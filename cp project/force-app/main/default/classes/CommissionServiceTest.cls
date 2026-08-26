@isTest
private class CommissionServiceTest {

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Prestige Partner Network',
            Email__c = 'partner@prestige.com',
            Phone__c = '+91 9900112233',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Partner_Tier__c = 'Platinum',
            Commission_Eligible__c = true,
            GST_Number__c = '29ABCDE1234F1Z5',
            PAN_Number__c = 'ABCDE1234F'
        );
        insert partner;

        Project__c proj = new Project__c(
            Name = 'Prestige Lakefront',
            Project_Code__c = 'PRJ-PLF-001',
            Active__c = true,
            Status__c = 'Ongoing',
            City__c = 'Bengaluru'
        );
        insert proj;

        Commission_Rule__c rule = new Commission_Rule__c(
            Name = 'Platinum Tier 3% Scheme',
            Project__c = proj.Id,
            Partner_Tier__c = 'Platinum',
            Commission_Type__c = 'Percentage',
            Commission_Rate__c = 3.00,
            Effective_From__c = Date.today().addDays(-30),
            Active__c = true
        );
        insert rule;

        Booking__c booking = new Booking__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Agreement_Value__c = 10000000,
            Booking_Amount__c = 500000,
            Booking_Date__c = Date.today(),
            Booking_Status__c = 'Booked'
        );
        insert booking;
    }

    @isTest
    static void testCommissionCalculationAndGeneration() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

        Test.startTest();
        Commission__c comm = CommissionService.generateCommissionForBooking(b.Id);
        Test.stopTest();

        System.assertNotEquals(null, comm.Id, 'Commission should be created');
        System.assertEquals(10000000, comm.Property_Value__c);
        System.assertEquals(3.00, comm.Commission_Rate__c);
        System.assertEquals(300000, comm.Gross_Commission__c);
        System.assertEquals(15000, comm.Tax_Deduction__c); // 5% TDS
        System.assertEquals(54000, comm.GST_Amount__c); // 18% GST for registered partner
        System.assertEquals(339000, comm.Net_Commission__c); // 300000 - 15000 + 54000
    }

    @isTest
    static void testCommissionApprovalWorkflow() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        Commission__c comm = CommissionService.generateCommissionForBooking(b.Id);

        Test.startTest();
        Commission__c approved = CommissionService.approveCommission(comm.Id, 'Verified and approved for payment');
        Test.stopTest();

        System.assertEquals('Approved', approved.Approval_Status__c);
        System.assertNotEquals(null, approved.Approved_Date__c);

        Partner__c p = [SELECT Total_Commission_Earned__c, Total_Commission_Pending__c FROM Partner__c WHERE Id = :comm.Partner__c];
        System.assertEquals(339000, p.Total_Commission_Earned__c);
    }

    @isTest
    static void testCommissionRejectionWorkflow() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        Commission__c comm = CommissionService.generateCommissionForBooking(b.Id);

        Test.startTest();
        Commission__c rejected = CommissionService.rejectCommission(comm.Id, 'Customer cancellation initiated');
        Test.stopTest();

        System.assertEquals('Rejected', rejected.Approval_Status__c);
        System.assertEquals('Customer cancellation initiated', rejected.Rejection_Reason__c);
    }

    @isTest
    static void testCommissionControllerSummary() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        Commission__c comm = CommissionService.generateCommissionForBooking(b.Id);
        CommissionService.approveCommission(comm.Id, 'Approved');

        Test.startTest();
        CommissionService.CommissionSummaryWrapper summary = CommissionController.getMyCommissions();
        Test.stopTest();

        System.assertNotEquals(null, summary);
        System.assertEquals(1, summary.approvedCount);
        System.assertEquals(339000, summary.totalEarned);
    }

    @isTest
    static void testFixedAmountCommissionCalculation() {
        Partner__c partner = [SELECT Id FROM Partner__c LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Commission_Rule__c fixedRule = new Commission_Rule__c(
            Name = 'Fixed 50k Incentive',
            Project__c = proj.Id,
            Partner_Tier__c = 'Platinum',
            Commission_Type__c = 'Fixed Amount',
            Fixed_Amount__c = 50000,
            Effective_From__c = Date.today().addDays(-5),
            Active__c = true
        );
        insert fixedRule;

        Test.startTest();
        CommissionCalculator.CalculationResult res = CommissionCalculator.calculateCommission(partner.Id, proj.Id, 2000000, Date.today());
        Test.stopTest();

        System.assertNotEquals(null, res);
    }
}
