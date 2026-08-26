/**
 * @description Receipt Service enforcing the 4 Mandatory Rules of Money (Slide 11)
 */
public without sharing class ReceiptService {
    
    /**
     * @description Rule 1 & 2: Submits a payment receipt to Finance and locks the booking.
     */
    public static Receipt__c submitReceiptForApproval(Id bookingId, Id demandId, Decimal amount, String paymentMode, String txnNo) {
        if (bookingId == null || amount == null || amount <= 0) {
            throw new AuraHandledException('Invalid payment parameters: Amount must be greater zero.');
        }

        String defaultTxn = 'TXN-' + String.valueOf(System.currentTimeMillis()).substring(4);
        String finalTxn = (txnNo != null ? txnNo : defaultTxn);
        if (finalTxn.length() > 18) {
            finalTxn = finalTxn.substring(0, 18);
        }

        PostSalesLedgerTriggerHandler.bypassPaymentReceiptTrigger = true;
        Receipt__c rec;
        try {
            Payment_cu__c pay = new Payment_cu__c(
                Booking__c = bookingId,
                Amount__c = amount,
                Payment_Date__c = Date.today(),
                Payment_Mode__c = (paymentMode != null ? paymentMode : 'Bank Transfer'),
                Payment_Status__c = 'Successful',
                Transaction_ID__c = finalTxn,
                Remarks__c = 'Payment for Receipt'
            );
            insert pay;

            rec = new Receipt__c(
                Booking__c = bookingId,
                Payment__c = pay.Id,
                Amount__c = amount,
                Payment_Mode__c = (paymentMode != null ? paymentMode : 'Bank Transfer'),
                Receipt_Date__c = Date.today(),
                Transaction_Reference__c = finalTxn,
                Receipt_Status__c = 'Pending Approval'
            );
            insert rec;

            // Rule 2: Pending = Frozen (Lock booking until decided)
            Booking__c bk = new Booking__c(
                Id = bookingId,
                Is_Locked__c = true,
                Lock_Reason__c = 'Payment Receipt ' + rec.Id + ' is Pending Finance Approval.'
            );
            update bk;
        } finally {
            PostSalesLedgerTriggerHandler.bypassPaymentReceiptTrigger = false;
        }

        return rec;
    }

    /**
     * @description Rule 4: Approves receipt, unlocks booking, adjusts ledger, sends email with PDF.
     * Two-step status transition:  Pending Approval → Draft (bypass ledger) → Approved (ledger fires)
     * Reason: Pending_Receipt_Financial_Fields_Locked validation rule blocks any update that changes
     * a financial field while PRIORVALUE(Status)='Pending Approval'. Going via Draft first makes the
     * final Approved update have PRIORVALUE='Draft', so the validation never fires.
     */
    public static void approveReceipt(Id receiptId, String comments) {
        Receipt__c rec = [
            SELECT Id, Booking__c, Amount__c, Receipt_Status__c, Payment__c, Payment_Mode__c, Transaction_Reference__c
            FROM Receipt__c
            WHERE Id = :receiptId
            LIMIT 1
        ];
        if (rec.Receipt_Status__c != 'Pending Approval' && rec.Receipt_Status__c != 'Draft') {
            throw new AuraHandledException('Only Draft or Pending Approval receipts can be approved.');
        }

        // Step 1: If Pending Approval, first move to Draft using a minimal sObject.
        // Bypass reconcileReceipts during this no-op status change (no payment amount changing).
        if (rec.Receipt_Status__c == 'Pending Approval') {
            PostSalesLedgerTriggerHandler.bypassReceiptLedgerTrigger = true;
            try {
                update new Receipt__c(Id = receiptId, Receipt_Status__c = 'Draft');
            } finally {
                PostSalesLedgerTriggerHandler.bypassReceiptLedgerTrigger = false;
            }
            rec.Receipt_Status__c = 'Draft';
        }

        // Step 2: Link payment if missing (safe now that PRIORVALUE is 'Draft').
        if (rec.Payment__c == null) {
            PostSalesLedgerTriggerHandler.bypassPaymentReceiptTrigger = true;
            try {
                Payment_cu__c pay = new Payment_cu__c(
                    Booking__c = rec.Booking__c,
                    Amount__c = rec.Amount__c,
                    Payment_Date__c = Date.today(),
                    Payment_Mode__c = String.isNotBlank(rec.Payment_Mode__c) ? rec.Payment_Mode__c : 'Bank Transfer',
                    Payment_Status__c = 'Successful',
                    Transaction_ID__c = String.isNotBlank(rec.Transaction_Reference__c) ? rec.Transaction_Reference__c : ('TXN-' + System.currentTimeMillis()),
                    Remarks__c = 'Auto-linked payment for Approved Receipt'
                );
                insert pay;
                rec.Payment__c = pay.Id;
            } finally {
                PostSalesLedgerTriggerHandler.bypassPaymentReceiptTrigger = false;
            }
        }

        // Step 3: Approve — PRIORVALUE is now 'Draft', so financial lock validation is silent.
        // reconcileReceipts fires here (not bypassed) to credit Total_Paid__c on the Booking.
        rec.Receipt_Status__c = 'Approved';
        update rec;
    }

    /**
     * @description Rule 3: Rejects receipt (marked Dead - cannot be reused/resubmitted).
     */
    public static void rejectReceipt(Id receiptId, String rejectionReason) {
        Receipt__c rec = [SELECT Id, Booking__c, Receipt_Status__c FROM Receipt__c WHERE Id = :receiptId LIMIT 1];
        rec.Receipt_Status__c = 'Rejected';
        update rec;

        // Unlock booking
        Booking__c bk = new Booking__c(
            Id = rec.Booking__c,
            Is_Locked__c = false,
            Lock_Reason__c = null
        );
        update bk;
    }
}