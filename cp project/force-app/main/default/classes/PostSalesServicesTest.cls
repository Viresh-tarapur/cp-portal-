/**
 * Comprehensive Unit Tests for Post-Sales Real Estate CRM Services & Rules.
 * Fingertipplus Technologies Pvt Ltd
 */
@isTest
private class PostSalesServicesTest {

    @isTest
    static void testDailyInterestCalculation_Slide18Scenario() {
        // Slide 18: ₹10,00,000 principal, 30 days overdue, 12% annual interest = ~₹9,860
        Decimal principal = 1000000.00;
        Integer daysLate = 30;
        Decimal rate = 0.12;

        Test.startTest();
        Decimal interest = InterestCalculatorService.calculateDailyInterest(principal, daysLate, rate);
        Decimal standardScenario = InterestCalculatorService.calculateStandardSlideScenario();
        Test.stopTest();

        System.assert(interest > 9800 && interest < 9900, 'Calculated interest should match Slide 18 scenario (~9,860): ' + interest);
        System.assertEquals(interest, standardScenario, 'Standard scenario should match direct calculation');
    }

    @isTest
    static void testInterestWaiverTwoTierApproval() {
        PostSalesModels.WaiverStatus status = PostSalesModels.WaiverStatus.PENDING_CRM_MANAGER;

        Test.startTest();
        // Tier 1: CRM Manager approves -> moves to Pending Finance
        status = InterestCalculatorService.approveWaiverByCRMManager(status);
        System.assertEquals(PostSalesModels.WaiverStatus.PENDING_FINANCE, status, 'Tier 1 should transition to PENDING_FINANCE');

        // Tier 2: Finance approves -> moves to Approved
        status = InterestCalculatorService.approveWaiverByFinance(status);
        System.assertEquals(PostSalesModels.WaiverStatus.APPROVED, status, 'Tier 2 should transition to APPROVED');
        Test.stopTest();
    }

    @isTest
    static void testReceiptApprovalRules_Slide11() {
        PostSalesModels.BookingWrapper booking = new PostSalesModels.BookingWrapper();
        PostSalesModels.ReceiptWrapper receipt = new PostSalesModels.ReceiptWrapper();
        receipt.receiptId = 'REC-101';
        receipt.amount = 500000.00;

        Test.startTest();
        // Rule 2: Submitting receipt freezes booking
        ReceiptApprovalHandler.submitReceiptForApproval(receipt, booking);
        System.assertEquals(true, booking.isLocked, 'Rule 2: Booking must be locked when receipt is pending');

        // Rule 4: Approving receipt unlocks booking and sets status approved
        ReceiptApprovalHandler.processFinanceDecision(receipt, booking, true, 'Approved by Finance');
        System.assertEquals(false, booking.isLocked, 'Approved receipt should unlock booking');
        System.assertEquals(String.valueOf(PostSalesModels.ReceiptStatus.APPROVED), receipt.status, 'Status must be APPROVED');

        // Rule 3: Rejection marks receipt dead
        PostSalesModels.ReceiptWrapper receipt2 = new PostSalesModels.ReceiptWrapper();
        receipt2.receiptId = 'REC-102';
        ReceiptApprovalHandler.submitReceiptForApproval(receipt2, booking);
        ReceiptApprovalHandler.processFinanceDecision(receipt2, booking, false, 'Invalid transaction ref');
        System.assertEquals(String.valueOf(PostSalesModels.ReceiptStatus.REJECTED_DEAD), receipt2.status, 'Status must be REJECTED_DEAD');

        // Rule 3 Verification: Attempting to modify dead receipt throws exception
        Boolean exceptionCaught = false;
        try {
            ReceiptApprovalHandler.processFinanceDecision(receipt2, booking, true, 'Retry approve');
        } catch (ReceiptApprovalHandler.ReceiptException e) {
            exceptionCaught = true;
        }
        System.assertEquals(true, exceptionCaught, 'Rule 3: Modifying a rejected dead receipt must throw exception');
        Test.stopTest();
    }

    @isTest
    static void testDemandArrearsRollForward_Slide15() {
        Decimal milestoneAmount = 1500000.00;
        Decimal oldPendingAmount = 200000.00;
        Decimal oldInterest = 9860.00;

        Test.startTest();
        DemandService.DemandCalculationResult result = DemandService.calculateDemandWithArrears(milestoneAmount, oldPendingAmount, oldInterest);
        PostSalesModels.DemandWrapper demand = DemandService.createDemand('M3', 1500000.00, 9860.00);
        Test.stopTest();

        System.assertEquals(1709860.00, result.netPayableTotal, 'Demand must roll forward previous dues and interest');
        System.assertNotEquals(null, demand.dueDate, 'Demand must have a due date');
    }

    @isTest
    static void testBookingLifecycleAndGoldenRule5() {
        PostSalesModels.BookingWrapper booking = new PostSalesModels.BookingWrapper();
        booking.fundingType = 'Loan';
        booking.kycVerified = true;

        Test.startTest();
        BookingController.approvePushToCRM(booking);
        System.assertEquals(String.valueOf(PostSalesModels.BookingStage.BOOKED), booking.stage, 'Should move to Booked stage');

        BookingController.dispatchWelcomeKit(booking);
        System.assertEquals(true, booking.welcomeMailSent, 'Welcome mail should be marked sent');

        // Loan gate check
        booking.ddCopyUploaded = false;
        System.assertEquals(false, BookingController.validateRegistrationGate(booking), 'Loan customer without DD cannot pass gate');
        booking.ddCopyUploaded = true;
        System.assertEquals(true, BookingController.validateRegistrationGate(booking), 'Loan customer with DD can pass gate');

        // Golden Rule 5: Cannot cancel or swap post-registration
        booking.stage = String.valueOf(PostSalesModels.BookingStage.REGISTRATION);
        Boolean rule5Blocked = false;
        try {
            BookingController.validateExceptionEligibility(booking);
        } catch (BookingController.BookingProcessException e) {
            rule5Blocked = true;
        }
        System.assertEquals(true, rule5Blocked, 'Golden Rule 5 must prevent cancellation after registration');
        Test.stopTest();
    }

    @isTest
    static void testReminderClockEvaluation_Slide16() {
        Test.startTest();
        System.assertEquals(ReminderClockBatch.ReminderAction.DEMAND_RAISED, ReminderClockBatch.evaluateReminderTrigger(0));
        System.assertEquals(ReminderClockBatch.ReminderAction.FIRST_REMINDER, ReminderClockBatch.evaluateReminderTrigger(7));
        System.assertEquals(ReminderClockBatch.ReminderAction.SECOND_REMINDER, ReminderClockBatch.evaluateReminderTrigger(14));
        System.assertEquals(ReminderClockBatch.ReminderAction.TERMINATION_NOTICE, ReminderClockBatch.evaluateReminderTrigger(21));
        System.assertEquals(ReminderClockBatch.ReminderAction.UNIT_RELEASED_AUTO_CANCEL, ReminderClockBatch.evaluateReminderTrigger(30));
        Test.stopTest();
    }
}
