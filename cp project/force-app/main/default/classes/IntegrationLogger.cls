/**
 * @description Centralized logging engine for Integration Callouts and Partner Audit Trails.
 * Ensures bulk-safe logging without failing calling business transactions.
 */
public without sharing class IntegrationLogger {

    /**
     * @description Logs an API integration callout or webhook payload.
     * @param integrationName Name of integration (e.g. Odoo_Inventory_Sync)
     * @param endpoint URL endpoint
     * @param method HTTP Method (GET, POST, etc.)
     * @param statusCode HTTP Status Code
     * @param status Success, Failed, Pending, Retrying
     * @param requestBody JSON Request payload
     * @param responseBody JSON Response payload
     * @param errorMessage Error / Exception text
     * @param recordId Related Salesforce Record ID
     * @param externalId External ERP identifier
     */
    public static void logIntegration(
        String integrationName,
        String endpoint,
        String method,
        Integer statusCode,
        String status,
        String requestBody,
        String responseBody,
        String errorMessage,
        String recordId,
        String externalId
    ) {
        try {
            Integration_Log__c log = new Integration_Log__c(
                Integration_Name__c = integrationName,
                Endpoint__c = endpoint,
                HTTP_Method__c = method,
                HTTP_Status_Code__c = statusCode,
                Status__c = status,
                Request__c = sanitizeSecrets(requestBody),
                Response__c = responseBody,
                Error_Message__c = errorMessage,
                Record_ID__c = recordId,
                External_ID__c = externalId,
                Timestamp__c = DateTime.now()
            );
            insert log;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Failed to insert Integration_Log__c: ' + ex.getMessage());
        }
    }

    /**
     * @description Records an immutable audit log entry for sensitive partner actions.
     * @param partnerId Partner__c ID
     * @param recordId SObject Record ID
     * @param objectName API Name of SObject
     * @param action Audit Action type
     * @param oldValue Previous state
     * @param newValue New state
     * @param reason User justification
     */
    public static void logAudit(
        Id partnerId,
        String recordId,
        String objectName,
        String action,
        String oldValue,
        String newValue,
        String reason
    ) {
        try {
            Partner_Audit_Log__c audit = new Partner_Audit_Log__c(
                User__c = UserInfo.getUserId(),
                Partner__c = partnerId,
                Record_ID__c = recordId,
                Object_Name__c = objectName,
                Action__c = action,
                Old_Value__c = oldValue,
                New_Value__c = newValue,
                Reason__c = reason,
                Timestamp__c = DateTime.now()
            );
            insert audit;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Failed to insert Partner_Audit_Log__c: ' + ex.getMessage());
        }
    }

    /**
     * @description Sanitizes passwords, tokens, and API keys from request bodies.
     */
    private static String sanitizeSecrets(String payload) {
        if (String.isBlank(payload)) {
            return payload;
        }
        String sanitized = payload.replaceAll('(?i)"(password|token|secret|apiKey)"\\s*:\\s*"[^"]+"', '"$1":"***MASKED***"');
        return sanitized;
    }
}
