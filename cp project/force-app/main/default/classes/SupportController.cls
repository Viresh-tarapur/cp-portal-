/**
 * @description Controller managing partner support ticketing, queries, and case escalation.
 */
public with sharing class SupportController {

    /**
     * @description Fetches all support cases raised by the logged-in partner.
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> getMySupportCases() {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        if (partnerId == null) {
            return new List<Case>();
        }

        return [
            SELECT Id, CaseNumber, Subject, Category__c, Description, Status, Priority,
                   CreatedDate, ClosedDate, Project__r.Name, Lead__r.Name
            FROM Case
            WHERE Partner__c = :partnerId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    /**
     * @description Creates a new support ticket on behalf of the partner.
     */
    @AuraEnabled
    public static Case createSupportCase(String subject, String category, String description, Id projectId, Id leadId) {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        if (partnerId == null) {
            throw new AuraHandledException('No Channel Partner account associated with current user.');
        }

        if (String.isBlank(subject)) {
            throw new AuraHandledException('Subject is required.');
        }
        if (String.isBlank(description)) {
            throw new AuraHandledException('Description is required.');
        }

        Case newCase = new Case(
            Partner__c = partnerId,
            Subject = subject,
            Category__c = category,
            Description = description,
            Project__c = projectId,
            Lead__c = leadId,
            Status = 'New',
            Priority = 'Medium',
            Origin = 'Web'
        );

        insert newCase;

        return [
            SELECT Id, CaseNumber, Subject, Category__c, Status, Priority, CreatedDate
            FROM Case
            WHERE Id = :newCase.Id
            WITH USER_MODE
            LIMIT 1
        ];
    }
}
