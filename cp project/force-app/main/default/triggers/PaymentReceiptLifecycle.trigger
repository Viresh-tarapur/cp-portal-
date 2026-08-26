trigger PaymentReceiptLifecycle on Payment_cu__c (before insert, after insert) {
    if (Trigger.isBefore) {
        PostSalesLedgerTriggerHandler.populateCustomerEmail(Trigger.new);
    } else if (Trigger.isAfter) {
        PostSalesLedgerTriggerHandler.createDraftReceipts(Trigger.new);
    }
}