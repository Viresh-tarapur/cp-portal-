/**
 * @description Controller enabling partners to schedule site visits and monitor visit execution.
 */
public with sharing class SiteVisitController {

    /**
     * @description Schedules a new site visit request.
     */
    @AuraEnabled
    public static Site_Visit__c scheduleVisit(SiteVisitService.SiteVisitRequest request) {
        try {
            return SiteVisitService.createSiteVisit(request);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /**
     * @description Fetches all site visits for the logged-in partner.
     */
    @AuraEnabled(cacheable=true)
    public static List<Site_Visit__c> getMySiteVisits() {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        return SiteVisitService.getPartnerSiteVisits(partnerId);
    }
}
