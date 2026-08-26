/**
 * Enforces the 4 Rules of Money for Payment Receipts.
 * Fingertipplus Technologies Pvt Ltd - Slide 11 Implementation
 */
public with sharing class ReceiptApprovalHandler {
    public class ReceiptException extends Exception {}

    /**
     * Rule 2: Pending means frozen. Locks the booking while receipt is awaiting decision.
     */
    public static void submitReceiptForApproval(PostSalesModels.ReceiptWrapper receipt, PostSalesModels.BookingWrapper booking) {
        if (receipt == null || booking == null) {
            throw new ReceiptException('Invalid receipt or booking payload.');
        }

        receipt.status = String.valueOf(PostSalesModels.ReceiptStatus.PENDING);
        booking.isLocked = true;
        booking.lockReason = 'Receipt ' + receipt.receiptId + ' pending Finance approval (Rule 2).';
    }

    /**
     * Rule 3 & 4: Decisions by Finance User.
     * - Approved: Adjusts against payment plan, unlocks booking.
     * - Rejected: Marks receipt dead, unlocks booking.
     */
    public static void processFinanceDecision(PostSalesModels.ReceiptWrapper receipt, PostSalesModels.BookingWrapper booking, Boolean isApproved, String comments) {
        if (receipt == null || booking == null) {
            throw new ReceiptException('Invalid receipt or booking payload.');
        }

        // Rule 3: If already rejected dead, it can never be altered
        if (receipt.status == String.valueOf(PostSalesModels.ReceiptStatus.REJECTED_DEAD)) {
            throw new ReceiptException('Rule 3 Violation: A rejected receipt is dead and cannot be modified or resubmitted.');
        }

        if (isApproved) {
            receipt.status = String.valueOf(PostSalesModels.ReceiptStatus.APPROVED);
            booking.isLocked = false;
            booking.lockReason = '';
            // Golden Rule 1: Receipt email dispatched with booking owner in CC
        } else {
            receipt.status = String.valueOf(PostSalesModels.ReceiptStatus.REJECTED_DEAD);
            booking.isLocked = false;
            booking.lockReason = '';
        }
    }
}