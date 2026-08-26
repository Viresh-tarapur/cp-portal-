@isTest
private class PartnerAccessServiceTest {

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Apex Global Realty',
            Email__c = 'partner@apexrealty.com',
            Phone__c = '+91 9876543210',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Partner_Tier__c = 'Gold',
            Commission_Eligible__c = true,
            PAN_Number__c = 'ABCDE1234F',
            GST_Number__c = '29ABCDE1234F1Z5'
        );
        insert partner;

        Project__c proj = new Project__c(
            Name = 'Apex Heights',
            Project_Code__c = 'PRJ-AH-001',
            Active__c = true,
            Status__c = 'Ongoing',
            City__c = 'Bengaluru',
            Location__c = 'Whitefield'
        );
        insert proj;

        Project_Access__c pa = new Project_Access__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Access_Status__c = 'Active',
            Start_Date__c = Date.today().addDays(-10),
            End_Date__c = Date.today().addDays(90),
            Can_Register_Lead__c = true,
            Can_Create_Site_Visit__c = true,
            Can_View_Inventory__c = true,
            Commission_Eligible__c = true
        );
        insert pa;
    }

    @isTest
    static void testGetPartnerDetails() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];
        Test.startTest();
        Partner__c details = PartnerAccessService.getPartnerDetails(p.Id);
        Test.stopTest();
        System.assertNotEquals(null, details, 'Partner details should not be null');
        System.assertEquals('Apex Global Realty', details.Name, 'Name should match');
    }

    @isTest
    static void testGetAuthorizedProjects() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];
        Test.startTest();
        List<Project__c> projects = PartnerAccessService.getAuthorizedProjects(p.Id);
        Test.stopTest();
        System.assertEquals(1, projects.size(), 'Should return 1 authorized project');
        System.assertEquals('Apex Heights', projects[0].Name);
    }

    @isTest
    static void testEligibilityChecks() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        Boolean canLead = PartnerAccessService.isPartnerEligibleForLeadRegistration(p.Id, proj.Id);
        Boolean canVisit = PartnerAccessService.isPartnerEligibleForSiteVisit(p.Id, proj.Id);
        Test.stopTest();

        System.assertEquals(true, canLead, 'Should be eligible for lead registration');
        System.assertEquals(true, canVisit, 'Should be eligible for site visits');
    }

    @isTest
    static void testPartnerPortalControllerMetrics() {
        Test.startTest();
        PartnerPortalController.DashboardMetricsWrapper metrics = PartnerPortalController.getDashboardMetrics();
        Test.stopTest();

        System.assertNotEquals(null, metrics, 'Metrics should not be null');
        System.assertNotEquals(null, metrics.partner, 'Partner should be populated');
    }

    @isTest
    static void testUpdatePartnerProfile() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];
        p.Phone__c = '+91 9999988888';
        p.Bank_Name__c = 'HDFC Bank';
        p.Account_Number__c = '123456789012';
        p.IFSC_Code__c = 'HDFC0001234';

        Test.startTest();
        Partner__c updated = PartnerPortalController.updatePartnerProfile(p);
        Test.stopTest();

        System.assertEquals('+91 9999988888', updated.Phone__c);
        System.assertEquals('HDFC Bank', updated.Bank_Name__c);
    }
}
