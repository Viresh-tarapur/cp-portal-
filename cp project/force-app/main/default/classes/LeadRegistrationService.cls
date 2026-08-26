/**
 * @description Core service orchestrating Channel Partner Lead Registration,
 * ownership exclusivity protection periods, and CRM lead creation.
 */
public with sharing class LeadRegistrationService {

    public class LeadRegistrationRequest {
        @AuraEnabled public Id partnerId { get; set; }
        @AuraEnabled public Id projectId { get; set; }
        @AuraEnabled public Id inventoryUnitId { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public Decimal budget { get; set; }
        @AuraEnabled public String requirement { get; set; }
        @AuraEnabled public Date expectedPurchaseDate { get; set; }
        @AuraEnabled public String notes { get; set; }
    }

    public class LeadRegistrationResponse {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String registrationNumber { get; set; }
        @AuraEnabled public Id registrationId { get; set; }
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public Date protectionEndDate { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    /**
     * @description Registers a new lead from a Channel Partner with end-to-end validations.
     */
    public static LeadRegistrationResponse registerLead(LeadRegistrationRequest req) {
        LeadRegistrationResponse resp = new LeadRegistrationResponse();

        if (req == null) {
            throw new AuraHandledException('Lead registration request cannot be empty.');
        }

        // 1. Resolve Partner
        Id effectivePartnerId = req.partnerId;
        if (effectivePartnerId == null) {
            effectivePartnerId = SecurityUtil.getCurrentUserPartnerId();
        }
        if (effectivePartnerId == null) {
            throw new AuraHandledException('No Channel Partner account associated with current user.');
        }

        // 2. Validate Partner Active & KYC Approved
        SecurityUtil.validatePartnerActiveAndApproved(effectivePartnerId);

        // 3. Validate Project Access
        Project_Access__c projectAccess = SecurityUtil.validateProjectAccess(effectivePartnerId, req.projectId);
        if (!projectAccess.Can_Register_Lead__c) {
            throw new AuraHandledException('Your account is not permitted to register leads for this project.');
        }

        // 4. Validate Customer Details
        if (String.isBlank(req.customerName)) {
            throw new AuraHandledException('Customer Full Name is required.');
        }
        if (String.isBlank(req.phone)) {
            throw new AuraHandledException('Customer Phone number is required.');
        }

        // 5. Validate Inventory Unit if provided
        if (req.inventoryUnitId != null) {
            List<Inventory_Unit__c> units = [
                SELECT Id, Status__c, Project__c 
                FROM Inventory_Unit__c 
                WHERE Id = :req.inventoryUnitId 
                WITH USER_MODE 
                LIMIT 1
            ];
            if (units.isEmpty() || units[0].Project__c != req.projectId) {
                throw new AuraHandledException('The selected inventory unit does not belong to this project.');
            }
        }

        // 6. Perform Duplicate & Protection Conflict Check
        DuplicateLeadService.DuplicateResult dupCheck = DuplicateLeadService.checkDuplicateLead(
            effectivePartnerId,
            req.projectId,
            req.phone,
            req.email
        );

        if (dupCheck.isDuplicate && dupCheck.isProtectedConflict) {
            // Collision with another partner's protected lead -> reject and log
            Lead_Registration__c conflictReg = new Lead_Registration__c(
                Partner__c = effectivePartnerId,
                Project__c = req.projectId,
                Customer_Name__c = req.customerName,
                Customer_Phone__c = req.phone,
                Customer_Email__c = req.email,
                Budget__c = req.budget,
                Requirement__c = req.requirement,
                Registration_Date__c = DateTime.now(),
                Registration_Status__c = 'Duplicate',
                Ownership_Status__c = 'Disputed',
                Duplicate_Found__c = true,
                Duplicate_Registration__c = dupCheck.conflictingRegistrationId,
                Duplicate_Lead__c = dupCheck.conflictingLeadId,
                Rejection_Reason__c = dupCheck.message
            );
            insert conflictReg;

            IntegrationLogger.logAudit(
                effectivePartnerId,
                conflictReg.Id,
                'Lead_Registration__c',
                'Duplicate Lead Blocked',
                null,
                'Duplicate Blocked',
                dupCheck.message
            );

            throw new AuraHandledException(dupCheck.message);
        }

        // 7. Determine Protection Duration from Custom Metadata
        Integer protectionDays = 90;
        List<CP_Portal_Setting__mdt> settings = [
            SELECT Default_Protection_Days__c 
            FROM CP_Portal_Setting__mdt 
            WHERE DeveloperName = 'Default_Configuration' 
            LIMIT 1
        ];
        if (!settings.isEmpty() && settings[0].Default_Protection_Days__c != null) {
            protectionDays = Integer.valueOf(settings[0].Default_Protection_Days__c);
        }

        Date today = Date.today();
        Date protectionEndDate = today.addDays(protectionDays);

        // 8. Create Standard Lead
        String firstName = '';
        String lastName = req.customerName.trim();
        if (req.customerName.contains(' ')) {
            Integer splitIdx = req.customerName.lastIndexOf(' ');
            firstName = req.customerName.substring(0, splitIdx);
            lastName = req.customerName.substring(splitIdx + 1);
        }

        Lead newLead = new Lead(
            FirstName = firstName,
            LastName = String.isBlank(lastName) ? req.customerName : lastName,
            Company = 'Individual Buyer',
            Phone = req.phone,
            MobilePhone = req.phone,
            Email = req.email,
            Project__c = req.projectId,
            Partner__c = effectivePartnerId,
            Registered_By_Partner__c = true,
            Protected_Until__c = protectionEndDate,
            Status = 'Registered',
            Description = req.notes
        );
        insert newLead;

        // 9. Create Lead_Registration__c Record
        Lead_Registration__c newReg = new Lead_Registration__c(
            Partner__c = effectivePartnerId,
            Lead__c = newLead.Id,
            Project__c = req.projectId,
            Inventory_Unit__c = req.inventoryUnitId,
            Customer_Name__c = req.customerName,
            Customer_Phone__c = req.phone,
            Customer_Email__c = req.email,
            Budget__c = req.budget,
            Requirement__c = req.requirement,
            Expected_Purchase_Date__c = req.expectedPurchaseDate,
            Notes__c = req.notes,
            Registration_Date__c = DateTime.now(),
            Protection_Start_Date__c = today,
            Protection_End_Date__c = protectionEndDate,
            Protection_Days_Granted__c = protectionDays,
            Registration_Status__c = 'Accepted',
            Ownership_Status__c = 'Protected'
        );
        insert newReg;

        // Link registration back to Lead
        newLead.Lead_Registration__c = newReg.Id;
        update newLead;

        // Update Partner metrics
        List<Partner__c> partners = [SELECT Id, Total_Leads_Registered__c FROM Partner__c WHERE Id = :effectivePartnerId LIMIT 1];
        if (!partners.isEmpty()) {
            Partner__c p = partners[0];
            p.Total_Leads_Registered__c = (p.Total_Leads_Registered__c == null ? 0 : p.Total_Leads_Registered__c) + 1;
            update p;
        }

        // Query auto-number registration code
        Lead_Registration__c createdReg = [SELECT Id, Name FROM Lead_Registration__c WHERE Id = :newReg.Id LIMIT 1];

        // Audit Trail
        IntegrationLogger.logAudit(
            effectivePartnerId,
            newReg.Id,
            'Lead_Registration__c',
            'Lead Protected',
            null,
            'Accepted & Protected',
            'Lead registered successfully. Exclusivity granted until ' + protectionEndDate.format()
        );

        resp.isSuccess = true;
        resp.registrationId = newReg.Id;
        resp.leadId = newLead.Id;
        resp.registrationNumber = createdReg.Name;
        resp.protectionEndDate = protectionEndDate;
        resp.message = 'Lead registered successfully. Exclusivity protection active until ' + protectionEndDate.format() + '.';

        return resp;
    }
}
