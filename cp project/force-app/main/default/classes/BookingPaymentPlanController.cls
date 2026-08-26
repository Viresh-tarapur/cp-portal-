public with sharing class BookingPaymentPlanController {
    
    public class PaymentPlanException extends Exception {}

    private static void throwPlanException(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        throw e;
    }

    public class BookingDetailsWrapper {
        @AuraEnabled public Booking__c booking { get; set; }
        @AuraEnabled public List<Payment_Schedule__c> schedules { get; set; }
        @AuraEnabled public Boolean hasModifyAccess { get; set; }
    }

    @AuraEnabled(cacheable=false)
    public static BookingDetailsWrapper getBookingDetails(Id bookingId) {
        try {
            if (bookingId == null) {
                throwPlanException('Booking ID cannot be null.');
            }
            
            Booking__c bk = [
                SELECT Id, Name, Booking_Date__c, Booking_Amount__c, Total_Property_Plot_Amount__c,
                       Payment_Plan_Activated__c, Payment_Plan_Type__c, Payment_Plan_Months__c,
                       Monthly_Installment__c, Total_Demanded__c, Total_Paid__c, Outstanding_Amount__c,
                       Next_Payment_Amount__c, Next_Payment_Date__c, Next_Milestone_Name__c,
                       Loan_Amount__c
                FROM Booking__c
                WHERE Id = :bookingId
                LIMIT 1
            ];

            List<Payment_Schedule__c> schList = [
                SELECT Id, Installment_Number__c, Milestone_Name__c, Amount__c, Outstanding_Amount__c, Paid_Amount__c, Due_Date__c, Status__c
                FROM Payment_Schedule__c
                WHERE Booking__c = :bookingId
                ORDER BY Installment_Number__c ASC
            ];

            Boolean hasAccess = FeatureManagement.checkPermission('Modify_Payment_Plan');
            if (!hasAccess) {
                List<Profile> pList = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
                if (!pList.isEmpty() && pList[0].Name == 'System Administrator') {
                    hasAccess = true;
                }
            }

            BookingDetailsWrapper wrapper = new BookingDetailsWrapper();
            wrapper.booking = bk;
            wrapper.schedules = schList;
            wrapper.hasModifyAccess = hasAccess;
            return wrapper;
        } catch (Exception e) {
            AuraHandledException auraEx = new AuraHandledException('Unable to get booking details: ' + e.getMessage());
            auraEx.setMessage('Unable to get booking details: ' + e.getMessage());
            throw auraEx;
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> previewSchedules(Id bookingId, String planType, Integer months, Decimal totalAmount) {
        try {
            if (bookingId == null) throwPlanException('Booking ID cannot be null.');
            if (totalAmount == null || totalAmount <= 0) throwPlanException('Total Property/Plot Amount must be greater than 0.');
            if (planType == 'Monthly Payment' && (months == null || months <= 0)) {
                throwPlanException('Number of months must be greater than 0.');
            }

            Booking__c bk = [SELECT Booking_Date__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];
            Date startDate = bk.Booking_Date__c != null ? bk.Booking_Date__c : Date.today();

            List<Payment_Schedule__c> existingSchedules = [
                SELECT Id, Installment_Number__c, Milestone_Name__c, Amount__c, Outstanding_Amount__c, Paid_Amount__c, Due_Date__c, Status__c
                FROM Payment_Schedule__c 
                WHERE Booking__c = :bookingId
                ORDER BY Installment_Number__c ASC
            ];

            List<Map<String, Object>> previewList = new List<Map<String, Object>>();
            Decimal preservedTotalAmount = 0.00;
            Integer preservedCount = 0;

            for (Payment_Schedule__c sch : existingSchedules) {
                if ((sch.Paid_Amount__c != null && sch.Paid_Amount__c > 0) || 
                    sch.Status__c == 'Paid' || 
                    sch.Status__c == 'Partially Paid') {
                    Map<String, Object> line = new Map<String, Object>();
                    line.put('installmentNumber', sch.Installment_Number__c);
                    line.put('milestoneName', sch.Milestone_Name__c + ' (Preserved)');
                    line.put('amount', sch.Amount__c);
                    line.put('dueDate', sch.Due_Date__c);
                    line.put('status', sch.Status__c);
                    previewList.add(line);
                    
                    preservedTotalAmount += (sch.Amount__c != null ? sch.Amount__c : 0.00);
                    preservedCount++;
                }
            }

            Decimal remainingAmount = totalAmount - preservedTotalAmount;
            if (remainingAmount < 0) remainingAmount = 0;

            if (remainingAmount > 0) {
                if (planType == 'Full Amount') {
                    Map<String, Object> line = new Map<String, Object>();
                    line.put('installmentNumber', preservedCount + 1);
                    line.put('milestoneName', preservedCount == 0 ? 'Full Payment' : 'Remaining Balance');
                    line.put('amount', remainingAmount);
                    line.put('dueDate', startDate.addMonths(preservedCount));
                    line.put('status', 'Pending');
                    previewList.add(line);
                } else if (planType == 'Monthly Payment') {
                    Integer futureMonths = months - preservedCount;
                    if (futureMonths <= 0) futureMonths = 1;

                    Decimal baseAmount = (remainingAmount / futureMonths).setScale(2, System.RoundingMode.HALF_UP);
                    Decimal totalAssigned = 0.00;

                    for (Integer i = 1; i <= futureMonths; i++) {
                        Map<String, Object> line = new Map<String, Object>();
                        line.put('installmentNumber', preservedCount + i);
                        line.put('milestoneName', 'Installment ' + (preservedCount + i));
                        
                        Decimal installmentAmt;
                        if (i == futureMonths) {
                            installmentAmt = remainingAmount - totalAssigned;
                        } else {
                            installmentAmt = baseAmount;
                            totalAssigned += installmentAmt;
                        }
                        
                        line.put('amount', installmentAmt);
                        line.put('dueDate', startDate.addMonths(preservedCount + i - 1));
                        line.put('status', 'Pending');
                        previewList.add(line);
                    }
                }
            }
            return previewList;
        } catch (Exception e) {
            AuraHandledException auraEx = new AuraHandledException('Unable to preview schedules: ' + e.getMessage());
            auraEx.setMessage('Unable to preview schedules: ' + e.getMessage());
            throw auraEx;
        }
    }

    @AuraEnabled(cacheable=false)
    public static BookingDetailsWrapper activatePaymentPlan(Id bookingId, String planType, Integer months, Decimal totalAmount) {
        try {
            if (bookingId == null) throwPlanException('Booking ID cannot be null.');
            if (totalAmount == null || totalAmount <= 0) throwPlanException('Total Property/Plot Amount must be greater than 0.');
            if (planType == 'Monthly Payment' && (months == null || months <= 0)) {
                throwPlanException('Number of months must be greater than 0.');
            }

            // Check modify access
            Boolean hasAccess = FeatureManagement.checkPermission('Modify_Payment_Plan');
            if (!hasAccess) {
                List<Profile> pList = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
                if (!pList.isEmpty() && pList[0].Name == 'System Administrator') {
                    hasAccess = true;
                }
            }
            if (!hasAccess) {
                throwPlanException('You do not have permission to modify the payment plan.');
            }

            Booking__c bk = [
                SELECT Id, Name, Booking_Date__c, Loan_Amount__c, Agreement_Value__c, Unit_Price__c
                FROM Booking__c 
                WHERE Id = :bookingId 
                LIMIT 1
            ];
            
            Date startDate = bk.Booking_Date__c != null ? bk.Booking_Date__c : Date.today();
            
            // 1. Query existing schedules and separate preserved vs deletable ones
            List<Payment_Schedule__c> existingSchedules = [
                SELECT Id, Installment_Number__c, Milestone_Name__c, Amount__c, Outstanding_Amount__c, Paid_Amount__c, Due_Date__c, Status__c, Loan_Portion__c, Customer_Portion__c
                FROM Payment_Schedule__c 
                WHERE Booking__c = :bookingId
                ORDER BY Installment_Number__c ASC
            ];

            List<Payment_Schedule__c> preservedSchedules = new List<Payment_Schedule__c>();
            List<Payment_Schedule__c> schedulesToDelete = new List<Payment_Schedule__c>();
            Decimal preservedTotalAmount = 0.00;

            for (Payment_Schedule__c sch : existingSchedules) {
                if ((sch.Paid_Amount__c != null && sch.Paid_Amount__c > 0) || 
                    sch.Status__c == 'Paid' || 
                    sch.Status__c == 'Partially Paid') {
                    preservedSchedules.add(sch);
                    preservedTotalAmount += (sch.Amount__c != null ? sch.Amount__c : 0.00);
                } else {
                    schedulesToDelete.add(sch);
                }
            }

            // Delete deletable schedules
            if (!schedulesToDelete.isEmpty()) {
                delete schedulesToDelete;
            }

            // Calculate remaining amount
            Decimal remainingAmount = totalAmount - preservedTotalAmount;
            if (remainingAmount < 0) remainingAmount = 0;

            // Number of preserved schedules
            Integer preservedCount = preservedSchedules.size();

            // Calculate Installment amount for future schedules
            Decimal monthlyInstallment = null;
            Integer futureMonths = (planType == 'Monthly Payment') ? (months - preservedCount) : 0;
            if (futureMonths <= 0) futureMonths = 1; // safety fallback

            if (planType == 'Monthly Payment' && remainingAmount > 0) {
                monthlyInstallment = (remainingAmount / futureMonths).setScale(2, System.RoundingMode.HALF_UP);
            }

            // Update Booking plan fields
            bk.Payment_Plan_Activated__c = true;
            bk.Payment_Plan_Type__c = planType;
            bk.Payment_Plan_Months__c = (planType == 'Monthly Payment') ? months : null;
            bk.Monthly_Installment__c = monthlyInstallment;
            bk.Total_Property_Plot_Amount__c = totalAmount;
            update bk;

            // Create new schedules if there is remaining amount to be scheduled
            List<Payment_Schedule__c> schedulesToInsert = new List<Payment_Schedule__c>();
            if (remainingAmount > 0) {
                Decimal loanTotal = (bk.Loan_Amount__c != null) ? bk.Loan_Amount__c : 0.00;
                Decimal loanRatio = totalAmount > 0 ? (loanTotal / totalAmount) : 0.00;

                if (planType == 'Full Amount') {
                    Decimal loanPart = (remainingAmount * loanRatio).setScale(2, System.RoundingMode.HALF_UP);
                    Decimal custPart = remainingAmount - loanPart;

                    schedulesToInsert.add(new Payment_Schedule__c(
                        Name = bk.Name + ' - ' + (preservedCount == 0 ? 'Full Payment' : 'Remaining Balance'),
                        Booking__c = bookingId,
                        Installment_Number__c = preservedCount + 1,
                        Milestone_Name__c = preservedCount == 0 ? 'Full Payment' : 'Remaining Balance',
                        Amount__c = remainingAmount,
                        Outstanding_Amount__c = remainingAmount,
                        Paid_Amount__c = 0.00,
                        Due_Date__c = startDate.addMonths(preservedCount),
                        Status__c = 'Pending',
                        Is_Active__c = true,
                        Plan_Type__c = 'Custom Payment Plan',
                        Loan_Portion__c = loanPart,
                        Customer_Portion__c = custPart
                    ));
                } else if (planType == 'Monthly Payment') {
                    Decimal baseAmount = (remainingAmount / futureMonths).setScale(2, System.RoundingMode.HALF_UP);
                    Decimal totalAssigned = 0.00;

                    for (Integer i = 1; i <= futureMonths; i++) {
                        Decimal installmentAmt;
                        if (i == futureMonths) {
                            installmentAmt = remainingAmount - totalAssigned;
                        } else {
                            installmentAmt = baseAmount;
                            totalAssigned += installmentAmt;
                        }

                        Decimal loanPart = (installmentAmt * loanRatio).setScale(2, System.RoundingMode.HALF_UP);
                        Decimal custPart = installmentAmt - loanPart;

                        schedulesToInsert.add(new Payment_Schedule__c(
                            Name = bk.Name + ' - Installment ' + (preservedCount + i),
                            Booking__c = bookingId,
                            Installment_Number__c = preservedCount + i,
                            Milestone_Name__c = 'Installment ' + (preservedCount + i),
                            Amount__c = installmentAmt,
                            Outstanding_Amount__c = installmentAmt,
                            Paid_Amount__c = 0.00,
                            Due_Date__c = startDate.addMonths(preservedCount + i - 1),
                            Status__c = 'Pending',
                            Is_Active__c = true,
                            Plan_Type__c = 'Custom Payment Plan',
                            Loan_Portion__c = loanPart,
                            Customer_Portion__c = custPart
                        ));
                    }
                }
            }

            if (!schedulesToInsert.isEmpty()) {
                insert schedulesToInsert;
            }

            // Recalculate Booking summary
            PropertyFinancialPlannerService.recalculateBookingPaymentSummary(bookingId);

            return getBookingDetails(bookingId);
        } catch (Exception e) {
            AuraHandledException auraEx = new AuraHandledException('Unable to activate payment plan: ' + e.getMessage());
            auraEx.setMessage('Unable to activate payment plan: ' + e.getMessage());
            throw auraEx;
        }
    }
}
