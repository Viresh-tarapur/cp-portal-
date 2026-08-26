@isTest
private class PropertyFinancialPlannerServiceTest {

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

        Account acc = new Account(Name = 'Test Financial Customer');
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

        Unit__c unit2 = new Unit__c(
            Name = '102',
            Project__c = proj.Id,
            Tower__c = tow.Id,
            Floor__c = 1,
            Unit_Type__c = '2 BHK',
            Area_Sq_Ft__c = 1200,
            Facing__c = 'North',
            Bedrooms__c = 2,
            Bathrooms__c = 2,
            Balcony__c = 1,
            Car_Parking__c = true,
            Base_Price__c = 6000000.00,
            Status__c = 'Blocked',
            Price__c = 6500000.00,
            Block_Expiry_Date__c = Datetime.now().addDays(-1)
        );
        insert unit2;
    }

    @isTest
    static void testFetchUnitPricingDetails() {
        Unit__c u = [SELECT Id FROM Unit__c WHERE Name = '101' LIMIT 1];
        Test.startTest();
        Map<String, Object> pricing = PropertyFinancialPlannerService.fetchUnitPricingDetails(u.Id);
        Test.stopTest();

        System.assertNotEquals(null, pricing, 'Pricing details map should not be null');
        System.assertEquals('101', pricing.get('unitNumber'));
        System.assertEquals(true, pricing.get('isAvailable'));
        System.assertEquals(8000000.00, pricing.get('basePrice'));
        System.assertEquals(12.00, pricing.get('projectInterestRate'));
    }

    @isTest
    static void testCostSheetCalculationAndApprovalCheck() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c WHERE Name = '101' LIMIT 1];

        Quotation__c quoteWithDiscount = new Quotation__c(
            Customer_Name__c = 'Ravi Kumar',
            Project__c = proj.Id,
            Unit__c = u.Id,
            Unit_Number__c = '101',
            Base_Price__c = 8000000.00,
            Parking_Charges__c = 300000.00,
            Other_Charges__c = 200000.00,
            Discount_Amount__c = 200000.00,
            Plan_Type__c = 'Standard Payment Plan',
            Funding_Type__c = 'Home Loan'
        );

        Test.startTest();
        Quotation__c calcQuote = PropertyFinancialPlannerService.calculateCostSheet(quoteWithDiscount);
        insert calcQuote;
        Test.stopTest();

        System.assertEquals('Pending Approval', calcQuote.Approval_Status__c, 'Cost sheet with discount requires approval');
        System.assert(calcQuote.Final_Property_Value__c > 0, 'Final property value must be computed');
    }

    @isTest
    static void testBookingCreationAndStandardPaymentSchedule() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c WHERE Name = '101' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Quotation__c quote = new Quotation__c(
            Customer_Name__c = 'Suresh Raina',
            Project__c = proj.Id,
            Unit__c = u.Id,
            Unit_Number__c = '101',
            Opportunity__c = opp.Id,
            Base_Price__c = 8000000.00,
            Parking_Charges__c = 300000.00,
            Other_Charges__c = 200000.00,
            Discount_Amount__c = 0.00,
            Final_Property_Value__c = 8925000.00,
            Booking_Amount__c = 500000.00,
            Plan_Type__c = 'Standard Payment Plan',
            Funding_Type__c = 'Home Loan',
            Status__c = 'Accepted'
        );
        insert quote;

        Test.startTest();
        Booking__c bk = BookingService.createBookingFromQuotation(quote.Id);
        Test.stopTest();

        System.assertNotEquals(null, bk.Id, 'Booking should be created from quotation');
        List<Payment_Schedule__c> schedules = [SELECT Id, Milestone_Name__c, Amount__c, Is_Active__c FROM Payment_Schedule__c WHERE Booking__c = :bk.Id];
        System.assertEquals(5, schedules.size(), 'Standard payment plan should generate 5 milestone lines');
    }

    @isTest
    static void testCustomPaymentScheduleAndPlanModification() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c WHERE Name = '101' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Booking__c bk = new Booking__c(
            Customer_Name__c = 'Meera Nair',
            Unit_Number__c = '101',
            Unit__c = u.Id,
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

        List<Payment_Schedule__c> customLines = new List<Payment_Schedule__c>{
            new Payment_Schedule__c(Milestone_Name__c = 'Custom Installment 1', Amount__c = 4500000.00, Percentage__c = 50.00),
            new Payment_Schedule__c(Milestone_Name__c = 'Custom Installment 2', Amount__c = 4500000.00, Percentage__c = 50.00)
        };

        Test.startTest();
        List<Payment_Schedule__c> insertedLines = PropertyFinancialPlannerService.generatePaymentSchedules(bk.Id, 'Custom Payment Plan', customLines);
        System.assertEquals(2, insertedLines.size(), '2 custom payment lines should be inserted');

        // Create and apply Payment Plan Modification
        Payment_Plan_Modification__c modReq = new Payment_Plan_Modification__c(
            Booking__c = bk.Id,
            Modification_Reason__c = 'Loan Delay',
            Proposed_Plan_Details__c = 'Rescheduled milestones due to bank loan approval cycle',
            Status__c = 'Approved'
        );
        insert modReq;

        PropertyFinancialPlannerService.applyPaymentPlanModification(modReq.Id);
        Test.stopTest();

        Payment_Plan_Modification__c updatedMod = [SELECT Status__c FROM Payment_Plan_Modification__c WHERE Id = :modReq.Id];
        System.assertEquals('Implemented', updatedMod.Status__c, 'Modification should be marked Implemented');
    }

    @isTest
    static void testRegistrationGateLoanVsSelfPayment() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c WHERE Name = '101' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        // 1. Home Loan Booking
        Booking__c loanBk = new Booking__c(
            Customer_Name__c = 'Karan Johar',
            Unit_Number__c = '101',
            Unit__c = u.Id,
            Project__c = proj.Id,
            Opportunity__c = opp.Id,
            Agreement_Value__c = 8500000.00,
            Funding_Type__c = 'Loan',
            Booking_Date__c = Date.today(),
            Booking_Amount__c = 500000.00,
            Booking_Status__c = 'Confirmed',
            Payment_Status__c = 'Pending',
            DD_Uploaded__c = true,
            DD_Reference__c = 'DD-HDFC-998877',
            Pending_Dues__c = 5000000.00,
            Is_Locked__c = false
        );
        insert loanBk;
        System.assertEquals(true, BookingService.validateRegistrationGate(loanBk.Id), 'Loan customer with DD uploaded is eligible for registration');

        // 2. Self Payment Booking (Dues Pending -> Ineligible)
        Tower__c tow = [SELECT Id FROM Tower__c LIMIT 1];
        Unit__c u2 = new Unit__c(
            Name = '103',
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
            Base_Price__c = 8500000.00,
            Price_per_Sq_Ft__c = 5666.66,
            Parking_Charges__c = 300000.00,
            Other_Charges__c = 200000.00,
            Status__c = 'Available',
            Price__c = 8500000.00
        );
        insert u2;

        Booking__c selfBk = new Booking__c(
            Customer_Name__c = 'Ananya Sen',
            Unit_Number__c = '103',
            Unit__c = u2.Id,
            Project__c = proj.Id,
            Opportunity__c = opp.Id,
            Agreement_Value__c = 8500000.00,
            Funding_Type__c = 'Self-payment',
            Booking_Date__c = Date.today(),
            Booking_Amount__c = 500000.00,
            Booking_Status__c = 'Confirmed',
            Payment_Status__c = 'Pending',
            Pending_Dues__c = 2000000.00,
            Is_Locked__c = false
        );
        insert selfBk;
        System.assertEquals(false, BookingService.validateRegistrationGate(selfBk.Id), 'Self-payment customer with dues is not eligible');

        // Clear dues
        selfBk.Pending_Dues__c = 0.00;
        update selfBk;
        System.assertEquals(true, BookingService.validateRegistrationGate(selfBk.Id), 'Self-payment customer with 0 dues is eligible');
    }

    @isTest
    static void testReleaseExpiredUnitBlocks() {
        Test.startTest();
        PropertyFinancialPlannerService.releaseExpiredUnitBlocks();
        Test.stopTest();

        Unit__c u = [SELECT Status__c, Block_Expiry_Date__c FROM Unit__c WHERE Name = '102' LIMIT 1];
        System.assertEquals('Available', u.Status__c, 'Expired blocked unit must be reset to Available');
        System.assertEquals(null, u.Block_Expiry_Date__c, 'Expiry date should be cleared');
    }

    @isTest
    static void testOpportunityLeadConversionPopulate() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c WHERE Name = '101' LIMIT 1];

        Lead ld = new Lead(
            LastName = 'Lead Test Customer',
            Company = 'Lead Corp',
            Status = 'Open - Not Contacted',
            LeadSource = 'Web',
            Phone = '9876543210',
            Email = 'leadtest@corp.com',
            Description = 'Interested in 3BHK flat',
            Property_Type__c = 'Apartment',
            Preferred_Unit_Type__c = '3 BHK',
            Preferred_Location__c = 'Bengaluru',
            Next_Follow_up_Date__c = Date.today().addDays(7),
            Customer_Priority__c = 'High',
            Project__c = proj.Id
        );
        insert ld;
        
        
        Account acc = new Account(Name = 'Converted Lead Account');
        insert acc;
        
        Test.startTest();
        LeadConversionContext.convertedLeadsByAccountId.put(acc.Id, ld);
        
        Opportunity opp = new Opportunity(
            Name = 'Converted Lead Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(60),
            Project__c = proj.Id,
            Unit__c = u.Id,
            Booking_Amount__c = 500000.00,
            Expected_Registration_Date__c = Date.today().addDays(60)
        );
        insert opp;
        Test.stopTest();
        
        Opportunity queried = [SELECT Id, LeadSource, Description FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Web', queried.LeadSource, 'Opportunity LeadSource should be populated from converted Lead');
        System.assertEquals('Interested in 3BHK flat', queried.Description, 'Opportunity Description should be populated from converted Lead');
    }

    @isTest
    static void testOpportunityUnitPricingAndAmount() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Tower__c tow = [SELECT Id FROM Tower__c LIMIT 1];
        
        Unit__c u3 = new Unit__c(
            Name = '104',
            Project__c = proj.Id,
            Tower__c = tow.Id,
            Floor__c = 3,
            Unit_Type__c = '3 BHK',
            Area_Sq_Ft__c = 1500,
            Facing__c = 'East',
            Bedrooms__c = 3,
            Bathrooms__c = 3,
            Balcony__c = 2,
            Car_Parking__c = true,
            Base_Price__c = 5000000.00,
            Parking_Charges__c = 200000.00,
            Other_Charges__c = 100000.00,
            Status__c = 'Available',
            Price__c = 5300000.00
        );
        insert u3;
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        Opportunity opp = new Opportunity(
            Name = 'Opp Unit Pricing Test',
            AccountId = acc.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(60),
            Project__c = proj.Id,
            Unit__c = u3.Id,
            Discount__c = 10, // 10% discount
            Booking_Amount__c = 500000.00,
            Expected_Registration_Date__c = Date.today().addDays(60)
        );
        insert opp;
        Test.stopTest();
        
        // Subtotal = 5,000,000 + 200,000 + 100,000 = 5,300,000
        // Discount = 530,000
        // Taxable = 4,770,000
        // Taxes = 238,500
        // Final Value = 5,008,500
        Opportunity queried = [SELECT Id, Amount FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(5008500.00, queried.Amount, 'Opportunity Amount should match computed property value');
    }

    @isTest
    static void testLeadRegistrationDateSynchronization() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c WHERE Name = '101' LIMIT 1];
        
        Partner__c partner = new Partner__c(
            Name = 'Test Partner Agency Ref',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Email__c = 'refpartner@test.com',
            Phone__c = '9191919191'
        );
        insert partner;

        Lead_Registration__c reg = new Lead_Registration__c(
            Customer_Name__c = 'Kirti Vyas',
            Customer_Phone__c = '9900887766',
            Customer_Email__c = 'kirti@vyas.com',
            Project__c = proj.Id,
            Expected_Purchase_Date__c = Date.today().addDays(30),
            Partner__c = partner.Id
        );
        insert reg;
        
        Opportunity opp = new Opportunity(
            Name = 'Opp Registration Date Test',
            AccountId = acc.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(60),
            Project__c = proj.Id,
            Unit__c = u.Id,
            Lead_Registration__c = reg.Id,
            Booking_Amount__c = 500000.00,
            Expected_Registration_Date__c = Date.today().addDays(30)
        );
        insert opp;
        
        Opportunity queriedInit = [SELECT Id, Expected_Registration_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(Date.today().addDays(30), queriedInit.Expected_Registration_Date__c, 'Expected registration date should map on insert');
        
        Test.startTest();
        reg.Expected_Purchase_Date__c = Date.today().addDays(45);
        update reg;
        Test.stopTest();
        
        Opportunity queriedUpdated = [SELECT Id, Expected_Registration_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(Date.today().addDays(45), queriedUpdated.Expected_Registration_Date__c, 'Opportunity expected registration date should synchronize');
    }
}
