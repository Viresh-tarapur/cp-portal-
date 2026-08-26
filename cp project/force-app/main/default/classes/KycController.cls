/**
 * @description Controller managing Channel Partner KYC document compliance, verification status, and audit.
 */
public with sharing class KycController {

    public class KycStatusWrapper {
        @AuraEnabled public String kycStatus { get; set; }
        @AuraEnabled public String partnerStatus { get; set; }
        @AuraEnabled public List<KYC_Document__c> documents { get; set; }
    }

    /**
     * @description Fetches all KYC documents and overall verification status for the partner.
     */
    @AuraEnabled(cacheable=true)
    public static KycStatusWrapper getKycStatus() {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        if (partnerId == null) {
            return new KycStatusWrapper();
        }

        Partner__c partner = [SELECT Id, Status__c, KYC_Status__c FROM Partner__c WHERE Id = :partnerId WITH SYSTEM_MODE LIMIT 1];

        KycStatusWrapper wrapper = new KycStatusWrapper();
        wrapper.kycStatus = partner.KYC_Status__c;
        wrapper.partnerStatus = partner.Status__c;
        wrapper.documents = [
            SELECT Id, Name, Document_Type__c, Document_Number__c, Document_Status__c,
                   Uploaded_Date__c, Verified_Date__c, Rejection_Reason__c, File_Name__c, Content_Document_Id__c
            FROM KYC_Document__c
            WHERE Partner__c = :partnerId
            WITH SYSTEM_MODE
            ORDER BY Uploaded_Date__c DESC
        ];

        return wrapper;
    }

    /**
     * @description Submits a new KYC compliance document for Channel Manager review.
     */
    @AuraEnabled
    public static KYC_Document__c submitKycDocument(String documentType, String documentNumber, String contentDocumentId, String fileName) {
        Id partnerId = SecurityUtil.getCurrentUserPartnerId();
        if (partnerId == null) {
            throw new AuraHandledException('No Channel Partner account associated with current user.');
        }

        if (String.isBlank(documentType)) {
            throw new AuraHandledException('Document Type is required.');
        }

        KYC_Document__c doc = new KYC_Document__c(
            Partner__c = partnerId,
            Document_Type__c = documentType,
            Document_Number__c = documentNumber,
            Document_Status__c = 'Uploaded',
            Uploaded_Date__c = DateTime.now(),
            Content_Document_Id__c = contentDocumentId,
            File_Name__c = fileName
        );

        insert doc;

        // Update Partner KYC Status to Under Review if previously Pending
        Partner__c p = [SELECT Id, KYC_Status__c, Status__c FROM Partner__c WHERE Id = :partnerId LIMIT 1];
        if (p.KYC_Status__c == 'Pending' || p.KYC_Status__c == 'Rejected') {
            p.KYC_Status__c = 'Under Review';
            if (p.Status__c == 'Draft' || p.Status__c == 'KYC Pending') {
                p.Status__c = 'KYC Under Review';
            }
            update p;
        }

        IntegrationLogger.logAudit(
            partnerId,
            doc.Id,
            'KYC_Document__c',
            'KYC Approved',
            null,
            'Uploaded',
            'Uploaded KYC Document: ' + documentType + ' (' + fileName + ')'
        );

        return doc;
    }
}
