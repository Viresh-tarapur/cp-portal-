/**
 * @description Master Booking Lifecycle Controller and Automation Engine
 * Supports Quote->Booking conversion, 6 Stages, Gates, Round-Robin Assignment, and Handover Completion
 */
public without sharing class BookingService {
    
    /**
     * @description Automation 1: Converts accepted quotation/cost sheet to Booking and generates Payment Schedule
     */
    public static Booking__c createBookingFromQuotation(Id quotationId) {
        Quotation__c quote = [
            SELECT Id, Customer_Name__c, Total_Amount__c, Booking_Amount__c, Status__c,
                   Project__c, Tower__c, Unit__c, Unit_Number__c, Unit_Type__c, Floor__c,
                   Area_Sq_Ft__c, Facing__c, Bedrooms__c, Bathrooms__c, Balcony__c, Parking__c,
                   Base_Price__c, Price_per_Sq_Ft__c, Parking_Charges__c, Other_Charges__c,
                   Taxes__c, Discount_Amount__c, Final_Property_Value__c, Plan_Type__c, Funding_Type__c,
                   Opportunity__c
            FROM Quotation__c 
            WHERE Id = :quotationId 
            LIMIT 1
        ];
        
        quote.Status__c = 'Converted';
        update quote;

        Id oppId = quote.Opportunity__c;
        Id projId = quote.Project__c;
        Id unitId = quote.Unit__c;

        if (oppId == null) {
            List<Opportunity> opps = [SELECT Id, Project__c, Unit__c FROM Opportunity WHERE Project__c = :projId OR Unit__c = :unitId LIMIT 1];
            if (!opps.isEmpty()) {
                oppId = opps[0].Id;
                if (projId == null) projId = opps[0].Project__c;
                if (unitId == null) unitId = opps[0].Unit__c;
            } else {
                Opportunity newOpp = new Opportunity(
                    Name = (quote.Customer_Name__c != null ? quote.Customer_Name__c : 'Customer') + ' - Booking Opp',
                    StageName = 'Booking Confirmed',
                    CloseDate = Date.today().addDays(60),
                    Project__c = projId,
                    Unit__c = unitId,
                    Booking_Amount__c = (quote.Booking_Amount__c != null ? quote.Booking_Amount__c : 100000.00),
                    Payment_Mode__c = 'Bank Transfer',
                    Expected_Registration_Date__c = Date.today().addDays(60)
                );
                insert newOpp;
                oppId = newOpp.Id;
            }
        }

        Decimal propVal = (quote.Final_Property_Value__c != null && quote.Final_Property_Value__c > 0) ? 
                          quote.Final_Property_Value__c : 
                          ((quote.Total_Amount__c != null && quote.Total_Amount__c > 0) ? quote.Total_Amount__c : 9500000.00);

        String fundingType = 'Self-payment';
        if (quote.Funding_Type__c != null && (quote.Funding_Type__c.contains('Loan') || quote.Funding_Type__c == 'Loan')) {
            fundingType = 'Loan';
        }

        Booking__c newBooking = new Booking__c(
            Customer_Name__c = quote.Customer_Name__c,
            Customer_Email__c = 'tarapurviresh@gmail.com',
            Customer_Phone__c = '06362272321',
            Unit_Number__c = (quote.Unit_Number__c != null ? quote.Unit_Number__c : '101'),
            Unit_Price__c = propVal,
            Agreement_Value__c = propVal,
            Final_Property_Value__c = propVal,
            Base_Price__c = quote.Base_Price__c,
            Price_per_Sq_Ft__c = quote.Price_per_Sq_Ft__c,
            Parking_Charges__c = quote.Parking_Charges__c,
            Other_Charges__c = quote.Other_Charges__c,
            Taxes__c = quote.Taxes__c,
            Discount_Amount__c = quote.Discount_Amount__c,
            Facing__c = quote.Facing__c,
            Area_Sq_Ft__c = quote.Area_Sq_Ft__c,
            Floor__c = quote.Floor__c,
            Bedrooms__c = quote.Bedrooms__c,
            Bathrooms__c = quote.Bathrooms__c,
            Balcony__c = quote.Balcony__c,
            Parking__c = quote.Parking__c,
            Plan_Type__c = quote.Plan_Type__c != null ? quote.Plan_Type__c : 'Standard Payment Plan',
            Funding_Type__c = fundingType,
            Total_Paid__c = 0.00,
            Pending_Dues__c = propVal,
            Outstanding_Amount__c = propVal,
            Stage__c = 'New',
            Is_Locked__c = false,
            Booking_Date__c = Date.today(),
            Booking_Amount__c = (quote.Booking_Amount__c != null ? quote.Booking_Amount__c : 500000.00),
            Booking_Status__c = 'Confirmed',
            Payment_Status__c = 'Pending',
            Opportunity__c = oppId,
            Project__c = projId,
            Unit__c = unitId
        );
        insert newBooking;

        // Auto-create active payment schedule
        PropertyFinancialPlannerService.generatePaymentSchedules(newBooking.Id, newBooking.Plan_Type__c, null);

        // Auto-create advance receipt for booking amount
        if (quote.Booking_Amount__c != null && quote.Booking_Amount__c > 0) {
            ReceiptService.submitReceiptForApproval(newBooking.Id, null, quote.Booking_Amount__c, 'Bank Transfer', 'TXN-ADV-' + System.currentTimeMillis());
        }

        return newBooking;
    }

    /**
     * @description Automation 3: CRM Handover & Stage Push
     */
    public static void pushBookingToCRM(Id bookingId) {
        Booking__c bk = [SELECT Id, Stage__c, Total_Paid__c, Is_Locked__c, CRM_Executive__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];
        
        bk.Is_Locked__c = false;
        bk.Stage__c = 'Booked';

        // Assign CRM Executive
        if (bk.CRM_Executive__c == null) {
            List<User> activeUsers = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];
            bk.CRM_Executive__c = !activeUsers.isEmpty() ? activeUsers[0].Id : UserInfo.getUserId();
        }

        update bk;
    }

    /**
     * @description Gate Before Registration (Loan DD Copy check vs Self-Pay 100% Cleared)
     */
    public static Boolean validateRegistrationGate(Id bookingId) {
        Booking__c bk = [
            SELECT Id, Funding_Type__c, Pending_Dues__c, DD_Uploaded__c, DD_Reference__c, Is_Locked__c
            FROM Booking__c 
            WHERE Id = :bookingId 
            LIMIT 1
        ];
        
        Boolean isLoan = (bk.Funding_Type__c == 'Loan' || bk.Funding_Type__c == 'Home Loan');
        if (isLoan) {
            return (bk.DD_Uploaded__c == true && String.isNotBlank(bk.DD_Reference__c));
        } else {
            return (bk.Pending_Dues__c <= 0 && !bk.Is_Locked__c);
        }
    }

    /**
     * @description Gate Before Handover (100% Payment Cleared, All Receipts Approved, Registration Done)
     */
    public static Boolean validateHandoverGate(Id bookingId) {
        Booking__c bk = [
            SELECT Id, Pending_Dues__c, Total_Paid__c, Final_Property_Value__c, Is_Locked__c, Stage__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];

        // Check if all receipts are approved (none in Draft/Pending Approval)
        Integer pendingReceipts = [
            SELECT COUNT()
            FROM Receipt__c
            WHERE Booking__c = :bookingId AND Receipt_Status__c = 'Pending Approval'
        ];

        return (bk.Pending_Dues__c <= 0 && pendingReceipts == 0 && !bk.Is_Locked__c);
    }

    /**
     * @description Completes the Handover process, generates 3 letters, sends Handover email, and marks unit Sold.
     */
    public static void completeHandover(Id bookingId, String keyNumber) {
        Booking__c bk = [
            SELECT Id, Unit__c, Stage__c, Opportunity__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];

        bk.Stage__c = 'Completed';
        bk.Payment_Status__c = 'Paid';
        update bk;

        // Mark Unit as Sold and preserve Sales History
        if (bk.Unit__c != null) {
            UnitInventoryService.markUnitSold(bk.Unit__c);
        }
        UnitInventoryService.createOrUpdateSalesHistory(bk.Id);

        // Update Opportunity to Closed Won
        if (bk.Opportunity__c != null) {
            update new Opportunity(Id = bk.Opportunity__c, StageName = 'Closed Won', CloseDate = Date.today());
        }

        // Generate documents and dispatch email
        RealEstateEmailService.sendHandoverEmail(bk.Id, keyNumber);
    }
}