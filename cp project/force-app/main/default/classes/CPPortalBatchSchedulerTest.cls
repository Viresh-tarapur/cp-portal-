@isTest
private class CPPortalBatchSchedulerTest {

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Batch Partner',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Email__c = 'batch@partner.com',
            Phone__c = '9876543202'
        );
        insert partner;

        Project__c proj = new Project__c(
            Name = 'Batch Project',
            Project_Code__c = 'BP-01',
            Location__c = 'Whitefield',
            City__c = 'Bengaluru',
            Status__c = 'Ongoing',
            Active__c = true
        );
        insert proj;

        // Expired Project Access (End_Date in past)
        Project_Access__c access = new Project_Access__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Access_Status__c = 'Active',
            Start_Date__c = Date.today().addDays(-30),
            End_Date__c = Date.today().addDays(-1)
        );
        insert access;

        // Expired Lead Registration (Protection_End_Date in past)
        Lead_Registration__c reg = new Lead_Registration__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Customer_Name__c = 'Expired Customer',
            Customer_Phone__c = '9900011223',
            Registration_Date__c = DateTime.now().addDays(-100),
            Protection_Start_Date__c = Date.today().addDays(-100),
            Protection_End_Date__c = Date.today().addDays(-10),
            Registration_Status__c = 'Accepted',
            Ownership_Status__c = 'Protected'
        );
        insert reg;
    }

    @isTest
    static void testProjectAccessExpiryBatch() {
        Test.startTest();
        Database.executeBatch(new ProjectAccessExpiryBatch(), 200);
        Test.stopTest();

        Project_Access__c pa = [SELECT Id, Access_Status__c FROM Project_Access__c LIMIT 1];
        System.assertEquals('Expired', pa.Access_Status__c, 'Access status should be updated to Expired');
    }

    @isTest
    static void testLeadProtectionExpiryBatch() {
        Test.startTest();
        Database.executeBatch(new LeadProtectionExpiryBatch(), 200);
        Test.stopTest();

        Lead_Registration__c reg = [SELECT Id, Ownership_Status__c, Registration_Status__c FROM Lead_Registration__c LIMIT 1];
        System.assertEquals('Expired', reg.Ownership_Status__c, 'Ownership status should be updated to Expired');
        System.assertEquals('Expired', reg.Registration_Status__c);
    }

    @isTest
    static void testCPPortalScheduler() {
        Test.startTest();
        String cronExp = '0 0 0 * * ?';
        String jobId = System.schedule('CPPortalSchedulerTestJob', cronExp, new CPPortalScheduler());
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduler job should be enqueued');
    }
}
