trigger ReceiptLedgerLifecycle on Receipt__c (after insert, after update) {
    PostSalesLedgerTriggerHandler.reconcileReceipts(Trigger.new, Trigger.isInsert ? null : Trigger.oldMap);
}