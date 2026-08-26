/**
 * @description Controller providing authorized project catalogs and project detail views for Channel Partners.
 */
public with sharing class ProjectController {

    /**
     * @description Fetches all projects authorized for the logged-in Channel Partner.
     */
    @AuraEnabled(cacheable=true)
    public static List<Project__c> getAuthorizedProjects() {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        return PartnerAccessService.getAuthorizedProjects(partnerId);
    }

    /**
     * @description Retrieves single project details, ensuring partner authorization check.
     */
    @AuraEnabled(cacheable=true)
    public static Project__c getProjectDetails(Id projectId) {
        if (projectId == null) {
            throw new AuraHandledException('Project ID is required.');
        }

        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        if (partnerId != null) {
            SecurityUtil.validateProjectAccess(partnerId, projectId);
        }

        List<Project__c> projects = [
            SELECT Id, Name, Project_Code__c, Location__c, City__c, Project_Type__c,
                   Total_Units__c, Available_Units__c, Sold_Units__c, Status__c,
                   Minimum_Price__c, Maximum_Price__c, Description__c, Banner_Image_URL__c,
                   RERA_Number__c, Launch_Date__c, Completion_Date__c, Brochure_URL__c
            FROM Project__c
            WHERE Id = :projectId
            WITH USER_MODE
            LIMIT 1
        ];

        if (projects.isEmpty()) {
            throw new AuraHandledException('Project not found or access is restricted.');
        }

        return projects[0];
    }
}
