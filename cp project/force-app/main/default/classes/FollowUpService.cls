/**
 * @description Follow-Up Service - handles Follow_Up__c trigger logic
 */
public without sharing class FollowUpService {

    public static void handleBeforeSave(List<Follow_Up__c> newList, Map<Id, Follow_Up__c> oldMap) {
        // Basic validation and defaulting
        for (Follow_Up__c fu : newList) {
            if (fu.Status__c == null) {
                fu.Status__c = 'Pending';
            }
        }
    }

    public static void handleNextFollowUpScheduling(List<Follow_Up__c> newList, Map<Id, Follow_Up__c> oldMap) {
        // Scheduling logic placeholder - extend as needed
        // Follow-up chaining can be added here when required
    }

    public static Follow_Up__c createLeadFollowUp(Id leadId, Datetime fuDate, String fuType, String subject) {
        Follow_Up__c fu = new Follow_Up__c(
            Lead__c     = leadId,
            Follow_Up_Date__c = fuDate != null ? fuDate.date() : Date.today(),
            Follow_Up_Type__c = fuType,
            Notes__c    = subject,
            Status__c   = 'Pending'
        );
        insert fu;
        return fu;
    }

    public static Follow_Up__c createOpportunityFollowUp(Id oppId, Datetime fuDate, String fuType, String subject, String notes) {
        Follow_Up__c fu = new Follow_Up__c(
            Follow_Up_Date__c = fuDate != null ? fuDate.date() : Date.today(),
            Follow_Up_Type__c = fuType,
            Notes__c    = notes != null ? notes : subject,
            Status__c   = 'Pending'
        );
        insert fu;
        return fu;
    }
}
