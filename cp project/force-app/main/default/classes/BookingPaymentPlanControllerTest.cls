@isTest
private class BookingPaymentPlanControllerTest {

    @testSetup
    static void setupData() {
        Project__c proj = new Project__c(
            Name = 'Financial Test Project',
            Project_Code__c = 'FTP-01',
            Builder_Name__c = 'Sunrise Developers',
            Project_Type__c = 'Apartment',
            Status__c = 'Ongoing',
            City__c = 'Bengaluru',
            State__c = 'Karnataka',
            Starting_Price__c = 8500000.00,
            Total_Units__c = 100,
            Interest_Rate__c = 12.0
        );
        insert proj;

        Tower__c tow = new Tower__c(
            Name = 'Tower 1',
            Project__c = proj.Id,
            Tower_Code__c = 'FTP-T1',
            Number_of_Floors__c = 10,
            Total_Units__c = 40,
            Status__c = 'Under Construction'
        );
        insert tow;

        Unit__c unit1 = new Unit__c(
            Name = '101',
            Project__c = proj.Id,
            Tower__c = tow.Id,
            Floor__c = 1,
            Unit_Type__c = '3 BHK',
            Area_Sq_Ft__c = 1500,
            Facing__c = 'East',
            Bedrooms__c = 3,
            Bathrooms__c = 3,
            Balcony__c = 2,
            Car_Parking__c = true,
            Base_Price__c = 8000000.00,
            Price_per_Sq_Ft__c = 5333.33,
            Parking_Charges__c = 300000.00,
            Other_Charges__c = 200000.00,
            Status__c = 'Available',
            Price__c = 8500000.00
        );
        insert unit1;

        Account acc = new Account(Name = 'Test Financial Customer', Phone = '1234567890');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp - 101',
            AccountId = acc.Id,
            StageName = 'Booking Confirmed',
            CloseDate = Date.today().addDays(60),
            Project__c = proj.Id,
            Tower__c = tow.Id,
            Unit__c = unit1.Id,
            Booking_Amount__c = 500000.00,
            Payment_Mode__c = 'Bank Transfer',
            Expected_Registration_Date__c = Date.today().addDays(60)
        );
        insert opp;

        Booking__c bk = new Booking__c(
            Customer_Name__c = 'Meera Nair',
            Unit_Number__c = '101',
            Unit__c = unit1.Id,
            Project__c = proj.Id,
            Opportunity__c = opp.Id,
            Agreement_Value__c = 9000000.00,
            Unit_Price__c = 9000000.00,
            Total_Paid__c = 900000.00,
            Stage__c = 'Booked',
            Plan_Type__c = 'Custom Payment Plan',
            Funding_Type__c = 'Loan',
            Booking_Date__c = Date.today(),
            Booking_Amount__c = 500000.00,
            Booking_Status__c = 'Confirmed',
            Payment_Status__c = 'Pending',
            Sanctioned_Amount__c = 7000000.00,
            Loan_Disbursed_Amount__c = 2000000.00,
            Loan_Status__c = 'Partially Disbursed'
        );
        insert bk;
    }

    @isTest
    static void testGetBookingDetails() {
        Booking__c bk = [SELECT Id FROM Booking__c LIMIT 1];
        
        Test.startTest();
        BookingPaymentPlanController.BookingDetailsWrapper fetched = BookingPaymentPlanController.getBookingDetails(bk.Id);
        Test.stopTest();

        System.assertNotEquals(null, fetched, 'Wrapper should not be null');
        System.assertEquals(bk.Id, fetched.booking.Id, 'IDs should match');
        System.assertNotEquals(null, fetched.schedules, 'Schedules list should be loaded');
        System.assertEquals(true, fetched.hasModifyAccess, 'System Admin should have modify access');
    }

    @isTest
    static void testGetBookingDetailsException() {
        Test.startTest();
        try {
            BookingPaymentPlanController.getBookingDetails(null);
            System.assert(false, 'Should have thrown exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Booking ID cannot be null'), 'Expected error message');
        }
        Test.stopTest();
    }

    @isTest
    static void testPreviewSchedulesFullAmount() {
        Booking__c bk = [SELECT Id FROM Booking__c LIMIT 1];
        
        Test.startTest();
        List<Map<String, Object>> preview = BookingPaymentPlanController.previewSchedules(bk.Id, 'Full Amount', null, 1000000.00);
        Test.stopTest();

        System.assertEquals(1, preview.size(), 'Full Amount preview should contain 1 installment');
        System.assertEquals('Full Payment', preview[0].get('milestoneName'));
        System.assertEquals(1000000.00, preview[0].get('amount'));
    }

    @isTest
    static void testPreviewSchedulesMonthly() {
        Booking__c bk = [SELECT Id FROM Booking__c LIMIT 1];
        
        Test.startTest();
        List<Map<String, Object>> preview = BookingPaymentPlanController.previewSchedules(bk.Id, 'Monthly Payment', 12, 1200000.00);
        Test.stopTest();

        System.assertEquals(12, preview.size(), 'Monthly Payment preview should contain 12 installments');
        System.assertEquals(100000.00, preview[0].get('amount'));
    }

    @isTest
    static void testPreviewSchedulesExceptions() {
        Booking__c bk = [SELECT Id FROM Booking__c LIMIT 1];
        
        Test.startTest();
        try {
            BookingPaymentPlanController.previewSchedules(bk.Id, 'Monthly Payment', 12, null);
            System.assert(false, 'Exception expected for null amount');
        } catch (Exception e) {}

        try {
            BookingPaymentPlanController.previewSchedules(bk.Id, 'Monthly Payment', null, 1200000.00);
            System.assert(false, 'Exception expected for null months');
        } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testActivatePlanFullAmount() {
        Booking__c bk = [SELECT Id FROM Booking__c LIMIT 1];
        
        Test.startTest();
        BookingPaymentPlanController.BookingDetailsWrapper updated = BookingPaymentPlanController.activatePaymentPlan(bk.Id, 'Full Amount', null, 1000000.00);
        Test.stopTest();

        System.assertEquals(true, updated.booking.Payment_Plan_Activated__c, 'Plan should be activated');
        System.assertEquals('Full Amount', updated.booking.Payment_Plan_Type__c, 'Type should be Full Amount');
        System.assertEquals(1000000.00, updated.booking.Total_Property_Plot_Amount__c, 'Total amount should be set');

        List<Payment_Schedule__c> schedules = [SELECT Id, Amount__c, Milestone_Name__c FROM Payment_Schedule__c WHERE Booking__c = :bk.Id];
        System.assertEquals(1, schedules.size(), '1 payment schedule should be generated');
        System.assertEquals('Full Payment', schedules[0].Milestone_Name__c);
    }

    @isTest
    static void testActivatePlanMonthly() {
        Booking__c bk = [SELECT Id FROM Booking__c LIMIT 1];
        
        Test.startTest();
        BookingPaymentPlanController.BookingDetailsWrapper updated = BookingPaymentPlanController.activatePaymentPlan(bk.Id, 'Monthly Payment', 10, 1000005.00);
        Test.stopTest();

        System.assertEquals(true, updated.booking.Payment_Plan_Activated__c, 'Plan should be activated');
        System.assertEquals(10, updated.booking.Payment_Plan_Months__c);
        System.assertNotEquals(null, updated.booking.Monthly_Installment__c);

        List<Payment_Schedule__c> schedules = [SELECT Id, Amount__c, Milestone_Name__c FROM Payment_Schedule__c WHERE Booking__c = :bk.Id ORDER BY Installment_Number__c ASC];
        System.assertEquals(10, schedules.size(), '10 schedules should be generated');
        
        Decimal totalCalculated = 0.00;
        for (Payment_Schedule__c ps : schedules) {
            totalCalculated += ps.Amount__c;
        }
        System.assertEquals(1000005.00, totalCalculated, 'Discrepancy adjustment should ensure exact total amount match');
    }

    @isTest
    static void testPreserveSchedulesOnModify() {
        Booking__c bk = [SELECT Id FROM Booking__c LIMIT 1];
        
        // 1. Activate initial monthly plan of 3 months with total 300,000
        BookingPaymentPlanController.BookingDetailsWrapper init = BookingPaymentPlanController.activatePaymentPlan(bk.Id, 'Monthly Payment', 3, 300000.00);
        
        // 2. Mark the first schedule as Paid
        List<Payment_Schedule__c> schedules = [SELECT Id, Status__c, Paid_Amount__c FROM Payment_Schedule__c WHERE Booking__c = :bk.Id ORDER BY Installment_Number__c ASC];
        schedules[0].Status__c = 'Paid';
        schedules[0].Paid_Amount__c = 100000.00;
        update schedules[0];

        // 3. Modify payment plan to 5 months with total 500,000
        Test.startTest();
        BookingPaymentPlanController.BookingDetailsWrapper modified = BookingPaymentPlanController.activatePaymentPlan(bk.Id, 'Monthly Payment', 5, 500000.00);
        Test.stopTest();

        // 4. Verify results
        // Sum of all active schedules should match new total (500,000)
        List<Payment_Schedule__c> finalSchedules = [SELECT Id, Amount__c, Status__c, Installment_Number__c FROM Payment_Schedule__c WHERE Booking__c = :bk.Id ORDER BY Installment_Number__c ASC];
        
        // The first schedule must remain preserved (Paid)
        System.assertEquals('Paid', finalSchedules[0].Status__c);
        System.assertEquals(100000.00, finalSchedules[0].Amount__c);
        
        // Total should be 500,000
        Decimal sumAmount = 0;
        for (Payment_Schedule__c ps : finalSchedules) {
            sumAmount += ps.Amount__c;
        }
        System.assertEquals(500000.00, sumAmount, 'Schedules sum should equal new configured total');
        
        // Total count of schedules should be 5
        System.assertEquals(5, finalSchedules.size());
    }

    @isTest
    static void testBookingAutoPopulateFromOpp() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Tower__c tow = [SELECT Id FROM Tower__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // Create a new available unit to avoid double-booking validation error
        Unit__c unit2 = new Unit__c(
            Name = '102',
            Project__c = proj.Id,
            Tower__c = tow.Id,
            Floor__c = 2,
            Unit_Type__c = '2 BHK',
            Area_Sq_Ft__c = 1200,
            Facing__c = 'West',
            Bedrooms__c = 2,
            Bathrooms__c = 2,
            Balcony__c = 1,
            Car_Parking__c = false,
            Base_Price__c = 6000000.00,
            Price_per_Sq_Ft__c = 5000.00,
            Parking_Charges__c = 0.00,
            Other_Charges__c = 100000.00,
            Status__c = 'Available',
            Price__c = 6100000.00
        );
        insert unit2;

        Opportunity opp2 = new Opportunity(
            Name = 'Test Opp - 102',
            AccountId = acc.Id,
            StageName = 'Booking Confirmed',
            CloseDate = Date.today().addDays(60),
            Project__c = proj.Id,
            Tower__c = tow.Id,
            Unit__c = unit2.Id,
            Booking_Amount__c = 400000.00,
            Payment_Mode__c = 'Bank Transfer',
            Expected_Registration_Date__c = Date.today().addDays(60)
        );
        insert opp2;
        
        Test.startTest();
        Booking__c newBk = new Booking__c(
            Opportunity__c = opp2.Id,
            Booking_Status__c = 'Pending',
            Payment_Status__c = 'Pending'
        );
        insert newBk;
        Test.stopTest();

        // Verify that fields were automatically populated from Opportunity and its related Unit
        Booking__c queriedBk = [
            SELECT Id, Customer_Name__c, Customer_Phone__c, Unit_Number__c, Floor__c, Base_Price__c, Project__c, Tower__c, Unit__c
            FROM Booking__c
            WHERE Id = :newBk.Id
        ];
        
        System.assertEquals('Test Financial Customer', queriedBk.Customer_Name__c, 'Name should auto-populate from Opportunity Account');
        System.assertEquals('1234567890', queriedBk.Customer_Phone__c, 'Phone should auto-populate from Opportunity Account');
        System.assertEquals('102', queriedBk.Unit_Number__c, 'Unit Number should auto-populate from Unit');
        System.assertEquals('2', queriedBk.Floor__c, 'Floor should auto-populate from Unit');
        System.assertEquals(6000000.00, queriedBk.Base_Price__c, 'Base Price should auto-populate from Unit');
        System.assertEquals(opp2.Project__c, queriedBk.Project__c, 'Project lookup should copy');
        System.assertEquals(opp2.Tower__c, queriedBk.Tower__c, 'Tower lookup should copy');
        System.assertEquals(opp2.Unit__c, queriedBk.Unit__c, 'Unit lookup should copy');
    }
}
