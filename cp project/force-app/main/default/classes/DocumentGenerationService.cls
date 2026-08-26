/**
 * @description Central Document Generation & Management Service for Real Estate CRM.
 * Generates and stores customer-facing documents (Cost Sheets, Receipts, Demands, Agreements, Handover Letters).
 * Links records seamlessly with Document__c and Salesforce Files (ContentVersion).
 */
public without sharing class DocumentGenerationService {

    /**
     * @description Creates a Document__c tracking record and attaches a simulated or rendered PDF ContentVersion.
     */
    public static Document__c createDocumentRecord(
        String docType,
        String docName,
        Id bookingId,
        Id oppId,
        Id leadId,
        String contentText
    ) {
        Document__c doc = new Document__c(
            Document_Type__c = docType,
            Document_Status__c = 'Verified',
            Status__c = 'Verified',
            Upload_Date__c = Date.today(),
            Verified_Date__c = Date.today(),
            Booking__c = bookingId,
            Lead__c = leadId,
            Remarks__c = 'Generated automatically by Real Estate CRM Document Engine'
        );
        if (Schema.sObjectType.Document__c.fields.getMap().containsKey('opportunity__c')) {
            doc.put('Opportunity__c', oppId);
        }
        insert doc;

        // Create ContentVersion (Salesforce File)
        try {
            ContentVersion cv = new ContentVersion(
                Title = docName,
                PathOnClient = docName + '.pdf',
                VersionData = Blob.valueOf(String.isNotBlank(contentText) ? contentText : ('Official Document: ' + docName + '\nType: ' + docType + '\nDate: ' + String.valueOf(Date.today()))),
                IsMajorVersion = true
            );
            insert cv;

            Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

            // Link File to Document__c record
            ContentDocumentLink cdlDoc = new ContentDocumentLink(
                ContentDocumentId = conDocId,
                LinkedEntityId = doc.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdlDoc;

            // Link File to Booking__c if present
            if (bookingId != null) {
                ContentDocumentLink cdlBooking = new ContentDocumentLink(
                    ContentDocumentId = conDocId,
                    LinkedEntityId = bookingId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
                insert cdlBooking;
            }
        } catch (Exception e) {
            System.debug('ContentVersion creation skipped in context: ' + e.getMessage());
        }

        return doc;
    }

    /**
     * @description Generates the 5 Welcome Email attachments for a confirmed Booking.
     */
    public static List<Document__c> generateWelcomeKitDocuments(Id bookingId) {
        Booking__c bk = [
            SELECT Id, Name, Customer_Name__c, Unit_Number__c, Project__c, Project__r.Name,
                   Tower__c, Final_Property_Value__c, Total_Paid__c, Opportunity__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];

        List<Document__c> docs = new List<Document__c>();
        String prjName = bk.Project__r != null ? bk.Project__r.Name : 'Project';

        // 1. Cost Sheet
        docs.add(createDocumentRecord('Cost Sheet', 'Cost_Sheet_' + bk.Unit_Number__c, bk.Id, bk.Opportunity__c, null,
            'COST SHEET - ' + prjName + ' Unit ' + bk.Unit_Number__c + '\nCustomer: ' + bk.Customer_Name__c + '\nValue: Rs ' + bk.Final_Property_Value__c));

        // 2. Consolidated Receipt
        docs.add(createDocumentRecord('Consolidated Receipt', 'Consolidated_Receipt_' + bk.Name, bk.Id, bk.Opportunity__c, null,
            'CONSOLIDATED RECEIPT - ' + bk.Name + '\nTotal Paid: Rs ' + bk.Total_Paid__c + '\nTotal Value: Rs ' + bk.Final_Property_Value__c));

        // 3. Agreement Demand Letter
        docs.add(createDocumentRecord('Agreement Demand Letter', 'Agreement_Demand_' + bk.Name, bk.Id, bk.Opportunity__c, null,
            'AGREEMENT DEMAND LETTER\nBooking: ' + bk.Name + '\nDue Date: ' + String.valueOf(Date.today().addDays(15))));

        // 4. Draft Sale Agreement
        docs.add(createDocumentRecord('Draft Sale Agreement', 'Draft_Agreement_' + bk.Unit_Number__c, bk.Id, bk.Opportunity__c, null,
            'DRAFT SALE AGREEMENT\nBetween Developer and ' + bk.Customer_Name__c + '\nProperty: ' + prjName + ' Unit ' + bk.Unit_Number__c));

        // 5. Allotment Letter
        docs.add(createDocumentRecord('Allotment Letter', 'Allotment_Letter_' + bk.Unit_Number__c, bk.Id, bk.Opportunity__c, null,
            'ALLOTMENT LETTER\nThis is to confirm allotment of Unit ' + bk.Unit_Number__c + ' in ' + prjName + ' to ' + bk.Customer_Name__c));

        return docs;
    }

    /**
     * @description Generates the 3 Handover documents for a completed Booking.
     * Bulkified: uses 3 DML statements total (vs 12 with individual createDocumentRecord calls)
     * to stay within the 150 DML governor limit.
     */
    public static List<Document__c> generateHandoverDocuments(Id bookingId, String keyNumber) {
        Booking__c bk = [
            SELECT Id, Name, Customer_Name__c, Unit_Number__c, Project__c, Project__r.Name, Opportunity__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];

        String prjName = bk.Project__r != null ? bk.Project__r.Name : 'Project';
        String key = String.isNotBlank(keyNumber) ? keyNumber : 'KEY-' + bk.Unit_Number__c;
        String today = String.valueOf(Date.today());

        // Build all 3 Document__c records (matching fields set by createDocumentRecord)
        String remarks = 'Generated automatically by Real Estate CRM Document Engine';
        Boolean hasOpp = Schema.sObjectType.Document__c.fields.getMap().containsKey('opportunity__c');
        Document__c d1 = new Document__c(
            Document_Type__c = 'Possession Certificate', Document_Status__c = 'Verified',
            Status__c = 'Verified', Upload_Date__c = Date.today(), Verified_Date__c = Date.today(),
            Booking__c = bookingId, Remarks__c = remarks
        );
        Document__c d2 = new Document__c(
            Document_Type__c = 'Key Handover Letter', Document_Status__c = 'Verified',
            Status__c = 'Verified', Upload_Date__c = Date.today(), Verified_Date__c = Date.today(),
            Booking__c = bookingId, Remarks__c = remarks
        );
        Document__c d3 = new Document__c(
            Document_Type__c = 'Maintenance Letter', Document_Status__c = 'Verified',
            Status__c = 'Verified', Upload_Date__c = Date.today(), Verified_Date__c = Date.today(),
            Booking__c = bookingId, Remarks__c = remarks
        );
        if (hasOpp && bk.Opportunity__c != null) {
            d1.put('Opportunity__c', bk.Opportunity__c);
            d2.put('Opportunity__c', bk.Opportunity__c);
            d3.put('Opportunity__c', bk.Opportunity__c);
        }
        List<Document__c> docs = new List<Document__c>{ d1, d2, d3 };
        insert docs; // 1 DML

        // Build all 3 ContentVersions in one batch
        List<String[]> cvContents = new List<String[]> {
            new String[] {'Possession_Certificate_' + bk.Unit_Number__c,
                'POSSESSION CERTIFICATE\nCustomer: ' + bk.Customer_Name__c + '\nUnit: ' + bk.Unit_Number__c + ' in ' + prjName + '\nDate: ' + today},
            new String[] {'Key_Handover_' + bk.Unit_Number__c,
                'KEY HANDOVER LETTER\nKeys Number: ' + key + ' delivered to ' + bk.Customer_Name__c + '\nDefect Liability Period: 12 Months'},
            new String[] {'Maintenance_Letter_' + bk.Unit_Number__c,
                'MAINTENANCE LETTER\nMaintenance guidelines for Unit ' + bk.Unit_Number__c}
        };

        List<ContentVersion> cvs = new List<ContentVersion>();
        for (String[] cv : cvContents) {
            cvs.add(new ContentVersion(
                Title = cv[0],
                PathOnClient = cv[0] + '.pdf',
                VersionData = Blob.valueOf(cv[1]),
                IsMajorVersion = true
            ));
        }

        try {
            insert cvs; // 1 DML

            // Query all ContentDocumentIds in one SOQL
            Set<Id> cvIds = new Set<Id>();
            for (ContentVersion cv : cvs) { cvIds.add(cv.Id); }
            Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>([
                SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :cvIds
            ]);

            // Link all ContentDocuments in one bulk insert
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            for (Integer i = 0; i < docs.size(); i++) {
                Id cdId = cvMap.get(cvs[i].Id) != null ? cvMap.get(cvs[i].Id).ContentDocumentId : null;
                if (cdId == null) continue;
                links.add(new ContentDocumentLink(ContentDocumentId = cdId, LinkedEntityId = docs[i].Id, ShareType = 'V', Visibility = 'AllUsers'));
                links.add(new ContentDocumentLink(ContentDocumentId = cdId, LinkedEntityId = bookingId, ShareType = 'V', Visibility = 'AllUsers'));
            }
            if (!links.isEmpty()) {
                insert links; // 1 DML
            }
        } catch (Exception e) {
            System.debug('ContentVersion bulk creation skipped: ' + e.getMessage());
        }

        return docs;
    }
}
