/**
 * @description Comprehensive Test Suite for Lead Pre-Sales Journey and Opportunity Commercial / Post-Sales Lifecycle.
 * Validates stage progressions, field retention, validation rules, and exception handlers.
 */
@isTest
private class LeadOpportunityLifecycleTest {

    @testSetup
    static void setupTestData() {
        Project__c proj = new Project__c(
            Name = 'Grand Heritage Residency',
            Project_Code__c = 'GHR-001',
            Builder_Name__c = 'Grand Builders',
            Project_Type__c = 'Apartment',
            Status__c = 'Ongoing',
            City__c = 'Bengaluru',
            State__c = 'Karnataka',
            Starting_Price__c = 6500000.00,
            Total_Units__c = 50
        );
        insert proj;

        Tower__c tower = new Tower__c(
            Name = 'Tower Alpha',
            Tower_Code__c = 'TWR-A',
            Number_of_Floors__c = 14,
            Total_Units__c = 50,
            Status__c = 'Ready to Move',
            Project__c = proj.Id
        );
        insert tower;

        Unit__c unit = new Unit__c(
            Name = 'A-502',
            Project__c = proj.Id,
            Tower__c = tower.Id,
            Unit_Type__c = '3 BHK',
            Floor__c = 5,
            Area_Sq_Ft__c = 1650,
            Bedrooms__c = 3,
            Bathrooms__c = 3,
            Balcony__c = 2,
            Price__c = 8500000.00,
            Status__c = 'Available'
        );
        insert unit;

        Account acc = new Account(
            Name = 'Rajesh Sharma',
            Phone = '9876543210',
            Rating = 'Hot'
        );
        insert acc;
    }

    /**
     * @description Test 1: Complete 9-stage Lead Pre-Sales Path progression.
     */
    @isTest
    static void test01_LeadPreSalesLifecycleProgression() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        // 1. New Lead (API: Open - Not Contacted)
        Lead l = new Lead(
            FirstName = 'Rajesh',
            LastName = 'Sharma',
            Company = 'Self-Employed',
            Email = 'rajesh.sharma@example.com',
            Phone = '9876543210',
            Budget__c = 8500000.00,
            Project__c = proj.Id,
            Property_Type__c = 'Apartment',
            Preferred_Unit_Type__c = '3 BHK',
            Preferred_Location__c = 'Bengaluru',
            Customer_Priority__c = 'High',
            Next_Follow_up_Date__c = Date.today().addDays(3),
            Status = 'Open - Not Contacted'
        );
        insert l;

        Lead q1 = [SELECT Id, Status FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Open - Not Contacted', q1.Status, 'Stage 1 should be New Lead');

        // 2. Qualification
        l.Status = 'Qualification';
        update l;
        System.assertEquals('Qualification', [SELECT Status FROM Lead WHERE Id = :l.Id].Status);

        // 3. Needs Analysis
        l.Status = 'Needs Analysis';
        update l;
        System.assertEquals('Needs Analysis', [SELECT Status FROM Lead WHERE Id = :l.Id].Status);

        // 4. Site Visit Scheduled
        l.Status = 'Site Visit Scheduled';
        update l;
        System.assertEquals('Site Visit Scheduled', [SELECT Status FROM Lead WHERE Id = :l.Id].Status);

        // 5. Site Visit Completed
        l.Status = 'Site Visit Completed';
        update l;
        System.assertEquals('Site Visit Completed', [SELECT Status FROM Lead WHERE Id = :l.Id].Status);

        // 6. Negotiation
        l.Status = 'Negotiation';
        update l;
        System.assertEquals('Negotiation', [SELECT Status FROM Lead WHERE Id = :l.Id].Status);

        // 7. Unit Selected
        l.Status = 'Unit Selected';
        update l;
        System.assertEquals('Unit Selected', [SELECT Status FROM Lead WHERE Id = :l.Id].Status);

        // 8. Booking Initiated
        l.Status = 'Booking Initiated';
        update l;
        System.assertEquals('Booking Initiated', [SELECT Status FROM Lead WHERE Id = :l.Id].Status);
    }

    /**
     * @description Test 2: Complete 7-stage Opportunity Commercial / Post-Sales Path progression.
     */
    @isTest
    static void test02_OpportunityPostSalesLifecycleProgression() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // 1. Booking Confirmed
        Opportunity opp = new Opportunity(
            Name = 'Rajesh Sharma - A-502 Purchase',
            AccountId = acc.Id,
            Project__c = proj.Id,
            Unit__c = unit.Id,
            Booking_Amount__c = 500000.00,
            Payment_Mode__c = 'Bank Transfer',
            Expected_Registration_Date__c = Date.today().addDays(60),
            CloseDate = Date.today().addDays(60),
            StageName = 'Booking Confirmed'
        );
        insert opp;
        System.assertEquals('Booking Confirmed', [SELECT StageName FROM Opportunity WHERE Id = :opp.Id].StageName);

        // 2. Payment
        opp.StageName = 'Payment';
        update opp;
        System.assertEquals('Payment', [SELECT StageName FROM Opportunity WHERE Id = :opp.Id].StageName);

        // 3. Documents
        opp.StageName = 'Documents';
        update opp;
        System.assertEquals('Documents', [SELECT StageName FROM Opportunity WHERE Id = :opp.Id].StageName);

        // 4. Agreement
        opp.StageName = 'Agreement';
        update opp;
        System.assertEquals('Agreement', [SELECT StageName FROM Opportunity WHERE Id = :opp.Id].StageName);

        // 5. Registration
        opp.StageName = 'Registration';
        update opp;
        System.assertEquals('Registration', [SELECT StageName FROM Opportunity WHERE Id = :opp.Id].StageName);

        // 6. Handover
        opp.StageName = 'Handover';
        update opp;
        System.assertEquals('Handover', [SELECT StageName FROM Opportunity WHERE Id = :opp.Id].StageName);

        // 7. Closed Won
        opp.StageName = 'Closed Won';
        update opp;
        Opportunity finalOpp = [SELECT StageName, IsWon, IsClosed FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Closed Won', finalOpp.StageName);
        System.assertEquals(true, finalOpp.IsWon);
        System.assertEquals(true, finalOpp.IsClosed);
    }

    /**
     * @description Test 3: Lead and Opportunity Validation Rules.
     */
    @isTest
    static void test03_ValidationRulesEnforcement() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // Lead: Budget > 0
        Lead invalidLeadBudget = new Lead(
            FirstName = 'Invalid',
            LastName = 'Budget',
            Company = 'Test Co',
            Budget__c = -100,
            Status = 'Open - Not Contacted'
        );
        Boolean budgetErrorCaught = false;
        try {
            insert invalidLeadBudget;
        } catch (DmlException e) {
            budgetErrorCaught = true;
        }
        System.assertEquals(true, budgetErrorCaught, 'Budget <= 0 should be blocked by validation rule');

        // Opportunity: Missing Project
        Opportunity invalidOppProj = new Opportunity(
            Name = 'Missing Project Opp',
            AccountId = acc.Id,
            Unit__c = null,
            Booking_Amount__c = 500000.00,
            Payment_Mode__c = 'Bank Transfer',
            Expected_Registration_Date__c = Date.today().addDays(60),
            CloseDate = Date.today().addDays(60),
            StageName = 'Booking Confirmed'
        );
        Boolean projErrorCaught = false;
        try {
            insert invalidOppProj;
        } catch (DmlException e) {
            projErrorCaught = true;
        }
        System.assertEquals(true, projErrorCaught, 'Missing Project on Opportunity should be blocked');

        // Opportunity: Missing Unit
        Opportunity invalidOppUnit = new Opportunity(
            Name = 'Missing Unit Opp',
            AccountId = acc.Id,
            Project__c = proj.Id,
            Booking_Amount__c = 500000.00,
            Payment_Mode__c = 'Bank Transfer',
            Expected_Registration_Date__c = Date.today().addDays(60),
            CloseDate = Date.today().addDays(60),
            StageName = 'Booking Confirmed'
        );
        Boolean unitErrorCaught = false;
        try {
            insert invalidOppUnit;
        } catch (DmlException e) {
            unitErrorCaught = true;
        }
        System.assertEquals(true, unitErrorCaught, 'Missing Unit on Opportunity should be blocked');
    }

    /**
     * @description Test 4: Exception Handling (Cancellation, Refund, Unit Swap).
     */
    @isTest
    static void test04_ExceptionProcesses() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c unit1 = [SELECT Id FROM Unit__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Exception Test Opp',
            AccountId = acc.Id,
            Project__c = proj.Id,
            Unit__c = unit1.Id,
            Booking_Amount__c = 500000.00,
            Payment_Mode__c = 'Bank Transfer',
            Expected_Registration_Date__c = Date.today().addDays(60),
            CloseDate = Date.today().addDays(60),
            StageName = 'Booking Confirmed'
        );
        insert opp;

        Booking__c booking = new Booking__c(
            Customer_Name__c = 'Rajesh Sharma',
            Unit_Number__c = 'A-502',
            Booking_Amount__c = 500000.00,
            Booking_Date__c = Date.today(),
            Booking_Status__c = 'Confirmed',
            Payment_Status__c = 'Pending',
            Opportunity__c = opp.Id,
            Project__c = proj.Id,
            Unit__c = unit1.Id
        );
        insert booking;

        // Exception 1: Unit Swap
        Swap__c swap = new Swap__c(
            Booking__c = booking.Id,
            New_Unit_Number__c = 'B-601',
            Status__c = 'Approved'
        );
        insert swap;
        System.assertNotEquals(null, swap.Id, 'Unit Swap record should be created');

        // Exception 2: Cancellation
        Cancellation__c cancel = new Cancellation__c(
            Booking__c = booking.Id,
            Reason__c = 'Relocation to another city',
            Status__c = 'Approved'
        );
        insert cancel;
        System.assertNotEquals(null, cancel.Id, 'Cancellation record should be created');

        // Exception 3: Refund
        Refund__c refund = new Refund__c(
            Booking__c = booking.Id,
            Amount__c = 450000.00,
            Status__c = 'Pending Finance'
        );
        insert refund;
        System.assertNotEquals(null, refund.Id, 'Refund record should be created');
    }

    /**
     * @description Test 5: Verify Lead-to-Opportunity flow creation works without Booking Amount.
     */
    @isTest
    static void test05_LeadToOpportunityWithoutBookingAmount() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'WithoutBooking',
            Company = 'No Budget Co',
            Email = 'nobudget@example.com',
            Phone = '9999999999',
            Budget__c = null, // No budget/booking amount
            Project__c = proj.Id,
            Property_Type__c = 'Apartment',
            Preferred_Unit_Type__c = '3 BHK',
            Preferred_Location__c = 'Bengaluru',
            Customer_Priority__c = 'High',
            Next_Follow_up_Date__c = Date.today().addDays(3),
            Status = 'Open - Not Contacted'
        );
        insert l;

        // Transition lead to Booking Initiated to trigger the Flow
        l.Status = 'Booking Initiated';
        Test.startTest();
        update l;
        Test.stopTest();

        // Verify that the Opportunity was successfully created
        List<Opportunity> createdOpps = [SELECT Id, Name, Unit__c, Project__c, Amount, Booking_Amount__c, StageName FROM Opportunity WHERE Project__c = :proj.Id AND StageName = 'Booking Confirmed' AND Name = 'WithoutBooking'];
        System.assertEquals(1, createdOpps.size(), 'One Opportunity should have been created');
        Opportunity opp = createdOpps[0];
        System.assertEquals(unit.Id, opp.Unit__c, 'Unit__c should be populated');
        System.assertEquals(proj.Id, opp.Project__c, 'Project__c should be populated');
        System.assertNotEquals(null, opp.Amount, 'Amount should be computed');
        System.assertEquals(null, opp.Booking_Amount__c, 'Booking_Amount__c should be blank');
    }
}
