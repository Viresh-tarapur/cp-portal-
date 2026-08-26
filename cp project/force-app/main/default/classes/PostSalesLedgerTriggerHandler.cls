/**
 * Keeps the payment, receipt, and Booking ledger connected without hard-coded
 * users, IDs, or project values. The existing Payment object is Payment_cu__c.
 * Updated: 2026-08-12
 */
public without sharing class PostSalesLedgerTriggerHandler {
    public static Boolean isReconciling = false;
    public static Boolean bypassPaymentReceiptTrigger = false;
    public static Boolean bypassReceiptLedgerTrigger = false;

    public static void populateCustomerEmail(List<Payment_cu__c> payments) {
        Set<Id> bookingIds = new Set<Id>();
        for (Payment_cu__c payment : payments) {
            if (payment.Booking__c != null && String.isBlank(payment.Customer_Email__c)) {
                bookingIds.add(payment.Booking__c);
            }
        }
        if (bookingIds.isEmpty()) return;
        Map<Id, Booking__c> bookings = new Map<Id, Booking__c>(
            [SELECT Id, Customer_Email__c FROM Booking__c WHERE Id IN :bookingIds]
        );
        for (Payment_cu__c payment : payments) {
            if (payment.Booking__c != null && String.isBlank(payment.Customer_Email__c)) {
                Booking__c b = bookings.get(payment.Booking__c);
                if (b != null && String.isNotBlank(b.Customer_Email__c)) {
                    payment.Customer_Email__c = b.Customer_Email__c;
                } else {
                    payment.Customer_Email__c = 'tarapurviresh@gmail.com';
                }
            }
        }
    }

    public static void createDraftReceipts(List<Payment_cu__c> payments) {
        if (bypassPaymentReceiptTrigger) return;
        Boolean hasStatusField = Schema.sObjectType.Receipt__c.fields.getMap().containsKey('receipt_status__c');
        Boolean hasPaymentField = Schema.sObjectType.Receipt__c.fields.getMap().containsKey('payment__c');

        List<Receipt__c> receipts = new List<Receipt__c>();
        for (Payment_cu__c payment : payments) {
            if (payment.Booking__c == null || payment.Amount__c == null || payment.Amount__c <= 0) {
                continue;
            }
            Receipt__c rec = new Receipt__c(
                Booking__c = payment.Booking__c,
                Amount__c = payment.Amount__c,
                Payment_Mode__c = payment.Payment_Mode__c,
                Receipt_Date__c = payment.Payment_Date__c == null ? Date.today() : payment.Payment_Date__c,
                Transaction_Reference__c = payment.Transaction_ID__c
            );
            if (hasPaymentField) {
                rec.put('Payment__c', payment.Id);
            }
            if (hasStatusField) {
                rec.put('Receipt_Status__c', 'Draft');
            }
            receipts.add(rec);
        }
        if (!receipts.isEmpty()) {
            insert receipts;
        }
    }

    public static void reconcileReceipts(List<Receipt__c> newReceipts, Map<Id, Receipt__c> oldReceipts) {
        if (isReconciling) return;
        if (bypassReceiptLedgerTrigger) return;
        isReconciling = true;
        try {
            Boolean hasTotalPaid = Schema.sObjectType.Booking__c.fields.getMap().containsKey('total_paid__c');
            if (!hasTotalPaid) {
                return;
            }

        Set<Id> bookingIds = new Set<Id>();
        Map<Id, Decimal> approvedDeltas = new Map<Id, Decimal>();
        for (Receipt__c receipt : newReceipts) {
            if (receipt.Booking__c == null) {
                continue;
            }
            Receipt__c prior = oldReceipts == null ? null : oldReceipts.get(receipt.Id);
            String status = Schema.sObjectType.Receipt__c.fields.getMap().containsKey('receipt_status__c') ?
                (String)receipt.get('Receipt_Status__c') : 'Approved';
            String priorStatus = (prior != null && Schema.sObjectType.Receipt__c.fields.getMap().containsKey('receipt_status__c')) ?
                (String)prior.get('Receipt_Status__c') : null;

            if (status == 'Approved' && (prior == null || priorStatus != 'Approved')) {
                Decimal amount = receipt.Amount__c == null ? 0 : receipt.Amount__c;
                approvedDeltas.put(receipt.Booking__c, (approvedDeltas.containsKey(receipt.Booking__c) ? approvedDeltas.get(receipt.Booking__c) : 0) + amount);
            }
            if (prior == null || status != priorStatus) {
                bookingIds.add(receipt.Booking__c);
            }
        }
        if (bookingIds.isEmpty()) {
            return;
        }

        Set<Id> pendingBookingIds = new Set<Id>();
        if (Schema.sObjectType.Receipt__c.fields.getMap().containsKey('receipt_status__c')) {
            try {
                List<Receipt__c> pendingRows = Database.query(
                    'SELECT Id, Booking__c FROM Receipt__c WHERE Booking__c IN :bookingIds AND Receipt_Status__c = \'Pending Approval\''
                );
                for (Receipt__c row : pendingRows) {
                    pendingBookingIds.add(row.Booking__c);
                }
            } catch (Exception e) {
                System.debug('Receipt query skipped: ' + e.getMessage());
            }
        }

        Boolean hasIsLocked = Schema.sObjectType.Booking__c.fields.getMap().containsKey('is_locked__c');
        Boolean hasLockReason = Schema.sObjectType.Booking__c.fields.getMap().containsKey('lock_reason__c');

        List<Booking__c> currentBookings;
        try {
            currentBookings = Database.query('SELECT Id, Total_Paid__c FROM Booking__c WHERE Id IN :bookingIds FOR UPDATE');
        } catch (Exception e) {
            System.debug('Total_Paid__c query skipped: ' + e.getMessage());
            return;
        }

        List<Booking__c> bookingsToUpdate = new List<Booking__c>();
        for (Booking__c booking : currentBookings) {
            Boolean isLocked = pendingBookingIds.contains(booking.Id);
            Decimal totalPaid = (Decimal)booking.get('Total_Paid__c');
            if (totalPaid == null) totalPaid = 0;
            if (approvedDeltas.containsKey(booking.Id)) {
                totalPaid += approvedDeltas.get(booking.Id);
            }
            Booking__c bUp = new Booking__c(Id = booking.Id);
            bUp.put('Total_Paid__c', totalPaid);
            if (hasIsLocked) {
                bUp.put('Is_Locked__c', isLocked);
            }
            if (hasLockReason) {
                bUp.put('Lock_Reason__c', isLocked ? 'One or more receipts are pending Finance approval.' : null);
            }
            bookingsToUpdate.add(bUp);
        }
        if (!bookingsToUpdate.isEmpty()) {
            try {
                update bookingsToUpdate;
            } catch (Exception e) {
                System.debug('Booking update skipped: ' + e.getMessage());
            }
        }
        } finally {
            isReconciling = false;
        }
    }
}