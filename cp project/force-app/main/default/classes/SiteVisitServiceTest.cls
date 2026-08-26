@isTest
private class SiteVisitServiceTest {

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Grand View Estates',
            Email__c = 'partner@grandview.com',
            Phone__c = '+91 9345678901',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Partner_Tier__c = 'Gold',
            Commission_Eligible__c = true
        );
        insert partner;

        Project__c proj = new Project__c(
            Name = 'Grand View Tower',
            Project_Code__c = 'PRJ-GVT-001',
            Active__c = true,
            Status__c = 'Ongoing',
            City__c = 'Bengaluru'
        );
        insert proj;

        Project_Access__c pa = new Project_Access__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Access_Status__c = 'Active',
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(60),
            Can_Register_Lead__c = true,
            Can_Create_Site_Visit__c = true
        );
        insert pa;

        Lead l = new Lead(
            LastName = 'Kapoor',
            Company = 'Individual',
            Phone = '9876543210',
            Project__c = proj.Id,
            Partner__c = partner.Id
        );
        insert l;
    }

    @isTest
    static void testCreateSiteVisitSuccess() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Lead l = [SELECT Id FROM Lead LIMIT 1];

        SiteVisitService.SiteVisitRequest req = new SiteVisitService.SiteVisitRequest();
        req.partnerId = p.Id;
        req.projectId = proj.Id;
        req.leadId = l.Id;
        req.visitDate = Date.today().addDays(2);
        req.visitTime = '11:00 AM';
        req.customerName = 'Rohan Kapoor';
        req.customerPhone = '9876543210';
        req.customerEmail = 'rohan@example.com';
        req.numberOfVisitors = 2;
        req.remarks = 'Interested in top floor 3BHK';

        Test.startTest();
        Site_Visit__c sv = SiteVisitService.createSiteVisit(req);
        Test.stopTest();

        System.assertNotEquals(null, sv.Id, 'Site visit ID should not be null');
        System.assertEquals('Requested', sv.Status__c);
        System.assertEquals('Rohan Kapoor', sv.Customer_Name__c);
    }

    @isTest
    static void testSiteVisitControllerMethods() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        SiteVisitService.SiteVisitRequest req = new SiteVisitService.SiteVisitRequest();
        req.partnerId = p.Id;
        req.projectId = proj.Id;
        req.visitDate = Date.today().addDays(1);
        req.visitTime = '03:00 PM';
        req.customerName = 'Meera Nair';
        req.customerPhone = '9876543219';

        Test.startTest();
        Site_Visit__c sv = SiteVisitController.scheduleVisit(req);
        List<Site_Visit__c> visits = SiteVisitController.getMySiteVisits();
        Test.stopTest();

        System.assertNotEquals(null, sv);
        System.assertNotEquals(null, visits);
    }
}
