/**
 * Real-Time Property Financial & Payment Planning Service
 * Fingertipplus Technologies Pvt Ltd
 */
public without sharing class PropertyFinancialPlannerService {
    public class FinancialPlannerException extends Exception {}

    /**
     * @description Fetches real-time pricing and property details for Project -> Tower -> Unit selection
     */
    @AuraEnabled
    public static Map<String, Object> fetchUnitPricingDetails(Id unitId) {
        if (unitId == null) throw new FinancialPlannerException('Unit ID cannot be null.');
        
        Unit__c u = [
            SELECT Id, Name, Project__c, Project__r.Name, Project__r.Interest_Rate__c, Floor__c, Unit_Type__c, Area_Sq_Ft__c,
                   Facing__c, Bedrooms__c, Bathrooms__c, Balcony__c, Car_Parking__c,
                   Price__c, Base_Price__c, Price_per_Sq_Ft__c, Parking_Charges__c,
                   Club_Amenities_Charges__c, Other_Charges__c, Status__c,
                   Blocked_By__c, Block_Date__c, Block_Expiry_Date__c, Blocked_For_Customer__c
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ];

        Decimal basePrice = (u.Base_Price__c != null && u.Base_Price__c > 0) ? u.Base_Price__c : 
                           (u.Price__c != null ? u.Price__c : 8500000.00);
        Decimal area = (u.Area_Sq_Ft__c != null && u.Area_Sq_Ft__c > 0) ? u.Area_Sq_Ft__c : 1500.00;
        Decimal ratePerSqFt = (u.Price_per_Sq_Ft__c != null && u.Price_per_Sq_Ft__c > 0) ? u.Price_per_Sq_Ft__c : 
                              (basePrice / area).setScale(2);
        Decimal parking = (u.Parking_Charges__c != null) ? u.Parking_Charges__c : 300000.00;
        Decimal other = (u.Other_Charges__c != null) ? u.Other_Charges__c : 200000.00;
        Decimal taxes = ((basePrice + parking + other) * 0.05).setScale(2); // 5% GST
        Decimal finalValue = (basePrice + parking + other + taxes).setScale(2);

        Map<String, Object> res = new Map<String, Object>();
        res.put('unitId', u.Id);
        res.put('unitNumber', u.Name);
        res.put('projectName', u.Project__r.Name);
        res.put('towerName', '');
        res.put('floor', u.Floor__c);
        res.put('unitType', u.Unit_Type__c);
        res.put('areaSqFt', area);
        res.put('facing', u.Facing__c);
        res.put('bedrooms', u.Bedrooms__c);
        res.put('bathrooms', u.Bathrooms__c);
        res.put('balcony', u.Balcony__c);
        res.put('parking', u.Car_Parking__c);
        res.put('basePrice', basePrice);
        res.put('pricePerSqFt', ratePerSqFt);
        res.put('parkingCharges', parking);
        res.put('otherCharges', other);
        res.put('taxes', taxes);
        res.put('discount', 0.00);
        res.put('finalPropertyValue', finalValue);
        res.put('status', u.Status__c);
        res.put('isAvailable', u.Status__c == 'Available');
        res.put('isBlocked', u.Status__c == 'Blocked');
        res.put('isBooked', u.Status__c == 'Booked' || u.Status__c == 'Sold');
        res.put('projectInterestRate', u.Project__r.Interest_Rate__c != null ? u.Project__r.Interest_Rate__c : 12.00);
        return res;
    }

    /**
     * @description Calculates Cost Sheet (Quotation) pricing and determines discount approval requirement
     */
    public static Quotation__c calculateCostSheet(Quotation__c quote) {
        if (quote.Base_Price__c == null || quote.Base_Price__c <= 0) {
            quote.Base_Price__c = (quote.Total_Amount__c != null && quote.Total_Amount__c > 0) ? quote.Total_Amount__c : 8500000.00;
        }
        Decimal parking = (quote.Parking_Charges__c != null) ? quote.Parking_Charges__c : 300000.00;
        Decimal other = (quote.Other_Charges__c != null) ? quote.Other_Charges__c : 200000.00;
        Decimal subTotal = quote.Base_Price__c + parking + other;
        
        Decimal discount = (quote.Discount_Amount__c != null) ? quote.Discount_Amount__c : 0.00;
        if (quote.Discount_Percentage__c != null && quote.Discount_Percentage__c > 0 && discount == 0.00) {
            discount = (subTotal * (quote.Discount_Percentage__c / 100)).setScale(2);
            quote.Discount_Amount__c = discount;
        }
        
        Decimal taxableAmount = subTotal - discount;
        quote.Taxes__c = (taxableAmount * 0.05).setScale(2);
        quote.Final_Property_Value__c = (taxableAmount + quote.Taxes__c).setScale(2);
        quote.Total_Amount__c = quote.Final_Property_Value__c;

        if (discount > 0 || quote.Plan_Type__c == 'Custom Payment Plan') {
            quote.Approval_Status__c = 'Pending Approval';
        } else {
            quote.Approval_Status__c = 'Approved';
        }
        return quote;
    }

    /**
     * @description Generates Standard or Custom Payment Schedule records for a Booking
     */
    public static List<Payment_Schedule__c> generatePaymentSchedules(Id bookingId, String planType, List<Payment_Schedule__c> customLines) {
        Booking__c bk = [SELECT Id, Agreement_Value__c, Unit_Price__c, Project__c, Funding_Type__c, Loan_Amount__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];
        Decimal totalVal = (bk.Agreement_Value__c != null && bk.Agreement_Value__c > 0) ? bk.Agreement_Value__c : 
                           ((bk.Unit_Price__c != null && bk.Unit_Price__c > 0) ? bk.Unit_Price__c : 9500000.00);
        Decimal loanTotal = (bk.Loan_Amount__c != null) ? bk.Loan_Amount__c : 0.00;
        Decimal loanRatio = totalVal > 0 ? (loanTotal / totalVal) : 0.00;

        List<Payment_Schedule__c> schedulesToInsert = new List<Payment_Schedule__c>();

        if (planType == 'Custom Payment Plan' && customLines != null && !customLines.isEmpty()) {
            Integer idx = 1;
            for (Payment_Schedule__c line : customLines) {
                line.Booking__c = bookingId;
                line.Installment_Number__c = idx;
                line.Plan_Type__c = 'Custom Payment Plan';
                line.Is_Active__c = true;
                line.Paid_Amount__c = 0.00;
                line.Outstanding_Amount__c = line.Amount__c;
                line.Loan_Portion__c = (line.Amount__c * loanRatio).setScale(2);
                line.Customer_Portion__c = line.Amount__c - line.Loan_Portion__c;
                line.Status__c = 'Pending';
                if (line.Due_Date__c == null) line.Due_Date__c = Date.today().addDays(idx * 30);
                schedulesToInsert.add(line);
                idx++;
            }
        } else {
            // Standard 5-milestone payment plan (Booking 10%, Foundation 20%, Structure 30%, Flooring 20%, Handover 20%)
            List<Map<String, Object>> standardMilestones = new List<Map<String, Object>>{
                new Map<String, Object>{ 'name' => 'Booking Advance', 'pct' => 10.00, 'days' => 0 },
                new Map<String, Object>{ 'name' => 'Foundation Milestone', 'pct' => 20.00, 'days' => 45 },
                new Map<String, Object>{ 'name' => 'Structure Completion', 'pct' => 30.00, 'days' => 90 },
                new Map<String, Object>{ 'name' => 'Flooring & Finishing', 'pct' => 20.00, 'days' => 150 },
                new Map<String, Object>{ 'name' => 'Key Handover & Possession', 'pct' => 20.00, 'days' => 210 }
            };

            for (Integer i = 0; i < standardMilestones.size(); i++) {
                Map<String, Object> m = standardMilestones[i];
                Decimal pct = (Decimal)m.get('pct');
                Decimal amount = (totalVal * (pct / 100.0)).setScale(2);
                Decimal loanPart = (amount * loanRatio).setScale(2);
                Decimal custPart = amount - loanPart;

                schedulesToInsert.add(new Payment_Schedule__c(
                    Booking__c = bookingId,
                    Installment_Number__c = i + 1,
                    Milestone_Name__c = (String)m.get('name'),
                    Percentage__c = pct,
                    Amount__c = amount,
                    Paid_Amount__c = 0.00,
                    Outstanding_Amount__c = amount,
                    Loan_Portion__c = loanPart,
                    Customer_Portion__c = custPart,
                    Due_Date__c = Date.today().addDays((Integer)m.get('days')),
                    Status__c = 'Pending',
                    Plan_Type__c = 'Standard Payment Plan',
                    Is_Active__c = true
                ));
            }
        }

        if (!schedulesToInsert.isEmpty()) {
            insert schedulesToInsert;
        }
        recalculateBookingPaymentSummary(bookingId);
        return schedulesToInsert;
    }

    /**
     * @description Recalculates and updates the real-time Payment Summary on Booking
     */
    public static void recalculateBookingPaymentSummary(Id bookingId) {
        Booking__c bk = [
            SELECT Id, Agreement_Value__c, Unit_Price__c, Total_Paid__c, Loan_Amount__c,
                   Loan_Disbursed_Amount__c, Sanctioned_Amount__c, Pending_Dues__c,
                   Outstanding_Amount__c, Interest_Amount__c, Next_Payment_Amount__c,
                   Next_Payment_Date__c, Next_Milestone_Name__c, Customer_Contribution__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];

        Decimal totalVal = (bk.Agreement_Value__c != null && bk.Agreement_Value__c > 0) ? bk.Agreement_Value__c :
                           ((bk.Unit_Price__c != null && bk.Unit_Price__c > 0) ? bk.Unit_Price__c : 0.00);
        Decimal totalPaid = (bk.Total_Paid__c != null) ? bk.Total_Paid__c : 0.00;
        Decimal loanSanctioned = (bk.Sanctioned_Amount__c != null && bk.Sanctioned_Amount__c > 0) ? bk.Sanctioned_Amount__c :
                                 ((bk.Loan_Amount__c != null) ? bk.Loan_Amount__c : 0.00);
        Decimal loanDisbursed = (bk.Loan_Disbursed_Amount__c != null) ? bk.Loan_Disbursed_Amount__c : 0.00;
        
        bk.Outstanding_Amount__c = totalVal - totalPaid;
        bk.Pending_Dues__c = bk.Outstanding_Amount__c;
        bk.Customer_Contribution__c = totalVal - loanSanctioned;
        bk.Loan_Outstanding__c = loanSanctioned - loanDisbursed;

        // Query active upcoming / due schedule
        List<Payment_Schedule__c> nextSchedules = [
            SELECT Id, Milestone_Name__c, Amount__c, Outstanding_Amount__c, Due_Date__c
            FROM Payment_Schedule__c
            WHERE Booking__c = :bookingId AND Is_Active__c = true AND (Status__c = 'Due' OR Status__c = 'Upcoming')
            ORDER BY Due_Date__c ASC
            LIMIT 1
        ];

        if (!nextSchedules.isEmpty()) {
            bk.Next_Payment_Amount__c = nextSchedules[0].Outstanding_Amount__c != null ? nextSchedules[0].Outstanding_Amount__c : nextSchedules[0].Amount__c;
            bk.Next_Payment_Date__c = nextSchedules[0].Due_Date__c;
            bk.Next_Milestone_Name__c = nextSchedules[0].Milestone_Name__c;
        }

        update bk;
    }

    /**
     * @description Executes an approved Payment Plan Modification
     */
    public static void applyPaymentPlanModification(Id modificationId) {
        Payment_Plan_Modification__c modReq = [
            SELECT Id, Booking__c, Status__c, Modification_Reason__c, Proposed_Plan_Details__c
            FROM Payment_Plan_Modification__c
            WHERE Id = :modificationId
            LIMIT 1
        ];

        if (modReq.Status__c != 'Approved') {
            throw new FinancialPlannerException('Cannot apply modification that is not Approved.');
        }

        // Delete existing old schedules to preserve uniqueness constraints
        List<Payment_Schedule__c> oldSchedules = [
            SELECT Id
            FROM Payment_Schedule__c
            WHERE Booking__c = :modReq.Booking__c
        ];
        if (!oldSchedules.isEmpty()) delete oldSchedules;

        // Generate new modified schedule lines
        generatePaymentSchedules(modReq.Booking__c, 'Standard Payment Plan', null);

        modReq.Status__c = 'Implemented';
        modReq.Approval_Date__c = Date.today();
        update modReq;
    }

    /**
     * @description Auto-releases expired temporary unit blocks
     */
    public static Integer releaseExpiredUnitBlocks() {
        List<Unit__c> expiredUnits = [
            SELECT Id, Status__c, Blocked_By__c, Block_Date__c, Block_Expiry_Date__c, Blocked_For_Customer__c
            FROM Unit__c
            WHERE Status__c = 'Blocked' AND Block_Expiry_Date__c != null AND Block_Expiry_Date__c < :Datetime.now()
        ];

        for (Unit__c u : expiredUnits) {
            u.Status__c = 'Available';
            u.Blocked_By__c = null;
            u.Block_Date__c = null;
            u.Block_Expiry_Date__c = null;
            u.Blocked_For_Customer__c = null;
        }

        if (!expiredUnits.isEmpty()) {
            update expiredUnits;
        }
        return expiredUnits.size();
    }
}