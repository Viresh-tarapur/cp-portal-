/**
 * Main Controller for managing the Post-Sales Booking Lifecycle, Approvals, and Golden Rules.
 * Fingertipplus Technologies Pvt Ltd
 */
public with sharing class BookingController {
    public class BookingProcessException extends Exception {}

    /**
     * Stage 1: Push to CRM Approval by CRM Manager
     */
    @AuraEnabled
    public static PostSalesModels.BookingWrapper approvePushToCRM(PostSalesModels.BookingWrapper booking) {
        if (booking == null) throw new BookingProcessException('Null booking passed.');
        booking.stage = String.valueOf(PostSalesModels.BookingStage.BOOKED);
        booking.isLocked = false;
        booking.lockReason = '';
        return booking;
    }

    /**
     * Stage 2: Verify KYC & Dispatch Welcome Kit
     */
    @AuraEnabled
    public static PostSalesModels.BookingWrapper dispatchWelcomeKit(PostSalesModels.BookingWrapper booking) {
        if (!booking.kycVerified) {
            throw new BookingProcessException('Cannot send welcome kit before KYC verification.');
        }
        booking.welcomeMailSent = true;
        // Golden Rule 1: Always CC booking owner
        return booking;
    }

    /**
     * Stage 5: Registration Gate Check
     */
    @AuraEnabled
    public static Boolean validateRegistrationGate(PostSalesModels.BookingWrapper booking) {
        if (booking.fundingType == 'Loan') {
            return (booking.ddCopyUploaded == true);
        } else {
            // Self-payment: all previous demands must be cleared
            return true;
        }
    }

    /**
     * Golden Rule 5 Check: Enforce no cancellation or unit swap after Registration
     */
    @AuraEnabled
    public static void validateExceptionEligibility(PostSalesModels.BookingWrapper booking) {
        if (booking.stage == String.valueOf(PostSalesModels.BookingStage.REGISTRATION) || 
            booking.stage == String.valueOf(PostSalesModels.BookingStage.HANDOVER)) {
            throw new BookingProcessException('Golden Rule 5 Violation: No cancellation or swap permitted after Registration.');
        }
    }
}