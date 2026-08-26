public without sharing class CpLeadRoundRobin {
    public static void assign(List<Lead> leads) {
        List<Round_Robin_Member__mdt> configured = [
            SELECT Active__c, Sequence__c, User_Username__c
            FROM Round_Robin_Member__mdt
            WHERE Active__c = true
            ORDER BY Sequence__c
        ];
        if (configured.isEmpty()) return;

        Set<String> usernames = new Set<String>();
        for (Round_Robin_Member__mdt member : configured) {
            if (String.isNotBlank(member.User_Username__c)) {
                usernames.add(member.User_Username__c);
            }
        }
        Map<String, User> usersByUsername = new Map<String, User>();
        for (User user : [SELECT Id, Username, IsActive FROM User WHERE Username IN :usernames AND IsActive = true]) {
            usersByUsername.put(user.Username, user);
        }
        List<Round_Robin_Member__mdt> activeMembers = new List<Round_Robin_Member__mdt>();
        for (Round_Robin_Member__mdt member : configured) {
            if (usersByUsername.containsKey(member.User_Username__c)) {
                activeMembers.add(member);
            }
        }
        if (activeMembers.isEmpty()) return;

        Integer existingCpLeads = [SELECT COUNT() FROM Lead WHERE LeadSource = 'Channel Partner'];
        Integer cursorIndex = Math.mod(existingCpLeads, activeMembers.size());
        for (Lead lead : leads) {
            if (lead.LeadSource != 'Channel Partner') continue;
            Round_Robin_Member__mdt selected = activeMembers[cursorIndex];
            lead.OwnerId = usersByUsername.get(selected.User_Username__c).Id;
            cursorIndex = Math.mod(cursorIndex + 1, activeMembers.size());
        }
    }

    public static void checkDuplicates(List<Lead> leads) {
        Set<String> emails = new Set<String>();
        Set<String> phones = new Set<String>();
        List<Lead> cpLeads = new List<Lead>();

        for (Lead l : leads) {
            if (l.LeadSource == 'Channel Partner') {
                cpLeads.add(l);
                if (String.isNotBlank(l.Email)) emails.add(l.Email.toLowerCase().trim());
                if (String.isNotBlank(l.Phone)) phones.add(l.Phone.trim());
            }
        }
        if (cpLeads.isEmpty()) return;

        Set<String> existingEmails = new Set<String>();
        Set<String> existingPhones = new Set<String>();
        Set<Id> leadIds = new Set<Id>();
        for (Lead l : leads) {
            if (l.Id != null) leadIds.add(l.Id);
        }

        if (!emails.isEmpty() || !phones.isEmpty()) {
            for (Lead existing : [
                SELECT Id, Email, Phone
                FROM Lead
                WHERE (Email IN :emails OR Phone IN :phones)
                AND Id NOT IN :leadIds
            ]) {
                if (String.isNotBlank(existing.Email)) existingEmails.add(existing.Email.toLowerCase().trim());
                if (String.isNotBlank(existing.Phone)) existingPhones.add(existing.Phone.trim());
            }
        }

        Set<String> batchEmails = new Set<String>();
        Set<String> batchPhones = new Set<String>();

        for (Lead lead : cpLeads) {
            String normEmail = String.isNotBlank(lead.Email) ? lead.Email.toLowerCase().trim() : null;
            String normPhone = String.isNotBlank(lead.Phone) ? lead.Phone.trim() : null;

            Boolean emailMatch = (normEmail != null && (existingEmails.contains(normEmail) || batchEmails.contains(normEmail)));
            Boolean phoneMatch = (normPhone != null && (existingPhones.contains(normPhone) || batchPhones.contains(normPhone)));

            if (emailMatch && phoneMatch) {
                lead.Potential_Duplicate__c = true;
                lead.Duplicate_Reason__c = 'Email + Phone Match';
            } else if (emailMatch) {
                lead.Potential_Duplicate__c = true;
                lead.Duplicate_Reason__c = 'Email Match';
            } else if (phoneMatch) {
                lead.Potential_Duplicate__c = true;
                lead.Duplicate_Reason__c = 'Phone Match';
            }

            if (normEmail != null) batchEmails.add(normEmail);
            if (normPhone != null) batchPhones.add(normPhone);
        }
    }
}
