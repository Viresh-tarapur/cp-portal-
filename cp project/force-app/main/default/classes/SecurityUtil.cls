/**
 * @description Security and authorization utility for Channel Partner Portal operations.
 * Enforces server-side user-to-partner resolution, CRUD/FLS validation, and sanitized errors.
 */
public with sharing class SecurityUtil {
    
    public class SecurityException extends Exception {}

    /**
     * @description Resolves the Partner__c ID associated with the current running user.
     * Searches via User.ContactId -> Contact.Partner__c or User's Account -> Partner__c.
     * @return Id of the Partner__c record, or null if internal admin/user without direct partner binding.
     */
    public static Id getCurrentUserPartnerId() {
        Id currentUserId = UserInfo.getUserId();
        
        List<User> userList = [
            SELECT Id, ContactId, Contact.AccountId 
            FROM User 
            WHERE Id = :currentUserId 
            WITH USER_MODE 
            LIMIT 1
        ];

        if (userList.isEmpty() || userList[0].ContactId == null) {
            // For internal users / testing, check if there is a primary contact or default partner
            List<Partner__c> activePartners = [
                SELECT Id 
                FROM Partner__c 
                WHERE Primary_Contact__c = :userList[0].ContactId 
                   OR Partner_Account__c = :userList[0].Contact.AccountId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            return activePartners.isEmpty() ? null : activePartners[0].Id;
        }

        Id contactId = userList[0].ContactId;
        Id accountId = userList[0].Contact.AccountId;

        List<Partner__c> partners = [
            SELECT Id, Status__c, KYC_Status__c 
            FROM Partner__c 
            WHERE (Primary_Contact__c = :contactId OR Partner_Account__c = :accountId)
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (!partners.isEmpty()) {
            return partners[0].Id;
        }

        return null;
    }

    /**
     * @description Validates that the partner has active status and approved KYC.
     * @param partnerId Partner__c record ID
     */
    public static void validatePartnerActiveAndApproved(Id partnerId) {
        if (partnerId == null) {
            throw new SecurityException('Channel Partner identification is required.');
        }

        List<Partner__c> partners = [
            SELECT Id, Name, Status__c, KYC_Status__c 
            FROM Partner__c 
            WHERE Id = :partnerId 
            WITH SYSTEM_MODE 
            LIMIT 1
        ];

        if (partners.isEmpty()) {
            throw new SecurityException('Channel Partner account not found.');
        }

        Partner__c partner = partners[0];
        if (partner.Status__c != 'Approved') {
            throw new SecurityException('Channel Partner account is currently ' + partner.Status__c + '. Actions are restricted.');
        }

        if (partner.KYC_Status__c != 'Approved') {
            throw new SecurityException('Channel Partner KYC is not approved (Current KYC Status: ' + partner.KYC_Status__c + '). Please complete KYC verification.');
        }
    }

    /**
     * @description Enforces that the current partner has explicit, active project authorization.
     * @param partnerId Partner__c ID
     * @param projectId Project__c ID
     * @return Project_Access__c record if valid
     */
    public static Project_Access__c validateProjectAccess(Id partnerId, Id projectId) {
        validatePartnerActiveAndApproved(partnerId);

        if (projectId == null) {
            throw new SecurityException('Project identification is required.');
        }

        Date today = Date.today();
        List<Project_Access__c> accessList = [
            SELECT Id, Name, Partner__c, Project__c, Access_Status__c, Start_Date__c, End_Date__c,
                   Can_Register_Lead__c, Can_View_Inventory__c, Can_Create_Site_Visit__c, Commission_Eligible__c
            FROM Project_Access__c
            WHERE Partner__c = :partnerId
              AND Project__c = :projectId
              AND Access_Status__c = 'Active'
              AND Start_Date__c <= :today
              AND End_Date__c >= :today
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (accessList.isEmpty()) {
            throw new SecurityException('You do not have active authorization to access this project or your access period has expired.');
        }

        return accessList[0];
    }

    /**
     * @description Sanitizes exception messages to prevent exposing raw stack traces or sensitive schema details.
     * @param e Exception
     * @return User-friendly message
     */
    public static String getSanitizedErrorMessage(Exception e) {
        if (e instanceof SecurityException || e instanceof AuraHandledException) {
            return e.getMessage();
        }
        return 'An unexpected error occurred while processing your request. Please contact support if the issue persists.';
    }
}
