@IsTest
private class PostSalesLedgerTriggerHandlerTest {
    private static Booking__c makeBooking() {
        Project__c project = new Project__c(
            Name = 'Test Lifecycle Project', Project_Code__c = 'TLP-001', Builder_Name__c = 'Test Builder',
            Project_Type__c = 'Apartment', Status__c = 'Ongoing', City__c = 'Bengaluru', State__c = 'Karnataka',
            Starting_Price__c = 1000000, Total_Units__c = 1
        );
        insert project;
        Tower__c tower = new Tower__c(
            Name = 'Test Tower', Project__c = project.Id, Status__c = 'Planned', Tower_Code__c = 'TT-A',
            Number_of_Floors__c = 1, Total_Units__c = 1
        );
        insert tower;
        Unit__c unit = new Unit__c(
            Name = 'T-101', Project__c = project.Id, Tower__c = tower.Id, Price__c = 1000000,
            Status__c = 'Available', Floor__c = 1, Unit_Type__c = '3 BHK', Area_Sq_Ft__c = 1500,
            Bedrooms__c = 3, Bathrooms__c = 3, Balcony__c = 2
        );
        insert unit;
        Opportunity opportunity = new Opportunity(
            Name = 'Test Lifecycle Opportunity', CloseDate = Date.today().addDays(30), StageName = 'Booking Confirmed',
            Project__c = project.Id, Unit__c = unit.Id, Booking_Amount__c = 100000,
            Payment_Mode__c = 'Bank Transfer', Expected_Registration_Date__c = Date.today().addDays(60)
        );
        insert opportunity;
        Booking__c booking = new Booking__c(
            Customer_Name__c = 'Test Customer', Unit_Number__c = 'T-101', Unit__c = unit.Id,
            Project__c = project.Id, Opportunity__c = opportunity.Id, Booking_Date__c = Date.today(),
            Booking_Amount__c = 100000, Booking_Status__c = 'Confirmed', Payment_Status__c = 'Pending'
        );
        insert booking;
        return booking;
    }

    @IsTest
    static void paymentCreatesReceiptAndApprovedReceiptUpdatesBooking() {
        Booking__c booking = makeBooking();
        Test.startTest();
        Payment_cu__c payment = new Payment_cu__c(
            Booking__c = booking.Id, Amount__c = 100000, Payment_Date__c = Date.today(),
            Payment_Mode__c = 'Bank Transfer', Payment_Status__c = 'Successful', Transaction_ID__c = 'TXN-100'
        );
        insert payment;
        Receipt__c receipt = [SELECT Id, Payment__c, Receipt_Status__c FROM Receipt__c WHERE Payment__c = :payment.Id];
        System.assertEquals('Draft', receipt.Receipt_Status__c);
        receipt.Receipt_Status__c = 'Pending Approval';
        update receipt;
        receipt.Receipt_Status__c = 'Approved';
        update receipt;
        Test.stopTest();

        Booking__c actual = [SELECT Total_Paid__c, Is_Locked__c FROM Booking__c WHERE Id = :booking.Id];
        System.assertEquals(100000, actual.Total_Paid__c);
        System.assertEquals(false, actual.Is_Locked__c);
    }
}
