/**
 * @description Controller handling lead submissions, duplicate validation, and lead portfolio views for partners.
 */
public with sharing class LeadRegistrationController {

    /**
     * @description Submits a lead registration with server-side validation, duplicate check, and protection lock.
     */
    @AuraEnabled
    public static LeadRegistrationService.LeadRegistrationResponse submitLeadRegistration(LeadRegistrationService.LeadRegistrationRequest request) {
        try {
            return LeadRegistrationService.registerLead(request);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /**
     * @description Real-time pre-submission duplicate check.
     */
    @AuraEnabled
    public static DuplicateLeadService.DuplicateResult checkDuplicate(Id projectId, String phone, String email) {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        return DuplicateLeadService.checkDuplicateLead(partnerId, projectId, phone, email);
    }

    /**
     * @description Retrieves all lead registrations belonging to the current partner.
     */
    @AuraEnabled(cacheable=true)
    public static List<Lead_Registration__c> getMyLeads() {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        if (partnerId == null) {
            return new List<Lead_Registration__c>();
        }

        return [
            SELECT Id, Name, Customer_Name__c, Customer_Phone__c, Customer_Email__c,
                   Project__c, Project__r.Name, Inventory_Unit__c, Inventory_Unit__r.Unit_Number__c,
                   Budget__c, Requirement__c, Registration_Date__c, Protection_Start_Date__c,
                   Protection_End_Date__c, Registration_Status__c, Ownership_Status__c,
                   Lead__c, Lead__r.Status, Lead__r.OwnerId, Lead__r.Owner.Name, OwnerId, Owner.Name, Notes__c, Duplicate_Found__c
            FROM Lead_Registration__c
            WHERE Partner__c = :partnerId
            WITH USER_MODE
            ORDER BY Registration_Date__c DESC
            LIMIT 500
        ];
    }

    /**
     * @description Fetches details of a single lead registration.
     */
    @AuraEnabled(cacheable=true)
    public static Lead_Registration__c getLeadDetails(Id registrationId) {
        if (registrationId == null) {
            throw new AuraHandledException('Registration ID is required.');
        }

        Id partnerId = SecurityUtil.getCurrentUserPartnerId();

        List<Lead_Registration__c> leads = [
            SELECT Id, Name, Customer_Name__c, Customer_Phone__c, Customer_Email__c,
                   Project__c, Project__r.Name, Project__r.Location__c, Project__r.City__c,
                   Inventory_Unit__c, Inventory_Unit__r.Unit_Number__c, Inventory_Unit__r.Base_Price__c,
                   Budget__c, Requirement__c, Expected_Purchase_Date__c, Notes__c,
                   Registration_Date__c, Protection_Start_Date__c, Protection_End_Date__c,
                   Protection_Days_Granted__c, Registration_Status__c, Ownership_Status__c,
                   Lead__c, Lead__r.Status, Partner__c
            FROM Lead_Registration__c
            WHERE Id = :registrationId
            WITH USER_MODE
            LIMIT 1
        ];

        if (leads.isEmpty()) {
            throw new AuraHandledException('Lead registration not found.');
        }

        if (partnerId != null && leads[0].Partner__c != partnerId) {
            throw new AuraHandledException('You do not have access to this lead record.');
        }

        return leads[0];
    }
}
