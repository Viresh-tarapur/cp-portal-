/**
 * @description Controller enabling partners to view inventory matrices and place temporary reservation holds.
 */
public with sharing class InventoryController {

    /**
     * @description Retrieves inventory units for a project with optional filters.
     */
    @AuraEnabled(cacheable=true)
    public static List<Inventory_Unit__c> getInventory(Id projectId, String statusFilter, String unitTypeFilter) {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        return InventoryService.getInventoryForProject(partnerId, projectId, statusFilter, unitTypeFilter);
    }

    /**
     * @description Places a temporary reservation hold on an inventory unit.
     */
    @AuraEnabled
    public static Inventory_Unit__c reserveInventoryUnit(Id unitId, Integer holdMinutes) {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        return InventoryService.reserveUnit(partnerId, unitId, holdMinutes);
    }
}
