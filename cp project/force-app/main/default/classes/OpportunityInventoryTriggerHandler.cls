/**
 * @description Handles Opportunity.StageName = 'Closed Won' to:
 *   1. Mark the linked Unit as Sold
 *   2. Ensure a Unit_Sales_History__c record exists (creates if missing)
 *   3. Mark the linked Unit as Available when Closed Lost (before booking)
 */
public without sharing class OpportunityInventoryTriggerHandler {

    public static void onAfterUpdate(
        List<Opportunity> newOpps,
        Map<Id, Opportunity> oldMap
    ) {
        List<Id> oppIdsClosedWon  = new List<Id>();
        List<Id> oppIdsClosedLost = new List<Id>();

        for (Opportunity opp : newOpps) {
            Opportunity old = oldMap.get(opp.Id);
            if (opp.StageName == old.StageName) continue;

            if (opp.StageName == 'Closed Won') {
                oppIdsClosedWon.add(opp.Id);
            } else if (opp.StageName == 'Closed Lost') {
                oppIdsClosedLost.add(opp.Id);
            }
        }

        // Handle Closed Won
        if (!oppIdsClosedWon.isEmpty()) {
            List<Opportunity> opps = [
                SELECT Id, Unit__c, Project__c, CloseDate
                FROM Opportunity
                WHERE Id IN :oppIdsClosedWon AND Unit__c != null
            ];
            for (Opportunity opp : opps) {
                UnitInventoryService.markUnitSold(opp.Unit__c);
            }
            // Find bookings for these opportunities and upsert history
            List<Booking__c> bookings = [
                SELECT Id FROM Booking__c
                WHERE Opportunity__c IN :oppIdsClosedWon
                LIMIT 200
            ];
            for (Booking__c bk : bookings) {
                UnitInventoryService.createOrUpdateSalesHistory(bk.Id);
            }
        }

        // Handle Closed Lost — release unit only if NOT yet booked
        if (!oppIdsClosedLost.isEmpty()) {
            List<Opportunity> opps = [
                SELECT Id, Unit__c
                FROM Opportunity
                WHERE Id IN :oppIdsClosedLost AND Unit__c != null
            ];
            for (Opportunity opp : opps) {
                // Only release if unit is Reserved (not yet formally Booked/Sold)
                List<Unit__c> units = [
                    SELECT Id, Status__c FROM Unit__c WHERE Id = :opp.Unit__c LIMIT 1
                ];
                if (!units.isEmpty() && units[0].Status__c == 'Reserved') {
                    UnitInventoryService.releaseUnit(opp.Unit__c);
                }
            }
        }
    }
}
