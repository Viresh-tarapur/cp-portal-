@isTest
private class SecurityUtilTest {

    @testSetup
    static void setupTestData() {
        Partner__c approvedPartner = new Partner__c(
            Name = 'Approved Secure Partner',
            Email__c = 'approved@secure.com',
            Phone__c = '+91 9123412345',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Partner_Tier__c = 'Gold',
            Commission_Eligible__c = true
        );
        insert approvedPartner;

        Partner__c pendingPartner = new Partner__c(
            Name = 'Pending Partner',
            Email__c = 'pending@secure.com',
            Phone__c = '+91 9123412346',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Draft',
            KYC_Status__c = 'Pending',
            Partner_Tier__c = 'Bronze',
            Commission_Eligible__c = false
        );
        insert pendingPartner;

        Project__c proj = new Project__c(
            Name = 'Secure Residency',
            Project_Code__c = 'PRJ-SR-001',
            Active__c = true,
            Status__c = 'Ongoing',
            City__c = 'Bengaluru'
        );
        insert proj;

        Project_Access__c pa = new Project_Access__c(
            Partner__c = approvedPartner.Id,
            Project__c = proj.Id,
            Access_Status__c = 'Active',
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(30)
        );
        insert pa;
    }

    @isTest
    static void testValidatePartnerActiveAndApproved() {
        Partner__c approved = [SELECT Id FROM Partner__c WHERE Name = 'Approved Secure Partner' LIMIT 1];
        Partner__c pending = [SELECT Id FROM Partner__c WHERE Name = 'Pending Partner' LIMIT 1];

        Test.startTest();
        // Positive
        SecurityUtil.validatePartnerActiveAndApproved(approved.Id);

        // Negative pending
        try {
            SecurityUtil.validatePartnerActiveAndApproved(pending.Id);
            System.assert(false, 'Should throw SecurityException for pending partner');
        } catch (SecurityUtil.SecurityException e) {
            System.assert(true);
        }

        // Negative null
        try {
            SecurityUtil.validatePartnerActiveAndApproved(null);
            System.assert(false, 'Should throw SecurityException for null partner');
        } catch (SecurityUtil.SecurityException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateProjectAccess() {
        Partner__c approved = [SELECT Id FROM Partner__c WHERE Name = 'Approved Secure Partner' LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        Project_Access__c pa = SecurityUtil.validateProjectAccess(approved.Id, proj.Id);
        System.assertNotEquals(null, pa);

        // Invalid project
        try {
            SecurityUtil.validateProjectAccess(approved.Id, null);
            System.assert(false, 'Should throw SecurityException for null project');
        } catch (SecurityUtil.SecurityException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetSanitizedErrorMessage() {
        SecurityUtil.SecurityException secEx = new SecurityUtil.SecurityException('Explicit permission denied');
        AuraHandledException auraEx = new AuraHandledException('Invalid input parameter');
        NullPointerException npe = new NullPointerException();

        Test.startTest();
        String msg1 = SecurityUtil.getSanitizedErrorMessage(secEx);
        String msg2 = SecurityUtil.getSanitizedErrorMessage(auraEx);
        String msg3 = SecurityUtil.getSanitizedErrorMessage(npe);
        Test.stopTest();

        System.assertEquals('Explicit permission denied', msg1);
        System.assertEquals('Invalid input parameter', msg2);
        System.assert(msg3.contains('unexpected error occurred'));
    }
}
