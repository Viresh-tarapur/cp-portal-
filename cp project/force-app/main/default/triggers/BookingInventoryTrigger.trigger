/**
 * @description Booking__c trigger — Unit Inventory Control
 * Delegates to BookingInventoryTriggerHandler for all unit status transitions.
 */
trigger BookingInventoryTrigger on Booking__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            BookingAutoPopulateHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            BookingAutoPopulateHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            BookingInventoryTriggerHandler.onAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            BookingInventoryTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
