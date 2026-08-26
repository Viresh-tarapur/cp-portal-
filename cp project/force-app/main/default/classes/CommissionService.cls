/**
 * @description Service managing partner commission lifecycle, finance approvals,
 * payout disbursements, and ERP synchronization.
 */
public with sharing class CommissionService {

    public class CommissionException extends Exception {}

    public class CommissionSummaryWrapper {
        @AuraEnabled public Decimal totalEarned { get; set; }
        @AuraEnabled public Decimal totalPending { get; set; }
        @AuraEnabled public Decimal totalPaid { get; set; }
        @AuraEnabled public Integer eligibleCount { get; set; }
        @AuraEnabled public Integer approvedCount { get; set; }
        @AuraEnabled public Integer paidCount { get; set; }
        @AuraEnabled public List<Commission__c> commissions { get; set; }
    }

    /**
     * @description Calculates and generates a Commission record for a confirmed booking.
     */
    public static Commission__c generateCommissionForBooking(Id bookingId) {
        if (bookingId == null) {
            throw new CommissionException('Booking ID is required.');
        }

        List<Booking__c> bookings = [
            SELECT Id, Name, Partner__c, Lead__c, Opportunity__c, Project__c, Unit__c, Inventory_Unit__c,
                   Agreement_Value__c, Booking_Amount__c, Booking_Status__c, Payment_Status__c,
                   Booking_Date__c
            FROM Booking__c
            WHERE Id = :bookingId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (bookings.isEmpty()) {
            throw new CommissionException('Booking record not found.');
        }

        Booking__c b = bookings[0];
        if (b.Partner__c == null) {
            throw new CommissionException('This booking was not registered through a Channel Partner.');
        }

        // Validate Partner Active and Commission Eligible
        List<Partner__c> partners = [
            SELECT Id, Status__c, KYC_Status__c, Commission_Eligible__c 
            FROM Partner__c 
            WHERE Id = :b.Partner__c 
            WITH SYSTEM_MODE 
            LIMIT 1
        ];

        if (partners.isEmpty() || partners[0].Status__c != 'Approved' || partners[0].KYC_Status__c != 'Approved') {
            throw new CommissionException('Partner is not in an approved state for commission eligibility.');
        }

        Decimal propertyValue = b.Agreement_Value__c != null ? b.Agreement_Value__c : b.Booking_Amount__c;
        if (propertyValue == null || propertyValue <= 0) {
            propertyValue = 5000000; // fallback standard unit value
        }

        // Run calculation engine
        CommissionCalculator.CalculationResult calc = CommissionCalculator.calculateCommission(
            b.Partner__c,
            b.Project__c,
            propertyValue,
            b.Booking_Date__c
        );

        Commission__c comm = new Commission__c(
            Partner__c = b.Partner__c,
            Lead__c = b.Lead__c,
            Opportunity__c = b.Opportunity__c,
            Booking__c = b.Id,
            Project__c = b.Project__c,
            Inventory_Unit__c = b.Inventory_Unit__c,
            Commission_Rule__c = calc.appliedRuleId,
            Property_Value__c = calc.propertyValue,
            Commission_Rate__c = calc.commissionRate,
            Gross_Commission__c = calc.grossCommission,
            TDS_Rate__c = calc.tdsRate,
            Tax_Deduction__c = calc.taxDeduction,
            GST_Rate__c = calc.gstRate,
            GST_Amount__c = calc.gstAmount,
            Net_Commission__c = calc.netCommission,
            Eligibility_Status__c = 'Eligible',
            Approval_Status__c = 'Pending Approval',
            Payment_Status__c = 'Processing',
            Earned_Date__c = Date.today()
        );

        insert comm;

        // Update booking
        b.Commission_Calculated__c = true;
        b.Commission_Status__c = 'Calculated';
        update b;

        // Update Partner metric
        Partner__c p = partners[0];
        p.Total_Commission_Pending__c = (p.Total_Commission_Pending__c == null ? 0 : p.Total_Commission_Pending__c) + calc.netCommission;
        p.Total_Bookings__c = (p.Total_Bookings__c == null ? 0 : p.Total_Bookings__c) + 1;
        update p;

        IntegrationLogger.logAudit(
            b.Partner__c,
            comm.Id,
            'Commission__c',
            'Commission Approved',
            null,
            'Eligible & Pending Approval',
            'Commission calculated: ₹' + calc.netCommission.format() + ' (' + calc.ruleName + ')'
        );

        return comm;
    }

    /**
     * @description Approves a commission record (Internal Finance action).
     */
    public static Commission__c approveCommission(Id commissionId, String financeRemarks) {
        List<Commission__c> comms = [
            SELECT Id, Partner__c, Net_Commission__c, Approval_Status__c, Eligibility_Status__c, Odoo_Commission_ID__c
            FROM Commission__c
            WHERE Id = :commissionId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (comms.isEmpty()) {
            throw new CommissionException('Commission record not found.');
        }

        Commission__c comm = comms[0];
        if (comm.Eligibility_Status__c != 'Eligible') {
            throw new CommissionException('Commission must be Eligible before it can be approved.');
        }

        comm.Approval_Status__c = 'Approved';
        comm.Approved_Date__c = Date.today();
        comm.Approved_By__c = UserInfo.getUserId();
        comm.Finance_Remarks__c = financeRemarks;
        update comm;

        // Update Partner metrics: Move from Pending to Earned
        List<Partner__c> partners = [
            SELECT Id, Total_Commission_Earned__c, Total_Commission_Pending__c 
            FROM Partner__c 
            WHERE Id = :comm.Partner__c 
            LIMIT 1
        ];
        if (!partners.isEmpty()) {
            Partner__c p = partners[0];
            p.Total_Commission_Earned__c = (p.Total_Commission_Earned__c == null ? 0 : p.Total_Commission_Earned__c) + comm.Net_Commission__c;
            if (p.Total_Commission_Pending__c != null && p.Total_Commission_Pending__c >= comm.Net_Commission__c) {
                p.Total_Commission_Pending__c -= comm.Net_Commission__c;
            }
            update p;
        }

        IntegrationLogger.logAudit(
            comm.Partner__c,
            comm.Id,
            'Commission__c',
            'Commission Approved',
            'Pending Approval',
            'Approved',
            'Finance approval granted. Remarks: ' + financeRemarks
        );

        // Queue Odoo ERP Sync
        if (!System.isQueueable() && !System.isBatch()) {
            System.enqueueJob(new OdooCalloutQueueable('SYNC_COMMISSION', comm.Id));
        }

        return comm;
    }

    /**
     * @description Rejects a commission record with reason.
     */
    public static Commission__c rejectCommission(Id commissionId, String rejectionReason) {
        if (String.isBlank(rejectionReason)) {
            throw new CommissionException('Rejection reason is required.');
        }

        List<Commission__c> comms = [
            SELECT Id, Partner__c, Net_Commission__c, Approval_Status__c 
            FROM Commission__c 
            WHERE Id = :commissionId 
            WITH SYSTEM_MODE 
            LIMIT 1
        ];

        if (comms.isEmpty()) {
            throw new CommissionException('Commission record not found.');
        }

        Commission__c comm = comms[0];
        comm.Approval_Status__c = 'Rejected';
        comm.Rejection_Reason__c = rejectionReason;
        update comm;

        IntegrationLogger.logAudit(
            comm.Partner__c,
            comm.Id,
            'Commission__c',
            'Commission Rejected',
            'Pending Approval',
            'Rejected',
            'Rejection reason: ' + rejectionReason
        );

        return comm;
    }

    /**
     * @description Fetches commission summary and details for a partner portal user.
     */
    @AuraEnabled(cacheable=true)
    public static CommissionSummaryWrapper getPartnerCommissions(Id partnerId) {
        if (partnerId == null) {
            partnerId = SecurityUtil.getCurrentUserPartnerId();
        }
        if (partnerId == null) {
            return new CommissionSummaryWrapper();
        }

        CommissionSummaryWrapper summary = new CommissionSummaryWrapper();
        summary.totalEarned = 0;
        summary.totalPending = 0;
        summary.totalPaid = 0;
        summary.eligibleCount = 0;
        summary.approvedCount = 0;
        summary.paidCount = 0;

        summary.commissions = [
            SELECT Id, Name, Project__c, Project__r.Name, Booking__c, Booking__r.Name,
                   Property_Value__c, Commission_Rate__c, Gross_Commission__c, Tax_Deduction__c,
                   GST_Amount__c, Net_Commission__c, Eligibility_Status__c, Approval_Status__c,
                   Payment_Status__c, Earned_Date__c, Approved_Date__c, Paid_Date__c,
                   Odoo_Commission_ID__c
            FROM Commission__c
            WHERE Partner__c = :partnerId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];

        for (Commission__c c : summary.commissions) {
            if (c.Approval_Status__c == 'Approved') {
                summary.totalEarned += (c.Net_Commission__c != null ? c.Net_Commission__c : 0);
                summary.approvedCount++;
            } else if (c.Approval_Status__c == 'Pending Approval') {
                summary.totalPending += (c.Net_Commission__c != null ? c.Net_Commission__c : 0);
            }

            if (c.Payment_Status__c == 'Paid') {
                summary.totalPaid += (c.Net_Commission__c != null ? c.Net_Commission__c : 0);
                summary.paidCount++;
            }
            if (c.Eligibility_Status__c == 'Eligible') {
                summary.eligibleCount++;
            }
        }

        return summary;
    }
}
