/**
 * @description Trigger Handler for Follow_Up__c (Follow-up)
 */
public without sharing class FollowUpTriggerHandler {

    public static Boolean isExecuting = false;

    public void onBeforeInsert(List<Follow_Up__c> newList) {
        FollowUpService.handleBeforeSave(newList, null);
    }

    public void onBeforeUpdate(List<Follow_Up__c> newList, Map<Id, Follow_Up__c> oldMap) {
        FollowUpService.handleBeforeSave(newList, oldMap);
    }

    public void onAfterUpdate(List<Follow_Up__c> newList, Map<Id, Follow_Up__c> oldMap) {
        if (!isExecuting) {
            isExecuting = true;
            try {
                FollowUpService.handleNextFollowUpScheduling(newList, oldMap);
            } finally {
                isExecuting = false;
            }
        }
    }
}
