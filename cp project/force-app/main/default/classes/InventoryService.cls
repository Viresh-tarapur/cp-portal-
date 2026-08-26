/**
 * @description Concurrency-safe inventory management and unit booking service.
 * Enforces server-side locks to prevent race conditions and double-booking.
 */
public with sharing class InventoryService {

    public class InventoryException extends Exception {}

    /**
     * @description Fetches inventory units for a project, enforcing partner authorization.
     */
    @AuraEnabled(cacheable=true)
    public static List<Inventory_Unit__c> getInventoryForProject(Id partnerId, Id projectId, String statusFilter, String unitTypeFilter) {
        if (partnerId == null) {
            partnerId = SecurityUtil.getCurrentUserPartnerId();
        }
        
        // Enforce project access authorization
        SecurityUtil.validateProjectAccess(partnerId, projectId);

        String query = 'SELECT Id, Name, Unit_Number__c, Project__c, Project__r.Name, Tower__c, Tower__r.Name, ' +
                       'Floor__c, Unit_Type__c, Area__c, Base_Price__c, Status__c, Booking_Amount__c, Facing__c, ' +
                       'Carpet_Area__c, Super_Built_Up_Area__c, Floor_Plan_URL__c, Blocked_Until__c ' +
                       'FROM Inventory_Unit__c WHERE Project__c = :projectId';

        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            query += ' AND Status__c = :statusFilter';
        }
        if (String.isNotBlank(unitTypeFilter) && unitTypeFilter != 'All') {
            query += ' AND Unit_Type__c = :unitTypeFilter';
        }

        query += ' WITH USER_MODE ORDER BY Floor__c ASC, Unit_Number__c ASC LIMIT 500';

        return Database.query(query);
    }

    /**
     * @description Temporarily reserves a unit for a partner lead with row-level locking.
     */
    public static Inventory_Unit__c reserveUnit(Id partnerId, Id unitId, Integer holdMinutes) {
        if (partnerId == null) {
            partnerId = SecurityUtil.getCurrentUserPartnerId();
        }
        SecurityUtil.validatePartnerActiveAndApproved(partnerId);

        if (holdMinutes == null || holdMinutes <= 0) {
            holdMinutes = 60; // 1 hour default hold
        }

        // Lock record for update to prevent concurrent double-reservation
        List<Inventory_Unit__c> units = [
            SELECT Id, Unit_Number__c, Project__c, Status__c, Base_Price__c, Booking_Amount__c, Blocked_Until__c, Blocked_By_Partner__c
            FROM Inventory_Unit__c
            WHERE Id = :unitId
            FOR UPDATE
        ];

        if (units.isEmpty()) {
            throw new InventoryException('Inventory unit not found.');
        }

        Inventory_Unit__c unit = units[0];
        SecurityUtil.validateProjectAccess(partnerId, unit.Project__c);

        if (unit.Status__c != 'Available') {
            if (unit.Status__c == 'Reserved' && unit.Blocked_Until__c != null && unit.Blocked_Until__c < DateTime.now()) {
                // Expired hold - allow acquisition
            } else {
                throw new InventoryException('Unit ' + unit.Unit_Number__c + ' is not available (Current status: ' + unit.Status__c + ').');
            }
        }

        unit.Status__c = 'Reserved';
        unit.Blocked_Until__c = DateTime.now().addMinutes(holdMinutes);
        unit.Blocked_By_Partner__c = partnerId;
        update unit;

        IntegrationLogger.logAudit(
            partnerId,
            unit.Id,
            'Inventory_Unit__c',
            'Unit Reserved',
            'Available',
            'Reserved',
            'Temporary hold acquired for ' + holdMinutes + ' minutes.'
        );

        return unit;
    }

    /**
     * @description Confirms booking of an inventory unit atomically.
     */
    public static Inventory_Unit__c bookUnit(Id partnerId, Id unitId, Id bookingId) {
        if (partnerId == null) {
            partnerId = SecurityUtil.getCurrentUserPartnerId();
        }
        SecurityUtil.validatePartnerActiveAndApproved(partnerId);

        List<Inventory_Unit__c> units = [
            SELECT Id, Unit_Number__c, Project__c, Status__c, Base_Price__c, Booking_Amount__c, Blocked_By_Partner__c
            FROM Inventory_Unit__c
            WHERE Id = :unitId
            FOR UPDATE
        ];

        if (units.isEmpty()) {
            throw new InventoryException('Inventory unit not found.');
        }

        Inventory_Unit__c unit = units[0];
        SecurityUtil.validateProjectAccess(partnerId, unit.Project__c);

        if (unit.Status__c != 'Available' && !(unit.Status__c == 'Reserved' && unit.Blocked_By_Partner__c == partnerId)) {
            throw new InventoryException('Unit ' + unit.Unit_Number__c + ' cannot be booked because it is ' + unit.Status__c + '.');
        }

        unit.Status__c = 'Booked';
        unit.Blocked_Until__c = null;
        update unit;

        // Update Project counters
        List<Project__c> projects = [
            SELECT Id, Sold_Units__c, Available_Units__c 
            FROM Project__c 
            WHERE Id = :unit.Project__c 
            LIMIT 1 
            FOR UPDATE
        ];
        if (!projects.isEmpty()) {
            Project__c p = projects[0];
            p.Sold_Units__c = (p.Sold_Units__c == null ? 0 : p.Sold_Units__c) + 1;
            if (p.Available_Units__c != null && p.Available_Units__c > 0) {
                p.Available_Units__c -= 1;
            }
            update p;
        }

        IntegrationLogger.logAudit(
            partnerId,
            unit.Id,
            'Inventory_Unit__c',
            'Unit Booked',
            'Available',
            'Booked',
            'Unit booked successfully against Booking ' + bookingId
        );

        return unit;
    }
}
