@isTest
private class SupportControllerTest {

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Metropolis Realty',
            Email__c = 'partner@metropolis.com',
            Phone__c = '+91 9444433333',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Partner_Tier__c = 'Silver',
            Commission_Eligible__c = true
        );
        insert partner;

        Project__c proj = new Project__c(
            Name = 'Metropolis Greens',
            Project_Code__c = 'PRJ-MG-001',
            Active__c = true,
            Status__c = 'Ongoing',
            City__c = 'Pune'
        );
        insert proj;
    }

    @isTest
    static void testCreateAndGetSupportCases() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        Case createdCase = SupportController.createSupportCase(
            'Commission Slab Dispute',
            'Commission Issue',
            'Dispute regarding 3% vs 2% commission slab on booking COM-001',
            proj.Id,
            null
        );

        List<Case> cases = SupportController.getMySupportCases();
        Test.stopTest();

        System.assertNotEquals(null, createdCase.Id);
        System.assertEquals('Commission Slab Dispute', createdCase.Subject);
        System.assertEquals('Commission Issue', createdCase.Category__c);
        System.assertNotEquals(null, cases);
    }
}
