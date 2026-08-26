/**
 * @description Integration Engine for Salesforce <-> Odoo ERP communications.
 * Handles inventory synchronization, booking push, payment ingestion, and commission vouchers.
 */
public with sharing class OdooIntegrationService {

    public class OdooIntegrationException extends Exception {}

    /**
     * @description Syncs an approved partner commission into Odoo Accounting as a Vendor Bill / Voucher.
     */
    public static Boolean syncCommissionToOdoo(Id commissionId) {
        List<Commission__c> comms = [
            SELECT Id, Name, Partner__c, Partner__r.Name, Partner__r.Partner_Code__c, Partner__r.GST_Number__c,
                   Partner__r.PAN_Number__c, Partner__r.Bank_Name__c, Partner__r.Account_Number__c, Partner__r.IFSC_Code__c,
                   Booking__c, Booking__r.Name, Net_Commission__c, Gross_Commission__c, Tax_Deduction__c,
                   GST_Amount__c, Property_Value__c, Odoo_Commission_ID__c
            FROM Commission__c
            WHERE Id = :commissionId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (comms.isEmpty()) {
            return false;
        }

        Commission__c comm = comms[0];

        // Prepare JSON payload
        Map<String, Object> payload = new Map<String, Object>{
            'action' => 'CREATE_COMMISSION_VOUCHER',
            'salesforce_commission_id' => comm.Id,
            'commission_number' => comm.Name,
            'partner_code' => comm.Partner__r.Partner_Code__c,
            'partner_name' => comm.Partner__r.Name,
            'pan_number' => comm.Partner__r.PAN_Number__c,
            'gst_number' => comm.Partner__r.GST_Number__c,
            'bank_account' => comm.Partner__r.Account_Number__c,
            'bank_ifsc' => comm.Partner__r.IFSC_Code__c,
            'booking_ref' => comm.Booking__r.Name,
            'gross_amount' => comm.Gross_Commission__c,
            'tds_withheld' => comm.Tax_Deduction__c,
            'gst_amount' => comm.GST_Amount__c,
            'net_payable' => comm.Net_Commission__c
        };

        String jsonBody = JSON.serialize(payload);
        String endpoint = 'callout:Odoo_ERP_Credential/api/v1/commissions/voucher';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(60000);
        req.setBody(jsonBody);

        Http http = new Http();
        HttpResponse res;
        String status = 'Success';
        String errorMsg = null;
        Integer statusCode = 200;
        String odooExternalId = null;

        try {
            res = http.send(req);
            statusCode = res.getStatusCode();
            String resBody = res.getBody();

            if (statusCode == 200 || statusCode == 201) {
                Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(resBody);
                if (resMap.containsKey('odoo_voucher_id')) {
                    odooExternalId = String.valueOf(resMap.get('odoo_voucher_id'));
                    comm.Odoo_Commission_ID__c = odooExternalId;
                    update comm;
                }
            } else {
                status = 'Failed';
                errorMsg = 'Odoo HTTP Error ' + statusCode + ': ' + resBody;
            }

            IntegrationLogger.logIntegration(
                'Odoo_Commission_Sync',
                endpoint,
                'POST',
                statusCode,
                status,
                jsonBody,
                resBody,
                errorMsg,
                comm.Id,
                odooExternalId
            );

        } catch (Exception ex) {
            status = 'Failed';
            errorMsg = ex.getMessage();
            IntegrationLogger.logIntegration(
                'Odoo_Commission_Sync',
                endpoint,
                'POST',
                0,
                status,
                jsonBody,
                null,
                errorMsg,
                comm.Id,
                null
            );
            return false;
        }

        return status == 'Success';
    }

    /**
     * @description Syncs a confirmed real estate booking to Odoo Sales Orders.
     */
    public static Boolean syncBookingToOdoo(Id bookingId) {
        List<Booking__c> bookings = [
            SELECT Id, Name, Customer_Name__c, Customer_Email__c, Customer_Phone__c,
                   Project__r.Name, Project__r.Project_Code__c, Unit_Number__c,
                   Agreement_Value__c, Booking_Amount__c, Booking_Date__c,
                   Partner__r.Name, Partner__r.Partner_Code__c, Odoo_Booking_ID__c
            FROM Booking__c
            WHERE Id = :bookingId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (bookings.isEmpty()) {
            return false;
        }

        Booking__c b = bookings[0];

        Map<String, Object> payload = new Map<String, Object>{
            'action' => 'CREATE_SALE_ORDER',
            'salesforce_booking_id' => b.Id,
            'booking_number' => b.Name,
            'customer_name' => b.Customer_Name__c,
            'customer_phone' => b.Customer_Phone__c,
            'customer_email' => b.Customer_Email__c,
            'project_code' => b.Project__r.Project_Code__c,
            'unit_number' => b.Unit_Number__c,
            'total_value' => b.Agreement_Value__c,
            'deposit_received' => b.Booking_Amount__c,
            'booking_date' => b.Booking_Date__c,
            'channel_partner' => b.Partner__r.Partner_Code__c
        };

        String jsonBody = JSON.serialize(payload);
        String endpoint = 'callout:Odoo_ERP_Credential/api/v1/bookings/order';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);

        Http http = new Http();
        HttpResponse res;
        String status = 'Success';
        String errorMsg = null;
        Integer statusCode = 200;
        String odooOrderId = null;

        try {
            res = http.send(req);
            statusCode = res.getStatusCode();
            String resBody = res.getBody();

            if (statusCode == 200 || statusCode == 201) {
                Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(resBody);
                if (resMap.containsKey('odoo_order_id')) {
                    odooOrderId = String.valueOf(resMap.get('odoo_order_id'));
                    b.Odoo_Booking_ID__c = odooOrderId;
                    update b;
                }
            } else {
                status = 'Failed';
                errorMsg = 'Odoo HTTP ' + statusCode + ': ' + resBody;
            }

            IntegrationLogger.logIntegration(
                'Odoo_Booking_Sync',
                endpoint,
                'POST',
                statusCode,
                status,
                jsonBody,
                resBody,
                errorMsg,
                b.Id,
                odooOrderId
            );

        } catch (Exception ex) {
            status = 'Failed';
            errorMsg = ex.getMessage();
            IntegrationLogger.logIntegration(
                'Odoo_Booking_Sync',
                endpoint,
                'POST',
                0,
                status,
                jsonBody,
                null,
                errorMsg,
                b.Id,
                null
            );
            return false;
        }

        return status == 'Success';
    }
}
