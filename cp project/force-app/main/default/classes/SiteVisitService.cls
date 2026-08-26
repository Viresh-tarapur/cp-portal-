/**
 * @description Service managing site visit scheduling, confirmation, and outcome logging.
 */
public with sharing class SiteVisitService {

    public class SiteVisitRequest {
        @AuraEnabled public Id partnerId { get; set; }
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public Id projectId { get; set; }
        @AuraEnabled public Id inventoryUnitId { get; set; }
        @AuraEnabled public Date visitDate { get; set; }
        @AuraEnabled public String visitTime { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String customerPhone { get; set; }
        @AuraEnabled public String customerEmail { get; set; }
        @AuraEnabled public Integer numberOfVisitors { get; set; }
        @AuraEnabled public String remarks { get; set; }
    }

    /**
     * @description Schedules a new site visit requested by a Channel Partner.
     */
    public static Site_Visit__c createSiteVisit(SiteVisitRequest req) {
        if (req == null) {
            throw new AuraHandledException('Site visit request cannot be empty.');
        }

        Id effectivePartnerId = req.partnerId;
        if (effectivePartnerId == null) {
            effectivePartnerId = SecurityUtil.getCurrentUserPartnerId();
        }
        if (effectivePartnerId == null) {
            throw new AuraHandledException('No Channel Partner account associated with current user.');
        }

        // Validate partner active and KYC approved
        SecurityUtil.validatePartnerActiveAndApproved(effectivePartnerId);

        // Validate project access
        Project_Access__c pa = SecurityUtil.validateProjectAccess(effectivePartnerId, req.projectId);
        if (!pa.Can_Create_Site_Visit__c) {
            throw new AuraHandledException('Your account is not permitted to schedule site visits for this project.');
        }

        // Validate visit date
        if (req.visitDate == null || req.visitDate < Date.today()) {
            throw new AuraHandledException('Site visit date must be today or a future date.');
        }
        if (String.isBlank(req.visitTime)) {
            throw new AuraHandledException('Site visit time is required.');
        }
        if (String.isBlank(req.customerName)) {
            throw new AuraHandledException('Customer name is required.');
        }
        if (String.isBlank(req.customerPhone)) {
            throw new AuraHandledException('Customer phone is required.');
        }

        Site_Visit__c sv = new Site_Visit__c(
            Partner__c = effectivePartnerId,
            Lead__c = req.leadId,
            Project__c = req.projectId,
            Inventory_Unit__c = req.inventoryUnitId,
            Visit_Date__c = req.visitDate,
            Visit_Time__c = req.visitTime,
            Status__c = 'Requested',
            Customer_Name__c = req.customerName,
            Customer_Phone__c = req.customerPhone,
            Customer_Email__c = req.customerEmail,
            Number_of_Visitors__c = req.numberOfVisitors != null ? req.numberOfVisitors : 1,
            Remarks__c = req.remarks
        );

        insert sv;

        // If linked to lead, update lead status
        if (req.leadId != null) {
            List<Lead> leads = [SELECT Id, Status FROM Lead WHERE Id = :req.leadId LIMIT 1];
            if (!leads.isEmpty()) {
                leads[0].Status = 'Site Visit Planned';
                update leads[0];
            }
        }

        IntegrationLogger.logAudit(
            effectivePartnerId,
            sv.Id,
            'Site_Visit__c',
            'Lead Registered',
            null,
            'Requested',
            'Site visit scheduled for ' + req.visitDate.format() + ' at ' + req.visitTime
        );

        return sv;
    }

    /**
     * @description Fetches all site visits belonging to the current partner.
     */
    @AuraEnabled(cacheable=true)
    public static List<Site_Visit__c> getPartnerSiteVisits(Id partnerId) {
        if (partnerId == null) {
            partnerId = SecurityUtil.getCurrentUserPartnerId();
        }
        if (partnerId == null) {
            return new List<Site_Visit__c>();
        }

        return [
            SELECT Id, Name, Customer_Name__c, Customer_Phone__c, Customer_Email__c,
                   Project__c, Project__r.Name, Inventory_Unit__c, Inventory_Unit__r.Unit_Number__c,
                   Visit_Date__c, Visit_Time__c, Status__c, Number_of_Visitors__c,
                   Sales_Executive__c, Sales_Executive__r.Name, Remarks__c, Visit_Outcome__c,
                   Check_In_Time__c, Check_Out_Time__c
            FROM Site_Visit__c
            WHERE Partner__c = :partnerId
            WITH USER_MODE
            ORDER BY Visit_Date__c DESC, CreatedDate DESC
            LIMIT 500
        ];
    }
}
