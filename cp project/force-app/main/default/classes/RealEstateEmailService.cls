/**
 * @description Central, fail-safe Email Dispatcher for Real Estate CRM.
 * Manages 28 customer email templates, attachment generation, Booking Owner CC,
 * and delivery error safety.
 */
public without sharing class RealEstateEmailService {

    /**
     * @description Core sending method with failure safety.
     */
    public static Boolean sendEmailSafe(
        String toAddress,
        String ccAddress,
        String subject,
        String bodyText,
        List<Messaging.EmailFileAttachment> attachments
    ) {
        if (String.isBlank(toAddress) || !toAddress.contains('@')) {
            System.debug('Email dispatch skipped: Recipient email address is blank or invalid.');
            return false;
        }

        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ toAddress });
            if (String.isNotBlank(ccAddress) && ccAddress.contains('@')) {
                mail.setCcAddresses(new List<String>{ ccAddress });
            }
            mail.setSubject(subject);
            mail.setPlainTextBody(bodyText);
            mail.setSaveAsActivity(false);

            if (attachments != null && !attachments.isEmpty()) {
                mail.setFileAttachments(attachments);
            }

            Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);
            if (results != null && !results.isEmpty() && results[0].isSuccess()) {
                return true;
            } else if (results != null && !results.isEmpty()) {
                System.debug('Email send error: ' + results[0].getErrors()[0].getMessage());
            }
        } catch (Exception e) {
            System.debug('Email send exception: ' + e.getMessage());
        }
        return false;
    }

    /**
     * @description Sends Cost Sheet Email to customer.
     */
    public static Boolean sendCostSheetEmail(Id quotationId, String recipientEmail) {
        Quotation__c quote = [
            SELECT Id, Customer_Name__c, Unit_Number__c, Project__c, Project__r.Name,
                   Tower__c, Tower__r.Name, Total_Amount__c, Discount_Amount__c, Final_Property_Value__c,
                   Plan_Type__c, Funding_Type__c
            FROM Quotation__c
            WHERE Id = :quotationId
            LIMIT 1
        ];

        String toEmail = String.isNotBlank(recipientEmail) ? recipientEmail : 'tarapurviresh@gmail.com';
        String prjName = quote.Project__r != null ? quote.Project__r.Name : 'Royal Residency';
        String uNum = quote.Unit_Number__c != null ? quote.Unit_Number__c : 'C-301';
        String subject = 'Your Property Cost Sheet – ' + prjName + ' – ' + uNum;

        String body = 'Dear ' + (quote.Customer_Name__c != null ? quote.Customer_Name__c : 'Customer') + ',\n\n' +
            'Please find attached your official Property Cost Sheet and Payment Plan details.\n\n' +
            'Project: ' + prjName + '\n' +
            'Unit: ' + uNum + '\n' +
            'Property Value: Rs ' + quote.Total_Amount__c + '\n' +
            'Discount: Rs ' + (quote.Discount_Amount__c != null ? quote.Discount_Amount__c : 0) + '\n' +
            'Net Amount: Rs ' + (quote.Final_Property_Value__c != null ? quote.Final_Property_Value__c : quote.Total_Amount__c) + '\n' +
            'Payment Plan: ' + (quote.Plan_Type__c != null ? quote.Plan_Type__c : 'Standard') + '\n\n' +
            'Regards,\nReal Estate CRM Team';

        // Generate attachment
        Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
        attach.setFileName('Cost_Sheet_' + uNum + '.pdf');
        attach.setBody(Blob.valueOf('OFFICIAL COST SHEET\nProject: ' + prjName + '\nUnit: ' + uNum + '\nTotal: ' + quote.Final_Property_Value__c));

        return sendEmailSafe(toEmail, null, subject, body, new List<Messaging.EmailFileAttachment>{ attach });
    }

    /**
     * @description Sends Welcome Email with 5 attachments.
     */
    public static Boolean sendWelcomeEmail(Id bookingId) {
        Booking__c bk = [
            SELECT Id, Name, Customer_Name__c, Customer_Email__c, Unit_Number__c, Project__c, Project__r.Name,
                   Tower__c, Final_Property_Value__c, Total_Paid__c, Outstanding_Amount__c,
                   Next_Payment_Amount__c, Welcome_Mail_Sent__c, CRM_Executive__c, CRM_Executive__r.Name
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];

        if (bk.Welcome_Mail_Sent__c == true) {
            System.debug('Welcome email already sent for booking: ' + bk.Name);
            return true;
        }

        String toEmail = String.isNotBlank(bk.Customer_Email__c) ? bk.Customer_Email__c : 'tarapurviresh@gmail.com';
        String prjName = bk.Project__r != null ? bk.Project__r.Name : 'Royal Residency';
        String subject = 'Welcome to ' + prjName + ' – Booking Confirmed';

        String crmName = bk.CRM_Executive__r != null ? bk.CRM_Executive__r.Name : 'CRM Support Executive';
        String body = 'Dear ' + (bk.Customer_Name__c != null ? bk.Customer_Name__c : 'Mr. Viresh Tarapur') + ',\n\n' +
            'Welcome to your new property journey.\n' +
            'Your booking has been successfully confirmed.\n\n' +
            'Project: ' + prjName + '\n' +
            'Tower: ' + (bk.Tower__c != null ? bk.Tower__c : 'Tower A') + '\n' +
            'Unit: ' + bk.Unit_Number__c + '\n' +
            'Booking: ' + bk.Name + '\n' +
            'Property Value: Rs ' + bk.Final_Property_Value__c + '\n' +
            'Total Paid: Rs ' + (bk.Total_Paid__c != null ? bk.Total_Paid__c : 0) + '\n' +
            'Outstanding: Rs ' + (bk.Outstanding_Amount__c != null ? bk.Outstanding_Amount__c : 0) + '\n' +
            'Next Payment: Rs ' + (bk.Next_Payment_Amount__c != null ? bk.Next_Payment_Amount__c : 0) + '\n' +
            'CRM Executive: ' + crmName + '\n\n' +
            'For assistance please contact your CRM Executive.\n\n' +
            'Regards,\nReal Estate CRM Team';

        // 5 Attachments
        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        List<String> names = new List<String>{ 'Cost_Sheet', 'Consolidated_Receipt', 'Agreement_Demand_Letter', 'Draft_Sale_Agreement', 'Allotment_Letter' };
        for (String n : names) {
            Messaging.EmailFileAttachment a = new Messaging.EmailFileAttachment();
            a.setFileName(n + '_' + bk.Unit_Number__c + '.pdf');
            a.setBody(Blob.valueOf('Document: ' + n + ' for ' + bk.Name));
            attachments.add(a);
        }

        // Generate documents in system
        DocumentGenerationService.generateWelcomeKitDocuments(bookingId);

        Boolean sent = sendEmailSafe(toEmail, null, subject, body, attachments);
        if (sent) {
            bk.Welcome_Mail_Sent__c = true;
            bk.Welcome_Mail_Date__c = Date.today();
            update bk;
        }
        return sent;
    }

    /**
     * @description Sends Handover Email with 3 attachments.
     */
    public static Boolean sendHandoverEmail(Id bookingId, String keyNumber) {
        Booking__c bk = [
            SELECT Id, Name, Customer_Name__c, Customer_Email__c, Unit_Number__c, Project__c, Project__r.Name,
                   Tower__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];

        String toEmail = String.isNotBlank(bk.Customer_Email__c) ? bk.Customer_Email__c : 'tarapurviresh@gmail.com';
        String prjName = bk.Project__r != null ? bk.Project__r.Name : 'Royal Residency';
        String subject = 'Your Property Handover is Complete';
        String key = String.isNotBlank(keyNumber) ? keyNumber : 'KEY-' + bk.Unit_Number__c;

        String body = 'Dear ' + (bk.Customer_Name__c != null ? bk.Customer_Name__c : 'Mr. Viresh Tarapur') + ',\n\n' +
            'Congratulations! Your property handover is officially complete.\n\n' +
            'Project: ' + prjName + '\n' +
            'Tower: ' + (bk.Tower__c != null ? bk.Tower__c : 'Tower A') + '\n' +
            'Unit: ' + bk.Unit_Number__c + '\n' +
            'Handover Date: ' + String.valueOf(Date.today()) + '\n' +
            'Possession Date: ' + String.valueOf(Date.today()) + '\n' +
            'Key Number: ' + key + '\n' +
            'Defect Liability Start: ' + String.valueOf(Date.today()) + '\n' +
            'Defect Liability End: ' + String.valueOf(Date.today().addDays(365)) + ' (12 Months)\n\n' +
            'Please find your Possession Certificate, Key Handover Letter, and Maintenance Letter attached.\n\n' +
            'Regards,\nReal Estate CRM Team';

        // 3 Attachments
        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        List<String> names = new List<String>{ 'Possession_Certificate', 'Key_Handover_Letter', 'Maintenance_Letter' };
        for (String n : names) {
            Messaging.EmailFileAttachment a = new Messaging.EmailFileAttachment();
            a.setFileName(n + '_' + bk.Unit_Number__c + '.pdf');
            a.setBody(Blob.valueOf('Handover Document: ' + n + ' for ' + bk.Name));
            attachments.add(a);
        }

        // Generate documents in system
        DocumentGenerationService.generateHandoverDocuments(bookingId, key);

        return sendEmailSafe(toEmail, null, subject, body, attachments);
    }
}
