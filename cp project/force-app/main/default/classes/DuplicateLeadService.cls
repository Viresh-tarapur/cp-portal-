/**
 * @description Multi-tier Duplicate Detection and Exclusivity Ownership engine.
 * Prevents unauthorized partner poaching of customers while protecting valid partner leads.
 */
public with sharing class DuplicateLeadService {

    public class DuplicateResult {
        @AuraEnabled public Boolean isDuplicate { get; set; }
        @AuraEnabled public Boolean isProtectedConflict { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id conflictingLeadId { get; set; }
        @AuraEnabled public Id conflictingRegistrationId { get; set; }
        @AuraEnabled public String conflictingPartnerName { get; set; }
        @AuraEnabled public Date protectedUntil { get; set; }

        public DuplicateResult() {
            this.isDuplicate = false;
            this.isProtectedConflict = false;
            this.message = 'No duplicate found.';
        }
    }

    /**
     * @description Checks for duplicate leads across phone, email, project, and active partner registrations.
     * @param partnerId Partner attempting to register the lead
     * @param projectId Target project ID
     * @param phone Customer phone number
     * @param email Customer email address
     * @return DuplicateResult with complete conflict metadata
     */
    public static DuplicateResult checkDuplicateLead(Id partnerId, Id projectId, String phone, String email) {
        DuplicateResult result = new DuplicateResult();

        if (String.isBlank(phone)) {
            return result;
        }

        String sanitizedPhone = sanitizePhone(phone);
        Date today = Date.today();

        // 1. Check Existing Active Lead Registrations on the same Project
        List<Lead_Registration__c> existingRegistrations = [
            SELECT Id, Name, Partner__c, Partner__r.Name, Project__c, Customer_Phone__c, Customer_Email__c,
                   Registration_Status__c, Ownership_Status__c, Protection_Start_Date__c, Protection_End_Date__c,
                   Lead__c
            FROM Lead_Registration__c
            WHERE Project__c = :projectId
              AND (Customer_Phone__c = :sanitizedPhone OR (Customer_Email__c != null AND Customer_Email__c = :email))
              AND Registration_Status__c IN ('Registered', 'Under Verification', 'Accepted')
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
        ];

        for (Lead_Registration__c reg : existingRegistrations) {
            // Check if active ownership protection exists
            if (reg.Ownership_Status__c == 'Protected' && reg.Protection_End_Date__c != null && reg.Protection_End_Date__c >= today) {
                if (reg.Partner__c == partnerId) {
                    result.isDuplicate = true;
                    result.isProtectedConflict = false;
                    result.conflictingRegistrationId = reg.Id;
                    result.conflictingLeadId = reg.Lead__c;
                    result.protectedUntil = reg.Protection_End_Date__c;
                    result.message = 'You have already registered and protected this customer for this project until ' + reg.Protection_End_Date__c.format() + '.';
                    return result;
                } else {
                    result.isDuplicate = true;
                    result.isProtectedConflict = true;
                    result.conflictingRegistrationId = reg.Id;
                    result.conflictingLeadId = reg.Lead__c;
                    result.conflictingPartnerName = reg.Partner__r.Name;
                    result.protectedUntil = reg.Protection_End_Date__c;
                    result.message = 'This customer is currently registered and under active exclusivity protection for this project until ' + reg.Protection_End_Date__c.format() + '.';
                    return result;
                }
            }
        }

        // 2. Check Standard Leads on the same Project
        List<Lead> standardLeads = [
            SELECT Id, Name, Phone, MobilePhone, Email, Project__c, Partner__c, Status, IsConverted
            FROM Lead
            WHERE IsConverted = false
              AND Project__c = :projectId
              AND (Phone = :sanitizedPhone OR MobilePhone = :sanitizedPhone OR (Email != null AND Email = :email))
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (!standardLeads.isEmpty()) {
            Lead existingLead = standardLeads[0];
            result.isDuplicate = true;
            result.conflictingLeadId = existingLead.Id;
            result.message = 'An active lead already exists for this customer on this project.';
            return result;
        }

        return result;
    }

    /**
     * @description Normalizes phone numbers (removes non-digits and leading country codes).
     */
    public static String sanitizePhone(String phone) {
        if (String.isBlank(phone)) {
            return '';
        }
        String clean = phone.replaceAll('[^0-9]', '');
        if (clean.length() > 10 && clean.startsWith('91')) {
            clean = clean.substring(2);
        }
        return clean;
    }
}
