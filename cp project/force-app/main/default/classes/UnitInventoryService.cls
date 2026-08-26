/**
 * @description Central Unit Inventory Service for the Real Estate CRM.
 * Handles all unit status transitions with FOR UPDATE locking to prevent
 * double-booking race conditions.
 *
 * Status lifecycle:
 *   Available → Reserved → Booked → Sold
 *   Booked/Reserved → Cancelled (post-cancellation approval) → Available
 */
public without sharing class UnitInventoryService {

    public static Set<Id> processedSalesHistoryBookingIds = new Set<Id>();

    // ─────────────────────────────────────────────────────────────────────────
    // STATUS TRANSITION METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Reserves a unit when a Booking is created.
     *   Requires Unit.Status = Available. Uses FOR UPDATE to prevent race conditions.
     */
    public static void reserveUnit(Id unitId, Id bookingId) {
        if (unitId == null) return;
        List<Unit__c> units = [SELECT Id, Name, Status__c FROM Unit__c WHERE Id = :unitId FOR UPDATE];
        if (units.isEmpty()) return;
        Unit__c u = units[0];
        if (u.Status__c != 'Available') {
            AuraHandledException ex = new AuraHandledException(
                'Unit ' + u.Name + ' is no longer available. Please select another unit.'
            );
            ex.setMessage('Unit ' + u.Name + ' is no longer available. Please select another unit.');
            throw ex;
        }
        u.Status__c = 'Reserved';
        update u;
    }

    /**
     * @description Confirms booking of a unit (Reserved → Booked).
     *   Triggered when Booking status moves to Confirmed.
     */
    public static void confirmBooking(Id unitId) {
        if (unitId == null) return;
        List<Unit__c> units = [SELECT Id, Name, Status__c FROM Unit__c WHERE Id = :unitId FOR UPDATE];
        if (units.isEmpty()) return;
        Unit__c u = units[0];
        // Allow Reserved or Available to transition to Booked
        if (u.Status__c != 'Reserved' && u.Status__c != 'Available') {
            AuraHandledException ex = new AuraHandledException(
                'Unit ' + u.Name + ' cannot be confirmed. Current status: ' + u.Status__c
            );
            ex.setMessage('Unit ' + u.Name + ' cannot be confirmed. Current status: ' + u.Status__c);
            throw ex;
        }
        u.Status__c = 'Booked';
        update u;
    }

    /**
     * @description Marks a unit as Sold (Booked → Sold).
     *   Triggered when Opportunity.StageName = Closed Won.
     */
    public static void markUnitSold(Id unitId) {
        if (unitId == null) return;
        List<Unit__c> units = [SELECT Id, Name, Status__c FROM Unit__c WHERE Id = :unitId FOR UPDATE];
        if (units.isEmpty()) return;
        Unit__c u = units[0];
        if (u.Status__c == 'Sold') return; // idempotent
        u.Status__c = 'Sold';
        update u;
    }

    /**
     * @description Releases a unit back to Available after approved cancellation.
     */
    public static void releaseUnit(Id unitId) {
        if (unitId == null) return;
        List<Unit__c> units = [SELECT Id, Name, Status__c FROM Unit__c WHERE Id = :unitId FOR UPDATE];
        if (units.isEmpty()) return;
        Unit__c u = units[0];
        u.Status__c = 'Available';
        update u;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // UNIT SALES HISTORY METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Creates or updates the Unit_Sales_History__c record for a Booking.
     * Prevents duplicates: only one active (non-Cancelled) history record per Booking.
     */
    public static void createOrUpdateSalesHistory(Id bookingId) {
        if (bookingId == null) return;
        if (processedSalesHistoryBookingIds.contains(bookingId)) return;
        processedSalesHistoryBookingIds.add(bookingId);

        Booking__c bk = [
            SELECT Id, Unit__c, Project__c, Opportunity__c,
                   Booking_Date__c, Booking_Amount__c, Booking_Status__c,
                   Payment_Status__c, Customer_Name__c,
                   Unit__r.Tower__c, Unit__r.Project__c,
                   Opportunity__r.Payment_Mode__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];

        Id projId = (bk.Project__c != null) ? bk.Project__c : (bk.Unit__c != null ? bk.Unit__r.Project__c : null);
        Id towerId = (bk.Unit__c != null) ? bk.Unit__r.Tower__c : null;
        Id unitId = bk.Unit__c;
        String payMode = (bk.Opportunity__c != null && bk.Opportunity__r.Payment_Mode__c != null) ? bk.Opportunity__r.Payment_Mode__c : 'Bank Transfer';

        String saleStatus = (bk.Booking_Status__c == 'Cancelled') ? 'Cancelled' : 'Booked';

        // Check for existing active history
        List<Unit_Sales_History__c> existing = [
            SELECT Id, Sale_Status__c
            FROM Unit_Sales_History__c
            WHERE Booking__c = :bookingId AND Sale_Status__c != 'Cancelled'
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            // Update existing record
            Unit_Sales_History__c hist = existing[0];
            hist.Sale_Status__c = saleStatus;
            hist.Sale_Closed_Date__c = (saleStatus == 'Sold') ? Date.today() : null;
            hist.Project__c = projId;
            hist.Tower__c = towerId;
            hist.Unit__c = unitId;
            update hist;
        } else {
            // Create new record
            Unit_Sales_History__c hist = new Unit_Sales_History__c(
                Booking__c = bookingId,
                Opportunity__c = bk.Opportunity__c,
                Unit__c = unitId,
                Project__c = projId,
                Tower__c = towerId,
                Sale_Status__c = saleStatus,
                Booking_Date__c = bk.Booking_Date__c != null ? bk.Booking_Date__c : Date.today(),
                Booking_Amount__c = bk.Booking_Amount__c,
                Payment_Mode__c = payMode,
                Loan_Required__c = (payMode == 'Bank Loan' || payMode == 'Home Loan'),
                Sale_Closed_Date__c = (saleStatus == 'Sold') ? Date.today() : null,
                Refund_Status__c = 'Not Applicable'
            );
            insert hist;
        }
    }

    /**
     * @description Updates Unit Sales History on cancellation.
     */
    public static void updateSalesHistoryOnCancellation(Id bookingId, String reason) {
        if (bookingId == null) return;
        List<Unit_Sales_History__c> existing = [
            SELECT Id
            FROM Unit_Sales_History__c
            WHERE Booking__c = :bookingId AND Sale_Status__c != 'Cancelled'
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            Unit_Sales_History__c hist = existing[0];
            hist.Sale_Status__c = 'Cancelled';
            hist.Cancellation_Date__c = Date.today();
            hist.Cancellation_Reason__c = (reason != null && reason.length() > 255) ?
                reason.substring(0, 255) : reason;
            hist.Refund_Status__c = 'Pending';
            update hist;
        }
    }
}
