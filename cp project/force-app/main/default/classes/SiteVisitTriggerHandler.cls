public without sharing class SiteVisitTriggerHandler {
    public static void handleBeforeInsert(List<Site_Visit__c> visits) {
        inheritLeadDetails(visits);
    }

    public static void handleBeforeUpdate(List<Site_Visit__c> visits, Map<Id, Site_Visit__c> oldMap) {
        List<Site_Visit__c> changedVisits = new List<Site_Visit__c>();
        for (Site_Visit__c v : visits) {
            Site_Visit__c oldV = oldMap.get(v.Id);
            if (v.Lead__c != oldV.Lead__c || v.Sales_Executive__c == null) {
                changedVisits.add(v);
            }
        }
        if (!changedVisits.isEmpty()) {
            inheritLeadDetails(changedVisits);
        }
    }

    public static void handleAfterInsert(List<Site_Visit__c> visits) {
        CpPortalNotificationService.notifySiteVisit(visits);
    }

    private static void inheritLeadDetails(List<Site_Visit__c> visits) {
        Set<Id> leadIds = new Set<Id>();
        for (Site_Visit__c v : visits) {
            if (v.Lead__c != null) {
                leadIds.add(v.Lead__c);
            }
        }
        if (leadIds.isEmpty()) return;

        Map<Id, Lead> leadsMap = new Map<Id, Lead>([
            SELECT Id, OwnerId, FirstName, LastName, Name, Phone, CP_ID__c, Channel_Partner__c, Project__c
            FROM Lead
            WHERE Id IN :leadIds
        ]);

        for (Site_Visit__c v : visits) {
            if (v.Lead__c != null && leadsMap.containsKey(v.Lead__c)) {
                Lead l = leadsMap.get(v.Lead__c);
                if (v.Sales_Executive__c == null && l.OwnerId != null && String.valueOf(l.OwnerId).startsWith('005')) {
                    v.Sales_Executive__c = l.OwnerId;
                }
                if (String.isBlank(v.Customer_Name__c)) {
                    v.Customer_Name__c = l.Name;
                }
                if (String.isBlank(v.Customer_Phone__c)) {
                    v.Customer_Phone__c = l.Phone;
                }
                if (String.isBlank(v.CP_ID__c)) {
                    v.CP_ID__c = l.CP_ID__c;
                }
                if (v.Channel_Partner__c == null) {
                    v.Channel_Partner__c = l.Channel_Partner__c;
                }
                if (v.Project__c == null && l.Project__c != null) {
                    v.Project__c = l.Project__c;
                }
            }
        }
    }
}
