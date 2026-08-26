/**
 * @description Controller enabling partners to view earnings, pending approvals, and payment disbursement histories.
 */
public with sharing class CommissionController {

    /**
     * @description Fetches all commission records and financial summaries for current partner.
     */
    @AuraEnabled(cacheable=true)
    public static CommissionService.CommissionSummaryWrapper getMyCommissions() {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        return CommissionService.getPartnerCommissions(partnerId);
    }
}
