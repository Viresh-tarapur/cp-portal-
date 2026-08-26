/**
 * @description Trigger Handler for Lead object.
 * Dispatches before insert and after insert events to LeadRoundRobinService.
 * Fingertipplus Technologies - Real Estate Pre-Sales CRM
 */
public without sharing class LeadTriggerHandler {

    @TestVisible
    private static Boolean bypassTrigger = false;

    /**
     * @description Handles before insert operations on Lead.
     * @param newLeads Trigger.new list
     */
    public static void handleBeforeInsert(List<Lead> newLeads) {
        if (bypassTrigger || newLeads == null || newLeads.isEmpty()) {
            return;
        }
        LeadRoundRobinService.assignLeads(newLeads);
    }

    /**
     * @description Handles after insert operations on Lead.
     * @param newLeads Trigger.new list
     */
    public static void handleAfterInsert(List<Lead> newLeads) {
        if (bypassTrigger || newLeads == null || newLeads.isEmpty()) {
            return;
        }
        LeadRoundRobinService.createAssignmentHistories(newLeads);
    }
}
