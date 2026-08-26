@isTest
private class KycControllerTest {

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Empire Realty Advisors',
            Email__c = 'partner@empirerealty.com',
            Phone__c = '+91 9555544444',
            Partner_Type__c = 'Corporate Agency',
            Status__c = 'Draft',
            KYC_Status__c = 'Pending',
            Partner_Tier__c = 'Bronze',
            Commission_Eligible__c = false
        );
        insert partner;
    }

    @isTest
    static void testGetKycStatus() {
        Test.startTest();
        KycController.KycStatusWrapper status = KycController.getKycStatus();
        Test.stopTest();

        System.assertNotEquals(null, status);
    }

    @isTest
    static void testSubmitKycDocumentProgression() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];

        Test.startTest();
        KYC_Document__c doc = KycController.submitKycDocument('PAN', 'ABCDE1234F', '069000000000001AAA', 'pan_card.pdf');
        Test.stopTest();

        System.assertNotEquals(null, doc.Id);
        System.assertEquals('Uploaded', doc.Document_Status__c);
        System.assertEquals('PAN', doc.Document_Type__c);

        Partner__c updatedPartner = [SELECT Id, Status__c, KYC_Status__c FROM Partner__c WHERE Id = :p.Id];
        System.assertEquals('Under Review', updatedPartner.KYC_Status__c);
        System.assertEquals('KYC Under Review', updatedPartner.Status__c);
    }
}
