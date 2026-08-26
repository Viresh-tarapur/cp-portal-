/**
 * @description Schedulable orchestrator for Channel Partner Portal nightly maintenance jobs.
 */
public with sharing class CPPortalScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        // Run Project Access Expiry
        Database.executeBatch(new ProjectAccessExpiryBatch(), 200);

        // Run Lead Protection Expiry
        Database.executeBatch(new LeadProtectionExpiryBatch(), 200);
    }
}
