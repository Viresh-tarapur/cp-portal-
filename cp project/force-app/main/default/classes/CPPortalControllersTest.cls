@isTest
private class CPPortalControllersTest {

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Universal Properties',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Email__c = 'universal@prop.com',
            Phone__c = '9876543201',
            Partner_Tier__c = 'Platinum',
            Commission_Eligible__c = true
        );
        insert partner;

        Project__c proj = new Project__c(
            Name = 'Galaxy Residences',
            Project_Code__c = 'GR-01',
            Location__c = 'Bellandur',
            City__c = 'Bengaluru',
            Status__c = 'Ongoing',
            Active__c = true
        );
        insert proj;

        Project_Access__c access = new Project_Access__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Access_Status__c = 'Active',
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(30),
            Can_Register_Lead__c = true,
            Can_View_Inventory__c = true,
            Can_Create_Site_Visit__c = true
        );
        insert access;

        Inventory_Unit__c unit = new Inventory_Unit__c(
            Unit_Number__c = 'G-101',
            Project__c = proj.Id,
            Floor__c = 1,
            Unit_Type__c = '3BHK',
            Area__c = 1500,
            Base_Price__c = 9000000,
            Status__c = 'Available'
        );
        insert unit;

        Lead_Registration__c reg = new Lead_Registration__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Customer_Name__c = 'Neha Gupta',
            Customer_Phone__c = '9876501234',
            Registration_Date__c = DateTime.now(),
            Protection_Start_Date__c = Date.today(),
            Protection_End_Date__c = Date.today().addDays(90),
            Registration_Status__c = 'Accepted',
            Ownership_Status__c = 'Protected'
        );
        insert reg;
    }

    @isTest
    static void testPartnerPortalController() {
        Partner__c partner = [SELECT Id, Name, Phone__c, Billing_City__c FROM Partner__c LIMIT 1];

        Test.startTest();
        PartnerPortalController.DashboardMetricsWrapper metrics = PartnerPortalController.getDashboardMetrics();
        System.assertNotEquals(null, metrics);

        partner.Billing_City__c = 'Bengaluru South';
        Partner__c updated = PartnerPortalController.updatePartnerProfile(partner);
        System.assertEquals('Bengaluru South', updated.Billing_City__c);
        Test.stopTest();
    }

    @isTest
    static void testProjectController() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        List<Project__c> projects = ProjectController.getAuthorizedProjects();
        Project__c details = ProjectController.getProjectDetails(proj.Id);
        Test.stopTest();

        System.assert(projects.size() >= 0);
        System.assertNotEquals(null, details);
    }

    @isTest
    static void testInventoryController() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Inventory_Unit__c unit = [SELECT Id FROM Inventory_Unit__c LIMIT 1];

        Test.startTest();
        List<Inventory_Unit__c> inv = InventoryController.getInventory(proj.Id, 'All', 'All');
        System.assertEquals(1, inv.size());

        Inventory_Unit__c reserved = InventoryController.reserveInventoryUnit(unit.Id, 30);
        System.assertEquals('Reserved', reserved.Status__c);
        Test.stopTest();
    }

    @isTest
    static void testLeadRegistrationController() {
        Partner__c partner = [SELECT Id FROM Partner__c LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Lead_Registration__c reg = [SELECT Id FROM Lead_Registration__c LIMIT 1];

        LeadRegistrationService.LeadRegistrationRequest req = new LeadRegistrationService.LeadRegistrationRequest();
        req.partnerId = partner.Id;
        req.projectId = proj.Id;
        req.customerName = 'Kavita Roy';
        req.phone = '9911223344';

        Test.startTest();
        LeadRegistrationService.LeadRegistrationResponse resp = LeadRegistrationController.submitLeadRegistration(req);
        System.assertEquals(true, resp.isSuccess);

        DuplicateLeadService.DuplicateResult dup = LeadRegistrationController.checkDuplicate(proj.Id, '9911223344', null);
        System.assertEquals(true, dup.isDuplicate);

        List<Lead_Registration__c> leads = LeadRegistrationController.getMyLeads();
        System.assert(leads.size() > 0);

        Lead_Registration__c detail = LeadRegistrationController.getLeadDetails(reg.Id);
        System.assertNotEquals(null, detail);
        Test.stopTest();
    }

    @isTest
    static void testSiteVisitController() {
        Partner__c partner = [SELECT Id FROM Partner__c LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        SiteVisitService.SiteVisitRequest req = new SiteVisitService.SiteVisitRequest();
        req.partnerId = partner.Id;
        req.projectId = proj.Id;
        req.customerName = 'Sameer Jain';
        req.customerPhone = '9876543212';
        req.visitDate = Date.today().addDays(3);
        req.visitTime = '12:00 PM';

        Test.startTest();
        Site_Visit__c sv = SiteVisitController.scheduleVisit(req);
        System.assertNotEquals(null, sv.Id);

        List<Site_Visit__c> visits = SiteVisitController.getMySiteVisits();
        System.assert(visits.size() > 0);
        Test.stopTest();
    }

    @isTest
    static void testCommissionController() {
        Test.startTest();
        CommissionService.CommissionSummaryWrapper comms = CommissionController.getMyCommissions();
        System.assertNotEquals(null, comms);
        Test.stopTest();
    }

    @isTest
    static void testKycController() {
        Partner__c partner = [SELECT Id FROM Partner__c LIMIT 1];

        Test.startTest();
        KYC_Document__c doc = KycController.submitKycDocument('GST', '29ABCDE1234F1Z5', null, 'GST_Cert.pdf');
        System.assertNotEquals(null, doc.Id);

        KycController.KycStatusWrapper status = KycController.getKycStatus();
        System.assertNotEquals(null, status);
        Test.stopTest();
    }

    @isTest
    static void testSupportController() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        Case c = SupportController.createSupportCase('Inquiry on Green Valley', 'Inventory Issue', 'Need floor plan for 3BHK', proj.Id, null);
        System.assertNotEquals(null, c.Id);

        List<Case> myCases = SupportController.getMySupportCases();
        System.assertEquals(1, myCases.size());
        Test.stopTest();
    }
}
