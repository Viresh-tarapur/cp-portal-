@isTest
private class DuplicateLeadServiceTest {

    @testSetup
    static void setupTestData() {
        Partner__c partnerA = new Partner__c(
            Name = 'Partner Agency A',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Email__c = 'partnerA@test.com',
            Phone__c = '9111111111'
        );
        insert partnerA;

        Partner__c partnerB = new Partner__c(
            Name = 'Partner Agency B',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Email__c = 'partnerB@test.com',
            Phone__c = '9222222222'
        );
        insert partnerB;

        Project__c proj = new Project__c(
            Name = 'Sky Heights Urban',
            Project_Code__c = 'SH-01',
            Location__c = 'Sarjapur',
            City__c = 'Bengaluru',
            Status__c = 'Ongoing',
            Active__c = true
        );
        insert proj;

        // Create protected registration by Partner A
        Lead_Registration__c regA = new Lead_Registration__c(
            Partner__c = partnerA.Id,
            Project__c = proj.Id,
            Customer_Name__c = 'Rahul Sharma',
            Customer_Phone__c = '9888877777',
            Customer_Email__c = 'rahul.sharma@test.com',
            Registration_Date__c = DateTime.now(),
            Protection_Start_Date__c = Date.today(),
            Protection_End_Date__c = Date.today().addDays(90),
            Registration_Status__c = 'Accepted',
            Ownership_Status__c = 'Protected'
        );
        insert regA;
    }

    @isTest
    static void testPartnerBCollisionWithProtectedCustomer() {
        Partner__c partnerB = [SELECT Id FROM Partner__c WHERE Name = 'Partner Agency B' LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        // Partner B attempts to check duplicate for Rahul Sharma
        DuplicateLeadService.DuplicateResult result = DuplicateLeadService.checkDuplicateLead(
            partnerB.Id,
            proj.Id,
            '9888877777',
            'rahul.sharma@test.com'
        );
        Test.stopTest();

        System.assertEquals(true, result.isDuplicate, 'Should detect duplicate lead');
        System.assertEquals(true, result.isProtectedConflict, 'Should flag protected exclusivity conflict with another partner');
    }

    @isTest
    static void testPartnerAReregistrationCheck() {
        Partner__c partnerA = [SELECT Id FROM Partner__c WHERE Name = 'Partner Agency A' LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        DuplicateLeadService.DuplicateResult result = DuplicateLeadService.checkDuplicateLead(
            partnerA.Id,
            proj.Id,
            '9888877777',
            'rahul.sharma@test.com'
        );
        Test.stopTest();

        System.assertEquals(true, result.isDuplicate, 'Should detect existing registration');
        System.assertEquals(false, result.isProtectedConflict, 'Should not flag conflict against own registration');
    }

    @isTest
    static void testFreshCustomerNoDuplicate() {
        Partner__c partnerB = [SELECT Id FROM Partner__c WHERE Name = 'Partner Agency B' LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        DuplicateLeadService.DuplicateResult result = DuplicateLeadService.checkDuplicateLead(
            partnerB.Id,
            proj.Id,
            '9999900000',
            'new.customer@test.com'
        );
        Test.stopTest();

        System.assertEquals(false, result.isDuplicate, 'Fresh customer should have no duplicates');
    }
}
