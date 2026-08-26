/**
 * @description Handler for Booking__c trigger events related to Unit inventory control.
 * Manages unit status transitions across the booking lifecycle:
 *   Insert                             → reserveUnit (Available → Reserved)
 *   Booking_Status__c → Confirmed      → confirmBooking (Reserved → Booked) + create history
 *   Booking_Status__c → Cancelled      → release unit + update history
 */
public without sharing class BookingInventoryTriggerHandler {

    /**
     * @description Called on after insert. Reserves the unit for each new booking in a bulkified manner.
     */
    public static void onAfterInsert(List<Booking__c> newBookings) {
        Set<Id> unitIds = new Set<Id>();
        for (Booking__c bk : newBookings) {
            if (bk.Unit__c != null) {
                unitIds.add(bk.Unit__c);
            }
        }
        if (unitIds.isEmpty()) return;

        Map<Id, Unit__c> unitsMap = new Map<Id, Unit__c>(
            [SELECT Id, Name, Status__c FROM Unit__c WHERE Id IN :unitIds FOR UPDATE]
        );

        List<Unit__c> unitsToUpdate = new List<Unit__c>();
        Set<Id> updatedIds = new Set<Id>();

        for (Booking__c bk : newBookings) {
            if (bk.Unit__c == null) continue;
            Unit__c u = unitsMap.get(bk.Unit__c);
            if (u == null) continue;

            if (u.Status__c != 'Available') {
                bk.addError('Unit ' + u.Name + ' is no longer available. Please select another unit.');
            } else if (!updatedIds.contains(u.Id)) {
                u.Status__c = 'Reserved';
                unitsToUpdate.add(u);
                updatedIds.add(u.Id);
            }
        }

        if (!unitsToUpdate.isEmpty()) {
            update unitsToUpdate;
        }
    }

    /**
     * @description Called on after update. Handles status transitions in a bulkified manner.
     */
    public static void onAfterUpdate(
        List<Booking__c> newBookings,
        Map<Id, Booking__c> oldMap
    ) {
        Set<Id> toConfirmUnitIds = new Set<Id>();
        Set<Id> toReleaseUnitIds = new Set<Id>();
        List<Id> bookingsForHist = new List<Id>();
        List<Id> cancelledBookings = new List<Id>();

        for (Booking__c bk : newBookings) {
            Booking__c old = oldMap != null ? oldMap.get(bk.Id) : null;
            String newStatus = bk.Booking_Status__c;
            String oldStatus = old != null ? old.Booking_Status__c : null;

            if (newStatus == oldStatus) continue;
            if (bk.Unit__c == null) continue;

            // Pending/New → Confirmed: confirm Booking
            if (newStatus == 'Confirmed' && oldStatus != 'Confirmed') {
                toConfirmUnitIds.add(bk.Unit__c);
                bookingsForHist.add(bk.Id);
            }

            // Confirmed → Cancelled: release unit
            if (newStatus == 'Cancelled' && oldStatus != 'Cancelled') {
                toReleaseUnitIds.add(bk.Unit__c);
                cancelledBookings.add(bk.Id);
            }
        }

        Set<Id> allUnitIds = new Set<Id>();
        allUnitIds.addAll(toConfirmUnitIds);
        allUnitIds.addAll(toReleaseUnitIds);

        if (!allUnitIds.isEmpty()) {
            Map<Id, Unit__c> unitsMap = new Map<Id, Unit__c>(
                [SELECT Id, Name, Status__c FROM Unit__c WHERE Id IN :allUnitIds FOR UPDATE]
            );
            List<Unit__c> unitUpdates = new List<Unit__c>();

            for (Id uId : toConfirmUnitIds) {
                Unit__c u = unitsMap.get(uId);
                if (u != null && (u.Status__c == 'Reserved' || u.Status__c == 'Available')) {
                    u.Status__c = 'Booked';
                    unitUpdates.add(u);
                }
            }
            for (Id uId : toReleaseUnitIds) {
                Unit__c u = unitsMap.get(uId);
                if (u != null) {
                    u.Status__c = 'Available';
                    unitUpdates.add(u);
                }
            }
            if (!unitUpdates.isEmpty()) {
                update unitUpdates;
            }
        }

        for (Id bookingId : bookingsForHist) {
            UnitInventoryService.createOrUpdateSalesHistory(bookingId);
        }
        for (Id bookingId : cancelledBookings) {
            UnitInventoryService.updateSalesHistoryOnCancellation(bookingId, 'Booking Cancelled');
        }
    }
}
