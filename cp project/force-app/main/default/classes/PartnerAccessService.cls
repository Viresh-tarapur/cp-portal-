/**
 * @description Service governing Channel Partner authorization, project access scopes, and portal permissions.
 */
public with sharing class PartnerAccessService {

    public class PartnerAccessException extends Exception {}

    /**
     * @description Retrieves partner master record with current tier, KYC status, and onboarding metadata.
     */
    @AuraEnabled(cacheable=true)
    public static Partner__c getPartnerDetails(Id partnerId) {
        if (partnerId == null) {
            partnerId = SecurityUtil.getCurrentUserPartnerId();
        }
        if (partnerId == null) {
            throw new AuraHandledException('No active partner account associated with the current user.');
        }

        List<Partner__c> partners = [
            SELECT Id, Name, Partner_Code__c, Partner_Type__c, Status__c, Email__c, Phone__c,
                   GST_Number__c, PAN_Number__c, KYC_Status__c, Partner_Tier__c, Commission_Eligible__c,
                   Onboarding_Date__c, Approval_Date__c, Billing_City__c, Billing_State__c,
                   Total_Leads_Registered__c, Total_Bookings__c, Total_Commission_Earned__c,
                   Total_Commission_Paid__c, Total_Commission_Pending__c
            FROM Partner__c
            WHERE Id = :partnerId
            WITH USER_MODE
            LIMIT 1
        ];

        if (partners.isEmpty()) {
            throw new AuraHandledException('Partner account record not accessible.');
        }

        return partners[0];
    }

    /**
     * @description Fetches all projects actively authorized for the given Channel Partner.
     */
    @AuraEnabled(cacheable=true)
    public static List<Project__c> getAuthorizedProjects(Id partnerId) {
        if (partnerId == null) {
            partnerId = SecurityUtil.getCurrentUserPartnerId();
        }
        if (partnerId == null) {
            return new List<Project__c>();
        }

        Date today = Date.today();
        List<Project_Access__c> accessList = [
            SELECT Project__c
            FROM Project_Access__c
            WHERE Partner__c = :partnerId
              AND Access_Status__c = 'Active'
              AND Start_Date__c <= :today
              AND End_Date__c >= :today
            WITH USER_MODE
        ];

        Set<Id> authorizedProjectIds = new Set<Id>();
        for (Project_Access__c pa : accessList) {
            authorizedProjectIds.add(pa.Project__c);
        }

        if (authorizedProjectIds.isEmpty()) {
            return new List<Project__c>();
        }

        return [
            SELECT Id, Name, Project_Code__c, Location__c, City__c, Project_Type__c,
                   Total_Units__c, Available_Units__c, Sold_Units__c, Status__c,
                   Minimum_Price__c, Maximum_Price__c, Description__c, Banner_Image_URL__c,
                   RERA_Number__c, Launch_Date__c, Completion_Date__c
            FROM Project__c
            WHERE Id IN :authorizedProjectIds
              AND Active__c = true
            WITH USER_MODE
            ORDER BY Name ASC
        ];
    }

    /**
     * @description Checks if a partner is authorized to register a lead on a project.
     */
    public static Boolean isPartnerEligibleForLeadRegistration(Id partnerId, Id projectId) {
        try {
            Project_Access__c pa = SecurityUtil.validateProjectAccess(partnerId, projectId);
            return pa.Can_Register_Lead__c;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * @description Checks if a partner is authorized to schedule a site visit on a project.
     */
    public static Boolean isPartnerEligibleForSiteVisit(Id partnerId, Id projectId) {
        try {
            Project_Access__c pa = SecurityUtil.validateProjectAccess(partnerId, projectId);
            return pa.Can_Create_Site_Visit__c;
        } catch (Exception e) {
            return false;
        }
    }
}
