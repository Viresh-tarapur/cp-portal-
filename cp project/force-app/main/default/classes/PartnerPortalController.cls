/**
 * @description Master Controller powering the Channel Partner Portal Dashboard and Profile views.
 */
public with sharing class PartnerPortalController {

    public class DashboardMetricsWrapper {
        @AuraEnabled public Partner__c partner { get; set; }
        @AuraEnabled public Integer totalLeads { get; set; }
        @AuraEnabled public Integer qualifiedLeads { get; set; }
        @AuraEnabled public Integer upcomingSiteVisits { get; set; }
        @AuraEnabled public Integer totalBookings { get; set; }
        @AuraEnabled public Decimal commissionEarned { get; set; }
        @AuraEnabled public Decimal commissionPending { get; set; }
        @AuraEnabled public List<Project__c> authorizedProjects { get; set; }
        @AuraEnabled public List<Lead_Registration__c> recentLeads { get; set; }
        @AuraEnabled public List<Site_Visit__c> upcomingVisits { get; set; }
        @AuraEnabled public List<Commission__c> recentCommissions { get; set; }
        @AuraEnabled public List<Case> supportCases { get; set; }
    }

    /**
     * @description Fetches all consolidated dashboard metrics for the logged-in partner.
     */
    @AuraEnabled(cacheable=true)
    public static DashboardMetricsWrapper getDashboardMetrics() {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        if (partnerId == null) {
            // For admin preview / testing, resolve first active partner
            List<Partner__c> samplePartners = [SELECT Id FROM Partner__c WITH SYSTEM_MODE LIMIT 1];
            if (!samplePartners.isEmpty()) {
                partnerId = samplePartners[0].Id;
            }
        }

        if (partnerId == null) {
            throw new AuraHandledException('No Channel Partner account found.');
        }

        DashboardMetricsWrapper metrics = new DashboardMetricsWrapper();
        metrics.partner = PartnerAccessService.getPartnerDetails(partnerId);

        // Authorized Projects
        metrics.authorizedProjects = PartnerAccessService.getAuthorizedProjects(partnerId);

        // Recent Registered Leads
        metrics.recentLeads = [
            SELECT Id, Name, Customer_Name__c, Customer_Phone__c, Customer_Email__c,
                   Project__r.Name, Registration_Status__c, Ownership_Status__c,
                   Protection_Start_Date__c, Protection_End_Date__c, Registration_Date__c
            FROM Lead_Registration__c
            WHERE Partner__c = :partnerId
            WITH USER_MODE
            ORDER BY Registration_Date__c DESC
            LIMIT 10
        ];
        metrics.totalLeads = [SELECT COUNT() FROM Lead_Registration__c WHERE Partner__c = :partnerId WITH USER_MODE];
        metrics.qualifiedLeads = [SELECT COUNT() FROM Lead_Registration__c WHERE Partner__c = :partnerId AND Registration_Status__c = 'Accepted' WITH USER_MODE];

        // Upcoming Site Visits
        Date today = Date.today();
        metrics.upcomingVisits = [
            SELECT Id, Name, Customer_Name__c, Customer_Phone__c, Project__r.Name,
                   Visit_Date__c, Visit_Time__c, Status__c, Sales_Executive__r.Name
            FROM Site_Visit__c
            WHERE Partner__c = :partnerId
              AND Visit_Date__c >= :today
              AND Status__c IN ('Requested', 'Confirmed')
            WITH USER_MODE
            ORDER BY Visit_Date__c ASC, Visit_Time__c ASC
            LIMIT 5
        ];
        metrics.upcomingSiteVisits = metrics.upcomingVisits.size();

        // Recent Commissions
        CommissionService.CommissionSummaryWrapper commSummary = CommissionService.getPartnerCommissions(partnerId);
        metrics.commissionEarned = commSummary.totalEarned;
        metrics.commissionPending = commSummary.totalPending;
        metrics.totalBookings = commSummary.paidCount + commSummary.approvedCount;
        metrics.recentCommissions = new List<Commission__c>();
        for (Integer i = 0; i < Math.min(commSummary.commissions.size(), 5); i++) {
            metrics.recentCommissions.add(commSummary.commissions[i]);
        }

        // Support Cases
        metrics.supportCases = [
            SELECT Id, CaseNumber, Subject, Category__c, Status, Priority, CreatedDate
            FROM Case
            WHERE Partner__c = :partnerId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];

        return metrics;
    }

    /**
     * @description Updates partner contact and banking information from the portal profile page.
     */
    @AuraEnabled
    public static Partner__c updatePartnerProfile(Partner__c partnerData) {
        if (partnerData == null || partnerData.Id == null) {
            throw new AuraHandledException('Partner data cannot be null.');
        }

        Id currentPartnerId = SecurityUtil.getCurrentUserPartnerId();
        if (currentPartnerId != null && currentPartnerId != partnerData.Id) {
            throw new AuraHandledException('You do not have permission to update another partner profile.');
        }

        // FLS / Sanitized update
        Partner__c toUpdate = new Partner__c(
            Id = partnerData.Id,
            Phone__c = partnerData.Phone__c,
            Billing_Street__c = partnerData.Billing_Street__c,
            Billing_City__c = partnerData.Billing_City__c,
            Billing_State__c = partnerData.Billing_State__c,
            Billing_PostalCode__c = partnerData.Billing_PostalCode__c,
            Bank_Name__c = partnerData.Bank_Name__c,
            Account_Number__c = partnerData.Account_Number__c,
            IFSC_Code__c = partnerData.IFSC_Code__c,
            Branch__c = partnerData.Branch__c,
            Account_Holder_Name__c = partnerData.Account_Holder_Name__c
        );

        update toUpdate;
        return PartnerAccessService.getPartnerDetails(partnerData.Id);
    }
}
