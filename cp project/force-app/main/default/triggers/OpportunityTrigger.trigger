trigger OpportunityTrigger on Opportunity (before insert, before update, after insert, after update) {

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            OpportunityAutoPopulateHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            OpportunityAutoPopulateHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isUpdate) {
            OpportunityInventoryTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
