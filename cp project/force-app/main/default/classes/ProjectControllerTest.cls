@isTest
private class ProjectControllerTest {

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Summit Realty',
            Email__c = 'partner@summitrealty.com',
            Phone__c = '+91 9123456789',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Partner_Tier__c = 'Platinum',
            Commission_Eligible__c = true
        );
        insert partner;

        Project__c proj = new Project__c(
            Name = 'Summit Horizon',
            Project_Code__c = 'PRJ-SH-001',
            Active__c = true,
            Status__c = 'Ongoing',
            City__c = 'Mumbai',
            Location__c = 'Bandra'
        );
        insert proj;

        Project_Access__c pa = new Project_Access__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Access_Status__c = 'Active',
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(60),
            Can_Register_Lead__c = true,
            Can_Create_Site_Visit__c = true,
            Can_View_Inventory__c = true
        );
        insert pa;
    }

    @isTest
    static void testGetAuthorizedProjects() {
        Test.startTest();
        List<Project__c> projects = ProjectController.getAuthorizedProjects();
        Test.stopTest();

        System.assertNotEquals(null, projects);
    }

    @isTest
    static void testGetProjectDetails() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        Project__c details = ProjectController.getProjectDetails(proj.Id);
        Test.stopTest();

        System.assertNotEquals(null, details);
        System.assertEquals('Summit Horizon', details.Name);
    }

    @isTest
    static void testGetProjectDetailsNull() {
        try {
            Test.startTest();
            ProjectController.getProjectDetails(null);
            Test.stopTest();
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
