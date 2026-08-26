/**
 * @description 2-Tier Unit Swap Engine (Slides 24 & 34)
 */
public without sharing class SwapService {
    
    /**
     * @description Initiates swap request to a new unit in the same project
     */
    public static Swap__c initiateSwap(Id bookingId, String newUnitNumber) {
        Booking__c bk = [SELECT Id, Stage__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];
        if (bk.Stage__c == 'Registration' || bk.Stage__c == 'Handover') {
            throw new AuraHandledException('Golden Rule 5 Violation: No swapping allowed after Registration.');
        }

        Swap__c swp = new Swap__c(
            Booking__c = bookingId,
            New_Unit_Number__c = newUnitNumber,
            Status__c = 'Sales Head Approval'
        );
        insert swp;
        return swp;
    }

    /**
     * @description Finalizes swap: marks old booking as Swapping, releases old unit, creates new booking
     */
    public static void approveSwapByCRM(Id swapId) {
        Swap__c swp = [SELECT Id, Booking__c, New_Unit_Number__c, Status__c FROM Swap__c WHERE Id = :swapId LIMIT 1];
        swp.Status__c = 'Completed';
        update swp;

        Booking__c oldBk = [SELECT Id, Customer_Name__c, Unit_Price__c, Total_Paid__c, Project__c, Unit__c, Opportunity__c FROM Booking__c WHERE Id = :swp.Booking__c LIMIT 1];
        oldBk.Stage__c = 'Swapping';
        update oldBk;

        // Auto-create new booking for swapped unit in Booked stage (Slide 34)
        Booking__c newBk = new Booking__c(
            Customer_Name__c = oldBk.Customer_Name__c,
            Unit_Number__c = swp.New_Unit_Number__c,
            Unit_Price__c = oldBk.Unit_Price__c,
            Total_Paid__c = oldBk.Total_Paid__c,
            Stage__c = 'Booked',
            Booking_Status__c = 'Confirmed',
            Payment_Status__c = 'Paid',
            Opportunity__c = oldBk.Opportunity__c,
            Project__c = oldBk.Project__c,
            Unit__c = oldBk.Unit__c
        );
        insert newBk;
    }
}