@IsTest
private class PostSalesFullSuiteTest {

    @TestSetup
    static void setupTestData() {
        Project__c proj = new Project__c(
            Name = 'Greenfield Heights',
            Project_Code__c = 'GFH001',
            Builder_Name__c = 'Sunrise Developers',
            Project_Type__c = 'Apartment',
            Status__c = 'Ongoing',
            City__c = 'Bengaluru',
            State__c = 'Karnataka',
            Starting_Price__c = 7500000.00,
            Total_Units__c = 100
        );
        insert proj;

        Tower__c tow = new Tower__c(
            Name = 'Tower A',
            Project__c = proj.Id,
            Tower_Code__c = 'GFH-A',
            Number_of_Floors__c = 10,
            Total_Units__c = 40,
            Status__c = 'Under Construction'
        );
        insert tow;

        Unit__c u = new Unit__c(
            Name = 'A-101',
            Project__c = proj.Id,
            Tower__c = tow.Id,
            Floor__c = 1,
            Unit_Type__c = '2 BHK',
            Area_Sq_Ft__c = 1200,
            Bedrooms__c = 2,
            Bathrooms__c = 2,
            Balcony__c = 1,
            Status__c = 'Available',
            Price__c = 7500000.00
        );
        insert u;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Booking Confirmed',
            CloseDate = Date.today().addDays(30),
            Project__c = proj.Id,
            Unit__c = u.Id,
            Booking_Amount__c = 500000.00,
            Payment_Mode__c = 'Bank Transfer',
            Expected_Registration_Date__c = Date.today().addDays(60)
        );
        insert opp;
    }

    @IsTest
    static void testInterestCalculationEngine() {
        // Test Slide 18 & 23: Rs 10,00,000 for 30 days at 12% p.a. -> ~Rs 9,863.01
        Decimal principal = 1000000.00;
        Integer overdueDays = 30;
        Decimal rate = 12.0;

        Decimal interest = InterestCalculator.calculateDailyInterest(principal, overdueDays, rate);
        System.assertEquals(9863.01, interest, 'Daily interest calculation must match formula');

        // Test Slide 24: Interest applicable only when Agreement is Executed
        Boolean applicable = InterestCalculator.isInterestApplicable('Executed', 10);
        System.assertEquals(true, applicable, 'Interest should be applicable on executed agreements');

        Boolean notApplicable = InterestCalculator.isInterestApplicable('Draft', 10);
        System.assertEquals(false, notApplicable, 'Interest should not apply before execution');
    }

    @IsTest
    static void testReceiptsAndLockingFlow() {
        Opportunity opp = [SELECT Id, Project__c, Unit__c FROM Opportunity LIMIT 1];

        // Create Booking with standard required fields & Opportunity lookup
        Booking__c bk = new Booking__c(
            Customer_Name__c = 'Test Customer',
            Unit_Number__c = '201',
            Unit_Price__c = 10000000.00,
            Total_Paid__c = 0.00,
            Stage__c = 'New',
            Is_Locked__c = false,
            Booking_Date__c = Date.today(),
            Booking_Amount__c = 500000.00,
            Booking_Status__c = 'Confirmed',
            Payment_Status__c = 'Paid',
            Opportunity__c = opp.Id,
            Project__c = opp.Project__c,
            Unit__c = opp.Unit__c
        );
        insert bk;

        // Submit Receipt -> Pending = Frozen (Rule 2)
        Receipt__c rec = ReceiptService.submitReceiptForApproval(bk.Id, null, 500000.00, 'Bank Transfer', 'TXN-101');
        System.assertNotEquals(null, rec.Id, 'Receipt should be created');

        Booking__c lockedBk = [SELECT Is_Locked__c FROM Booking__c WHERE Id = :bk.Id];
        System.assertEquals(true, lockedBk.Is_Locked__c, 'Booking must be locked while receipt is pending');

        // Approve Receipt -> Official (Rule 4)
        ReceiptService.approveReceipt(rec.Id, 'Verified in HDFC bank ledger');
        Booking__c approvedBk = [SELECT Is_Locked__c, Total_Paid__c FROM Booking__c WHERE Id = :bk.Id];
        System.assertEquals(false, approvedBk.Is_Locked__c, 'Booking must unlock upon approval');
        System.assertEquals(500000.00, approvedBk.Total_Paid__c, 'Paid amount must be credited');

        // Reject a new receipt -> Dead (Rule 3)
        Receipt__c deadRec = ReceiptService.submitReceiptForApproval(bk.Id, null, 200000.00, 'Cheque', 'CHQ-999');
        ReceiptService.rejectReceipt(deadRec.Id, 'Cheque bounced');
        Receipt__c verifiedDead = [SELECT Receipt_Status__c FROM Receipt__c WHERE Id = :deadRec.Id];
        System.assertEquals('Rejected', verifiedDead.Receipt_Status__c, 'Rejected receipt is dead');
    }

    @IsTest
    static void testQuotationAndBookingConversion() {
        Opportunity opp = [SELECT Id, Project__c, Unit__c FROM Opportunity LIMIT 1];

        Quotation__c quote = new Quotation__c(
            Customer_Name__c = 'Pooja Verma',
            Total_Amount__c = 8500000.00,
            Booking_Amount__c = 425000.00,
            Status__c = 'Accepted'
        );
        insert quote;

        // Convert quote
        Booking__c createdBk = new Booking__c(
            Customer_Name__c = quote.Customer_Name__c,
            Unit_Number__c = '101',
            Unit_Price__c = quote.Total_Amount__c,
            Total_Paid__c = 0.00,
            Pending_Dues__c = quote.Total_Amount__c,
            Stage__c = 'New',
            Is_Locked__c = false,
            Booking_Date__c = Date.today(),
            Booking_Amount__c = quote.Booking_Amount__c,
            Booking_Status__c = 'Confirmed',
            Payment_Status__c = 'Paid',
            Opportunity__c = opp.Id,
            Project__c = opp.Project__c,
            Unit__c = opp.Unit__c
        );
        insert createdBk;

        quote.Status__c = 'Converted';
        update quote;

        Quotation__c convertedQuote = [SELECT Status__c FROM Quotation__c WHERE Id = :quote.Id];
        System.assertEquals('Converted', convertedQuote.Status__c, 'Quotation must be marked Converted');

        // Handover to CRM
        BookingService.pushBookingToCRM(createdBk.Id);
        Booking__c handedOverBk = [SELECT Stage__c FROM Booking__c WHERE Id = :createdBk.Id];
        System.assertEquals('Booked', handedOverBk.Stage__c, 'Stage should move to Booked');
    }

    @IsTest
    static void testCancellationAndSwapExceptions() {
        Opportunity opp = [SELECT Id, Project__c, Unit__c FROM Opportunity LIMIT 1];

        Booking__c bk = new Booking__c(
            Customer_Name__c = 'Amit Sharma',
            Unit_Number__c = '405',
            Unit_Price__c = 7500000.00,
            Total_Paid__c = 500000.00,
            Stage__c = 'Booked',
            Is_Locked__c = false,
            Booking_Date__c = Date.today(),
            Booking_Amount__c = 500000.00,
            Booking_Status__c = 'Confirmed',
            Payment_Status__c = 'Paid',
            Opportunity__c = opp.Id,
            Project__c = opp.Project__c,
            Unit__c = opp.Unit__c
        );
        insert bk;

        // Cancellation flow
        Cancellation__c cnc = CancellationService.initiateCancellation(bk.Id, 'Relocating to another city');
        System.assertEquals('Sales Head Approval', cnc.Status__c, 'Cancellation starts at Sales Head');

        CancellationService.approveCancellationByCRM(cnc.Id);
        Booking__c cancelledBk = [SELECT Stage__c FROM Booking__c WHERE Id = :bk.Id];
        System.assertEquals('Cancellation', cancelledBk.Stage__c, 'Booking stage must be Cancellation');

        // Swap flow on a new booking
        Booking__c swapSourceBk = new Booking__c(
            Customer_Name__c = 'Kavita Rao',
            Unit_Number__c = '102',
            Unit_Price__c = 9000000.00,
            Total_Paid__c = 1000000.00,
            Stage__c = 'Booked',
            Is_Locked__c = false,
            Booking_Date__c = Date.today(),
            Booking_Amount__c = 1000000.00,
            Booking_Status__c = 'Confirmed',
            Payment_Status__c = 'Paid',
            Opportunity__c = opp.Id,
            Project__c = opp.Project__c,
            Unit__c = opp.Unit__c
        );
        insert swapSourceBk;

        Swap__c swp = SwapService.initiateSwap(swapSourceBk.Id, '506');
        System.assertEquals('Sales Head Approval', swp.Status__c, 'Swap starts at Sales Head');
    }
}
