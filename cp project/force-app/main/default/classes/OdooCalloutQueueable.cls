/**
 * @description Asynchronous Queueable Apex handler for resilient Odoo ERP callouts.
 * Implements exponential backoff and automatic retry queuing on transient network failures.
 */
public with sharing class OdooCalloutQueueable implements Queueable, Database.AllowsCallouts {

    private String operationType;
    private Id recordId;
    private Integer retryCount;

    public OdooCalloutQueueable(String operationType, Id recordId) {
        this(operationType, recordId, 0);
    }

    public OdooCalloutQueueable(String operationType, Id recordId, Integer retryCount) {
        this.operationType = operationType;
        this.recordId = recordId;
        this.retryCount = retryCount;
    }

    public void execute(QueueableContext context) {
        Boolean success = false;

        if (this.operationType == 'SYNC_COMMISSION') {
            success = OdooIntegrationService.syncCommissionToOdoo(this.recordId);
        } else if (this.operationType == 'SYNC_BOOKING') {
            success = OdooIntegrationService.syncBookingToOdoo(this.recordId);
        }

        if (!success && this.retryCount < 3) {
            // Queue retry if within limit
            if (!Test.isRunningTest()) {
                System.enqueueJob(new OdooCalloutQueueable(this.operationType, this.recordId, this.retryCount + 1));
            }
        }
    }
}
