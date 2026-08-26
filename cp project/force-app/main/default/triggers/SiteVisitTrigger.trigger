trigger SiteVisitTrigger on Site_Visit__c (before insert, before update, after insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        SiteVisitTriggerHandler.handleBeforeInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        SiteVisitTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isInsert) {
        SiteVisitTriggerHandler.handleAfterInsert(Trigger.new);
    }
}
