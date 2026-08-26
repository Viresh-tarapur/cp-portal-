/**
 * @description Central Service for Loan Reminders, Payment Schedule Reminders,
 * and the Official Demand Reminder Clock.
 */
public without sharing class LoanAndDemandReminderService {

    /**
     * @description Evaluates and sends Loan / DD Reminders (7-Day and 2-Day before due date).
     * Stops reminders if DD is uploaded or payment is completed.
     */
    public static Integer processLoanReminders() {
        Date today = Date.today();
        Date dateIn7Days = today.addDays(7);
        Date dateIn2Days = today.addDays(2);

        List<Booking__c> loanBookings = [
            SELECT Id, Name, Customer_Name__c, Customer_Email__c, Unit_Number__c, Project__r.Name,
                   Funding_Type__c, Next_Payment_Date__c, Next_Payment_Amount__c,
                   DD_Uploaded__c, DD_Reference__c, Outstanding_Amount__c
            FROM Booking__c
            WHERE Funding_Type__c IN ('Home Loan', 'Part Self + Part Loan', 'Loan')
              AND Outstanding_Amount__c > 0
              AND DD_Uploaded__c != true
              AND (Next_Payment_Date__c = :dateIn7Days OR Next_Payment_Date__c = :dateIn2Days)
        ];

        Integer sentCount = 0;
        for (Booking__c bk : loanBookings) {
            Integer days = today.daysBetween(bk.Next_Payment_Date__c);
            String subject = (days == 2 ? 'Urgent ' : '') + 'Loan/DD Reminder – Payment Due in ' + days + ' Days';
            String body = 'Dear ' + (bk.Customer_Name__c != null ? bk.Customer_Name__c : 'Customer') + ',\n\n' +
                'This is a reminder regarding your upcoming loan disbursement / DD submission.\n\n' +
                'Booking: ' + bk.Name + '\n' +
                'Unit: ' + bk.Unit_Number__c + '\n' +
                'Amount Due: Rs ' + bk.Next_Payment_Amount__c + '\n' +
                'Due Date: ' + String.valueOf(bk.Next_Payment_Date__c) + '\n\n' +
                'Please upload your DD copy or confirm bank disbursement.\n\n' +
                'Regards,\nReal Estate CRM Team';

            String toEmail = String.isNotBlank(bk.Customer_Email__c) ? bk.Customer_Email__c : 'tarapurviresh@gmail.com';
            Boolean sent = RealEstateEmailService.sendEmailSafe(toEmail, null, subject, body, null);
            if (sent) sentCount++;
        }
        return sentCount;
    }

    /**
     * @description Evaluates and executes the Official Demand Reminder Clock (Days 0, 7, 14, 21, 30).
     */
    public static Integer processDemandReminderClock() {
        Date today = Date.today();

        List<Demand__c> activeDemands = [
            SELECT Id, Name, Booking__c, Booking__r.Customer_Name__c, Booking__r.Customer_Email__c,
                   Booking__r.Unit_Number__c, Demand_Amount__c, Demand_Date__c, Due_Date__c,
                   Demand_Status__c, Reminder_Stage__c, Total_Payable__c
            FROM Demand__c
            WHERE Demand_Status__c IN ('Issued', 'Overdue')
              AND Demand_Date__c != null
        ];

        Integer processedCount = 0;
        for (Demand__c dem : activeDemands) {
            Integer daysPassed = dem.Demand_Date__c.daysBetween(today);
            String newStage = null;
            String subject = null;

            if (daysPassed >= 21 && dem.Reminder_Stage__c != 'Day 21 Warning') {
                newStage = 'Day 21 Warning';
                subject = 'DEMAND TERMINATION NOTICE AND DAILY INTEREST WARNING - ' + dem.Name;
            } else if (daysPassed >= 14 && dem.Reminder_Stage__c != 'Day 14 Reminder' && dem.Reminder_Stage__c != 'Day 21 Warning') {
                newStage = 'Day 14 Reminder';
                subject = 'Urgent Payment Reminder (Day 14) - Due Date Approaching for ' + dem.Name;
            } else if (daysPassed >= 7 && dem.Reminder_Stage__c == null) {
                newStage = 'Day 7 Reminder';
                subject = 'Payment Reminder (Day 7) - Milestone Demand for ' + dem.Name;
            }

            if (newStage != null) {
                dem.Reminder_Stage__c = newStage;
                if (daysPassed > 15) {
                    dem.Demand_Status__c = 'Overdue';
                }
                update dem;

                String toEmail = String.isNotBlank(dem.Booking__r.Customer_Email__c) ? dem.Booking__r.Customer_Email__c : 'tarapurviresh@gmail.com';
                String body = 'Dear ' + (dem.Booking__r.Customer_Name__c != null ? dem.Booking__r.Customer_Name__c : 'Customer') + ',\n\n' +
                    'Reminder Stage: ' + newStage + '\n' +
                    'Demand: ' + dem.Name + '\n' +
                    'Amount: Rs ' + dem.Total_Payable__c + '\n' +
                    'Due Date: ' + String.valueOf(dem.Due_Date__c) + '\n\n' +
                    'Please clear this demand immediately to avoid interest penalties.\n\n' +
                    'Regards,\nReal Estate CRM Team';

                RealEstateEmailService.sendEmailSafe(toEmail, null, subject, body, null);
                processedCount++;
            }
        }
        return processedCount;
    }
}
