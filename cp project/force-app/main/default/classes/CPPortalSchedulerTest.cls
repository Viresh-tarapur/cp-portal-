@isTest
private class CPPortalSchedulerTest {

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Scheduler Test Partner',
            Email__c = 'scheduler@partner.com',
            Phone__c = '+91 9111122222',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Partner_Tier__c = 'Bronze',
            Commission_Eligible__c = true
        );
        insert partner;

        Project__c proj = new Project__c(
            Name = 'Scheduler View',
            Project_Code__c = 'PRJ-SV-001',
            Active__c = true,
            Status__c = 'Ongoing',
            City__c = 'Bengaluru'
        );
        insert proj;

        // Expired Project Access
        Project_Access__c pa = new Project_Access__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Access_Status__c = 'Active',
            Start_Date__c = Date.today().addDays(-40),
            End_Date__c = Date.today().addDays(-5)
        );
        insert pa;

        // Expired Lead Registration
        Lead_Registration__c reg = new Lead_Registration__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Customer_Name__c = 'Expired Customer',
            Customer_Phone__c = '9876599999',
            Registration_Date__c = DateTime.now().addDays(-100),
            Protection_Start_Date__c = Date.today().addDays(-100),
            Protection_End_Date__c = Date.today().addDays(-10),
            Registration_Status__c = 'Accepted',
            Ownership_Status__c = 'Protected'
        );
        insert reg;
    }

    @isTest
    static void testSchedulerAndBatchExecution() {
        Test.startTest();
        String cronExp = '0 0 0 15 3 ? 2030';
        String jobId = System.schedule('TestCPPortalScheduler', cronExp, new CPPortalScheduler());
        
        // Execute batch jobs directly for test execution
        Database.executeBatch(new ProjectAccessExpiryBatch(), 200);
        Database.executeBatch(new LeadProtectionExpiryBatch(), 200);
        Test.stopTest();

        System.assertNotEquals(null, jobId);

        Project_Access__c updatedPa = [SELECT Access_Status__c FROM Project_Access__c LIMIT 1];
        System.assertEquals('Expired', updatedPa.Access_Status__c);

        Lead_Registration__c updatedReg = [SELECT Ownership_Status__c, Registration_Status__c FROM Lead_Registration__c LIMIT 1];
        System.assertEquals('Expired', updatedReg.Ownership_Status__c);
        System.assertEquals('Expired', updatedReg.Registration_Status__c);
    }
}
