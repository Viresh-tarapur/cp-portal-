@isTest
private class LeadRegistrationServiceTest {

    @testSetup
    static void setupTestData() {
        Partner__c partnerA = new Partner__c(
            Name = 'Alpha Realty',
            Email__c = 'partnerA@alpharealty.com',
            Phone__c = '+91 9888877777',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Partner_Tier__c = 'Gold',
            Commission_Eligible__c = true
        );
        insert partnerA;

        Partner__c partnerB = new Partner__c(
            Name = 'Beta Realty',
            Email__c = 'partnerB@betarealty.com',
            Phone__c = '+91 9777766666',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Partner_Tier__c = 'Silver',
            Commission_Eligible__c = true
        );
        insert partnerB;

        Project__c proj = new Project__c(
            Name = 'Alpha Crest',
            Project_Code__c = 'PRJ-AC-001',
            Active__c = true,
            Status__c = 'Ongoing',
            City__c = 'Hyderabad',
            Available_Units__c = 20
        );
        insert proj;

        Project_Access__c paA = new Project_Access__c(
            Partner__c = partnerA.Id,
            Project__c = proj.Id,
            Access_Status__c = 'Active',
            Start_Date__c = Date.today().addDays(-10),
            End_Date__c = Date.today().addDays(90),
            Can_Register_Lead__c = true,
            Can_Create_Site_Visit__c = true,
            Can_View_Inventory__c = true
        );
        insert paA;

        Project_Access__c paB = new Project_Access__c(
            Partner__c = partnerB.Id,
            Project__c = proj.Id,
            Access_Status__c = 'Active',
            Start_Date__c = Date.today().addDays(-10),
            End_Date__c = Date.today().addDays(90),
            Can_Register_Lead__c = true,
            Can_Create_Site_Visit__c = true,
            Can_View_Inventory__c = true
        );
        insert paB;
    }

    @isTest
    static void testSuccessfulLeadRegistration() {
        Partner__c p = [SELECT Id FROM Partner__c WHERE Name = 'Alpha Realty' LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        LeadRegistrationService.LeadRegistrationRequest req = new LeadRegistrationService.LeadRegistrationRequest();
        req.partnerId = p.Id;
        req.projectId = proj.Id;
        req.customerName = 'Rajesh Sharma';
        req.phone = '9876500001';
        req.email = 'rajesh.sharma@example.com';
        req.budget = 12000000;
        req.requirement = '3BHK East Facing';

        Test.startTest();
        LeadRegistrationService.LeadRegistrationResponse resp = LeadRegistrationService.registerLead(req);
        Test.stopTest();

        System.assertEquals(true, resp.isSuccess, 'Registration should be successful');
        System.assertNotEquals(null, resp.registrationId, 'Registration ID should not be null');
        System.assertNotEquals(null, resp.leadId, 'Lead ID should not be null');

        Lead_Registration__c reg = [SELECT Ownership_Status__c, Registration_Status__c FROM Lead_Registration__c WHERE Id = :resp.registrationId];
        System.assertEquals('Protected', reg.Ownership_Status__c);
        System.assertEquals('Accepted', reg.Registration_Status__c);
    }

    @isTest
    static void testDuplicateLeadRegistrationCollisionBlocked() {
        Partner__c pA = [SELECT Id FROM Partner__c WHERE Name = 'Alpha Realty' LIMIT 1];
        Partner__c pB = [SELECT Id FROM Partner__c WHERE Name = 'Beta Realty' LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        // Partner A registers first
        LeadRegistrationService.LeadRegistrationRequest reqA = new LeadRegistrationService.LeadRegistrationRequest();
        reqA.partnerId = pA.Id;
        reqA.projectId = proj.Id;
        reqA.customerName = 'Vikram Malhotra';
        reqA.phone = '9876500002';
        reqA.email = 'vikram@example.com';
        LeadRegistrationService.registerLead(reqA);

        // Partner B attempts to register same customer on same project
        LeadRegistrationService.LeadRegistrationRequest reqB = new LeadRegistrationService.LeadRegistrationRequest();
        reqB.partnerId = pB.Id;
        reqB.projectId = proj.Id;
        reqB.customerName = 'Vikram M';
        reqB.phone = '9876500002';
        reqB.email = 'vikram@example.com';

        Test.startTest();
        try {
            LeadRegistrationService.registerLead(reqB);
            System.assert(false, 'Expected conflict exception when registering protected customer');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected conflict AuraHandledException');
        }
        Test.stopTest();

        List<Lead_Registration__c> disputeRegs = [SELECT Id, Registration_Status__c, Ownership_Status__c FROM Lead_Registration__c WHERE Partner__c = :pB.Id];
        System.assertEquals(1, disputeRegs.size());
        System.assertEquals('Duplicate', disputeRegs[0].Registration_Status__c);
        System.assertEquals('Disputed', disputeRegs[0].Ownership_Status__c);
    }

    @isTest
    static void testLeadRegistrationControllerSubmitAndQuery() {
        Partner__c p = [SELECT Id FROM Partner__c WHERE Name = 'Alpha Realty' LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        LeadRegistrationService.LeadRegistrationRequest req = new LeadRegistrationService.LeadRegistrationRequest();
        req.partnerId = p.Id;
        req.projectId = proj.Id;
        req.customerName = 'Anita Desai';
        req.phone = '9876500003';
        req.email = 'anita@example.com';

        Test.startTest();
        LeadRegistrationService.LeadRegistrationResponse resp = LeadRegistrationController.submitLeadRegistration(req);
        DuplicateLeadService.DuplicateResult dup = LeadRegistrationController.checkDuplicate(proj.Id, '9876500003', 'anita@example.com');
        List<Lead_Registration__c> myLeads = LeadRegistrationController.getMyLeads();
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assertEquals(true, dup.isDuplicate);
        System.assertNotEquals(null, myLeads);
    }
}
             
