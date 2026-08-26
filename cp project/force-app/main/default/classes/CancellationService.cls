/**
 * @description 2-Tier Cancellation Engine and Unit Release (Slides 24 & 33)
 */
public without sharing class CancellationService {
    
    /**
     * @description Initiates cancellation request (Step 1: Sales Head approval)
     */
    public static Cancellation__c initiateCancellation(Id bookingId, String reason) {
        Booking__c bk = [SELECT Id, Stage__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];
        if (bk.Stage__c == 'Registration' || bk.Stage__c == 'Handover') {
            throw new AuraHandledException('Golden Rule 5 Violation: No cancellation allowed after Registration.');
        }

        Cancellation__c cnc = new Cancellation__c(
            Booking__c = bookingId,
            Reason__c = reason,
            Status__c = 'Sales Head Approval'
        );
        insert cnc;
        return cnc;
    }

    /**
     * @description Finalizes 2-tier approval: releases unit to Available and updates booking stage
     */
    public static void approveCancellationByCRM(Id cancellationId) {
        Cancellation__c cnc = [SELECT Id, Booking__c, Status__c, Reason__c FROM Cancellation__c WHERE Id = :cancellationId LIMIT 1];
        cnc.Status__c = 'Approved';
        update cnc;

        Booking__c bk = [SELECT Id, Stage__c, Total_Paid__c, Unit__c FROM Booking__c WHERE Id = :cnc.Booking__c LIMIT 1];
        bk.Stage__c = 'Cancellation';
        update bk;

        // Release the unit back to Available
        if (bk.Unit__c != null) {
            UnitInventoryService.releaseUnit(bk.Unit__c);
        }

        // Update Unit Sales History to reflect cancellation
        UnitInventoryService.updateSalesHistoryOnCancellation(bk.Id, cnc.Reason__c);

        // Auto-create refund record for Finance processing (Slide 38)
        if (bk.Total_Paid__c != null && bk.Total_Paid__c > 0) {
            Refund__c ref = new Refund__c(
                Booking__c = bk.Id,
                Amount__c = bk.Total_Paid__c,
                Status__c = 'Pending Finance'
            );
            insert ref;
        }
    }
}