@isTest
private class OdooIntegrationServiceTest {

    public class OdooHttpSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            if (req.getEndpoint().contains('voucher')) {
                res.setBody('{"success": true, "odoo_voucher_id": "VOUCH-998811"}');
            } else {
                res.setBody('{"success": true, "odoo_order_id": "SO-887722"}');
            }
            return res;
        }
    }

    public class OdooHttpFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setBody('{"error": "Internal Server Error in Odoo"}');
            return res;
        }
    }

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Odoo Test Partner',
            Email__c = 'odoo@partner.com',
            Phone__c = '+91 9888899999',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Partner_Tier__c = 'Gold',
            Commission_Eligible__c = true,
            GST_Number__c = '29ABCDE1234F1Z5',
            PAN_Number__c = 'ABCDE1234F'
        );
        insert partner;

        Project__c proj = new Project__c(
            Name = 'Odoo Heights',
            Project_Code__c = 'PRJ-OH-001',
            Active__c = true,
            Status__c = 'Ongoing',
            City__c = 'Bengaluru'
        );
        insert proj;

        Booking__c booking = new Booking__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Agreement_Value__c = 8000000,
            Booking_Amount__c = 400000,
            Booking_Date__c = Date.today(),
            Booking_Status__c = 'Booked',
            Customer_Name__c = 'Suresh Kumar',
            Customer_Phone__c = '9876543210',
            Unit_Number__c = 'B-202'
        );
        insert booking;

        Commission__c comm = new Commission__c(
            Partner__c = partner.Id,
            Booking__c = booking.Id,
            Project__c = proj.Id,
            Property_Value__c = 8000000,
            Gross_Commission__c = 160000,
            Tax_Deduction__c = 8000,
            GST_Amount__c = 28800,
            Net_Commission__c = 180800,
            Approval_Status__c = 'Approved',
            Eligibility_Status__c = 'Eligible'
        );
        insert comm;
    }

    @isTest
    static void testSyncCommissionToOdooSuccess() {
        Commission__c comm = [SELECT Id FROM Commission__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new OdooHttpSuccessMock());

        Test.startTest();
        Boolean success = OdooIntegrationService.syncCommissionToOdoo(comm.Id);
        Test.stopTest();

        System.assertEquals(true, success);
        Commission__c updated = [SELECT Odoo_Commission_ID__c FROM Commission__c WHERE Id = :comm.Id];
        System.assertEquals('VOUCH-998811', updated.Odoo_Commission_ID__c);

        List<Integration_Log__c> logs = [SELECT Id, Status__c, HTTP_Status_Code__c FROM Integration_Log__c WHERE Record_ID__c = :comm.Id];
        System.assertEquals(1, logs.size());
        System.assertEquals('Success', logs[0].Status__c);
    }

    @isTest
    static void testSyncBookingToOdooSuccess() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new OdooHttpSuccessMock());

        Test.startTest();
        Boolean success = OdooIntegrationService.syncBookingToOdoo(b.Id);
        Test.stopTest();

        System.assertEquals(true, success);
        Booking__c updated = [SELECT Odoo_Booking_ID__c FROM Booking__c WHERE Id = :b.Id];
        System.assertEquals('SO-887722', updated.Odoo_Booking_ID__c);
    }

    @isTest
    static void testSyncCommissionToOdooFailure() {
        Commission__c comm = [SELECT Id FROM Commission__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new OdooHttpFailureMock());

        Test.startTest();
        Boolean success = OdooIntegrationService.syncCommissionToOdoo(comm.Id);
        Test.stopTest();

        System.assertEquals(false, success);
        List<Integration_Log__c> logs = [SELECT Id, Status__c FROM Integration_Log__c WHERE Record_ID__c = :comm.Id];
        System.assertEquals(1, logs.size());
        System.assertEquals('Failed', logs[0].Status__c);
    }

    @isTest
    static void testOdooCalloutQueueableExecution() {
        Commission__c comm = [SELECT Id FROM Commission__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new OdooHttpSuccessMock());

        Test.startTest();
        System.enqueueJob(new OdooCalloutQueueable('SYNC_COMMISSION', comm.Id));
        Test.stopTest();

        Commission__c updated = [SELECT Odoo_Commission_ID__c FROM Commission__c WHERE Id = :comm.Id];
        System.assertEquals('VOUCH-998811', updated.Odoo_Commission_ID__c);
    }
}
