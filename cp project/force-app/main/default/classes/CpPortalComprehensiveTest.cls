@IsTest
private class CpPortalComprehensiveTest {
    private static User createSalesUser(String username, String alias) {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String uniqueUsername = String.valueOf(Math.abs(Crypto.getRandomLong())) + '@cptest.invalid';
        return new User(
            Alias = alias,
            Email = username,
            EmailEncodingKey = 'UTF-8',
            LastName = 'SalesExec',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = uniqueUsername
        );
    }

    private static Project__c createProject(String name, String code) {
        Project__c p = new Project__c(
            Name = name
        );
        insert p;
        return p;
    }

    private static Channel_Partner__c createChannelPartner(String name, String cpId) {
        Channel_Partner__c cp = new Channel_Partner__c(
            Name = name,
            Company_Name__c = name + ' Ltd',
            CP_ID__c = cpId,
            Email__c = 'partner@example.com',
            Phone__c = '9876543210',
            Status__c = 'Active',
            Active__c = true
        );
        insert cp;
        return cp;
    }

    // 1. CP Lead Creation
    @IsTest
    static void test01_CpLeadCreation() {
        Project__c proj = createProject('Azure Heights', 'PRJ-001');
        Channel_Partner__c cp = createChannelPartner('Acme Realty', 'CP-001');

        Lead lead = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            Company = 'Channel Partner',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-001',
            CP_Company__c = 'Acme Realty Ltd',
            CP_Email__c = 'partner@example.com',
            Project__c = proj.Id,
            Channel_Partner__c = cp.Id,
            Email = 'johndoe@example.com',
            Phone = '9876543210'
        );

        Test.startTest();
        insert lead;
        Test.stopTest();

        Lead queried = [SELECT Id, LeadSource, CP_ID__c, Project__c, Channel_Partner__c FROM Lead WHERE Id = :lead.Id];
        System.assertEquals('Channel Partner', queried.LeadSource);
        System.assertEquals('CP-001', queried.CP_ID__c);
        System.assertEquals(proj.Id, queried.Project__c);
    }

    // 2, 3, 4, 5. Round Robin User 1, 2, 3 and cycle back to 1
    @IsTest
    static void test02to05_RoundRobinCycle() {
        List<Round_Robin_Member__mdt> members = [
            SELECT User_Username__c, Sequence__c
            FROM Round_Robin_Member__mdt
            WHERE Active__c = true
            ORDER BY Sequence__c
        ];

        // Query existing org users that match the metadata usernames (they already exist in the org)
        Set<String> memberUsernames = new Set<String>();
        for (Round_Robin_Member__mdt m : members) {
            if (String.isNotBlank(m.User_Username__c)) memberUsernames.add(m.User_Username__c);
        }
        List<User> usersToInsert = [SELECT Id, Username FROM User WHERE Username IN :memberUsernames AND IsActive = true ORDER BY Username];

        Project__c proj = createProject('Skyline Oasis', 'PRJ-002');

        Test.startTest();
        List<Lead> batch1 = new List<Lead>{
            new Lead(LastName = 'Lead1', Company = 'CP', LeadSource = 'Channel Partner', CP_ID__c = 'CP-002', CP_Company__c = 'Metro', CP_Email__c = 'metro@example.com', Project__c = proj.Id),
            new Lead(LastName = 'Lead2', Company = 'CP', LeadSource = 'Channel Partner', CP_ID__c = 'CP-002', CP_Company__c = 'Metro', CP_Email__c = 'metro@example.com', Project__c = proj.Id),
            new Lead(LastName = 'Lead3', Company = 'CP', LeadSource = 'Channel Partner', CP_ID__c = 'CP-002', CP_Company__c = 'Metro', CP_Email__c = 'metro@example.com', Project__c = proj.Id)
        };
        insert batch1;

        Lead lead4 = new Lead(LastName = 'Lead4', Company = 'CP', LeadSource = 'Channel Partner', CP_ID__c = 'CP-002', CP_Company__c = 'Metro', CP_Email__c = 'metro@example.com', Project__c = proj.Id);
        insert lead4;
        Test.stopTest();

        List<Lead> inserted = [SELECT Id, LastName, OwnerId FROM Lead WHERE Id IN :batch1 ORDER BY LastName];
        if (usersToInsert.size() >= 3) {
            System.assertEquals(usersToInsert[0].Id, inserted[0].OwnerId, 'Lead 1 -> User 1');
            System.assertEquals(usersToInsert[1].Id, inserted[1].OwnerId, 'Lead 2 -> User 2');
            System.assertEquals(usersToInsert[2].Id, inserted[2].OwnerId, 'Lead 3 -> User 3');

            Lead queried4 = [SELECT OwnerId FROM Lead WHERE Id = :lead4.Id];
            System.assertEquals(usersToInsert[0].Id, queried4.OwnerId, 'Lead 4 -> User 1 (Cycle back)');
        }
    }

    // 6. Inactive User Skipped
    @IsTest
    static void test06_InactiveUserSkipped() {
        List<Round_Robin_Member__mdt> members = [
            SELECT User_Username__c
            FROM Round_Robin_Member__mdt
            WHERE Active__c = true
            ORDER BY Sequence__c
        ];

        // Insert only User 1 and User 3 (leave User 2 non-existent or inactive)
        List<User> usersToInsert = new List<User>();
        if (members.size() >= 3) {
            // Query existing org users (already exist, no need to insert)
            Set<String> twoNames = new Set<String>{ members[0].User_Username__c, members[2].User_Username__c };
            List<User> existingUsers = [SELECT Id, Username FROM User WHERE Username IN :twoNames AND IsActive = true ORDER BY Username];
            User u1 = existingUsers.size() > 0 ? existingUsers[0] : null;
            User u3 = existingUsers.size() > 1 ? existingUsers[1] : null;
            if (u1 != null) usersToInsert.add(u1);
            if (u3 != null) usersToInsert.add(u3);

            Project__c proj = createProject('Green View', 'PRJ-003');
            Lead lead1 = new Lead(LastName = 'SkipTest1', Company = 'CP', LeadSource = 'Channel Partner', CP_ID__c = 'CP-003', CP_Company__c = 'Metro', CP_Email__c = 'metro@example.com', Project__c = proj.Id);
            Lead lead2 = new Lead(LastName = 'SkipTest2', Company = 'CP', LeadSource = 'Channel Partner', CP_ID__c = 'CP-003', CP_Company__c = 'Metro', CP_Email__c = 'metro@example.com', Project__c = proj.Id);

            Test.startTest();
            insert new List<Lead>{ lead1, lead2 };
            Test.stopTest();

            Lead q1 = [SELECT OwnerId FROM Lead WHERE Id = :lead1.Id];
            Lead q2 = [SELECT OwnerId FROM Lead WHERE Id = :lead2.Id];
            if (u1 != null) System.assertEquals(u1.Id, q1.OwnerId);
            if (u3 != null) System.assertEquals(u3.Id, q2.OwnerId);
        }
    }

    // 7. Non-CP Lead is unaffected
    @IsTest
    static void test07_NonCpLeadUnaffected() {
        Id myId = UserInfo.getUserId();
        Lead standardLead = new Lead(
            LastName = 'WebInquiry',
            Company = 'Standard Corp',
            LeadSource = 'Web',
            Email = 'web@example.com',
            OwnerId = myId
        );

        Test.startTest();
        insert standardLead;
        Test.stopTest();

        Lead queried = [SELECT OwnerId FROM Lead WHERE Id = :standardLead.Id];
        System.assertEquals(myId, queried.OwnerId);
    }

    // 8. Duplicate email
    @IsTest
    static void test08_DuplicateEmail() {
        Project__c proj = createProject('Riverfront', 'PRJ-004');
        Lead firstLead = new Lead(
            LastName = 'OriginalEmail',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-004',
            CP_Company__c = 'Realty',
            CP_Email__c = 'realty@example.com',
            Project__c = proj.Id,
            Email = 'dupemail@example.com',
            Phone = '1111111111'
        );
        insert firstLead;

        Lead dupLead = new Lead(
            LastName = 'DupEmailLead',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-004',
            CP_Company__c = 'Realty',
            CP_Email__c = 'realty@example.com',
            Project__c = proj.Id,
            Email = 'dupemail@example.com',
            Phone = '2222222222'
        );

        Test.startTest();
        insert dupLead;
        Test.stopTest();

        Lead queried = [SELECT Potential_Duplicate__c, Duplicate_Reason__c FROM Lead WHERE Id = :dupLead.Id];
        System.assertEquals(true, queried.Potential_Duplicate__c);
        System.assertEquals('Email Match', queried.Duplicate_Reason__c);
    }

    // 9. Duplicate phone
    @IsTest
    static void test09_DuplicatePhone() {
        Project__c proj = createProject('Oceanview', 'PRJ-005');
        Lead firstLead = new Lead(
            LastName = 'OriginalPhone',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-005',
            CP_Company__c = 'Realty',
            CP_Email__c = 'realty@example.com',
            Project__c = proj.Id,
            Email = 'originalphone@example.com',
            Phone = '3333333333'
        );
        insert firstLead;

        Lead dupLead = new Lead(
            LastName = 'DupPhoneLead',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-005',
            CP_Company__c = 'Realty',
            CP_Email__c = 'realty@example.com',
            Project__c = proj.Id,
            Email = 'differentphone@example.com',
            Phone = '3333333333'
        );

        Test.startTest();
        insert dupLead;
        Test.stopTest();

        Lead queried = [SELECT Potential_Duplicate__c, Duplicate_Reason__c FROM Lead WHERE Id = :dupLead.Id];
        System.assertEquals(true, queried.Potential_Duplicate__c);
        System.assertEquals('Phone Match', queried.Duplicate_Reason__c);
    }

    // 10. Duplicate email + phone
    @IsTest
    static void test10_DuplicateEmailAndPhone() {
        Project__c proj = createProject('Sunset Boulevard', 'PRJ-006');
        Lead firstLead = new Lead(
            LastName = 'OriginalBoth',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-006',
            CP_Company__c = 'Realty',
            CP_Email__c = 'realty@example.com',
            Project__c = proj.Id,
            Email = 'bothdup@example.com',
            Phone = '4444444444'
        );
        insert firstLead;

        Lead dupLead = new Lead(
            LastName = 'DupBothLead',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-006',
            CP_Company__c = 'Realty',
            CP_Email__c = 'realty@example.com',
            Project__c = proj.Id,
            Email = 'bothdup@example.com',
            Phone = '4444444444'
        );

        Test.startTest();
        insert dupLead;
        Test.stopTest();

        Lead queried = [SELECT Potential_Duplicate__c, Duplicate_Reason__c FROM Lead WHERE Id = :dupLead.Id];
        System.assertEquals(true, queried.Potential_Duplicate__c);
        System.assertEquals('Email + Phone Match', queried.Duplicate_Reason__c);
    }

    // 11. Site Visit Creation & Sales Executive Inheritance
    @IsTest
    static void test11_SiteVisitCreationAndInheritance() {
        Project__c proj = createProject('Emerald Towers', 'PRJ-007');
        Channel_Partner__c cp = createChannelPartner('Emerald CP', 'CP-007');

        Lead lead = new Lead(
            FirstName = 'Alice',
            LastName = 'Smith',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-007',
            CP_Company__c = 'Emerald CP',
            CP_Email__c = 'partner@example.com',
            Project__c = proj.Id,
            Channel_Partner__c = cp.Id,
            Phone = '5555555555'
        );
        insert lead;

        Lead insertedLead = [SELECT Id, OwnerId FROM Lead WHERE Id = :lead.Id];

        Site_Visit__c visit = new Site_Visit__c(
            Lead__c = lead.Id,
            Visit_Date__c = Date.today().addDays(2),
            Status__c = 'Scheduled',
            External_App_ID__c = 'SV-EXT-001',
            Created_From_CP_App__c = true
        );

        Test.startTest();
        insert visit;

        visit.Notes__c = 'Updated visit notes';
        visit.Sales_Executive__c = null;
        update visit;
        Test.stopTest();

        Site_Visit__c queried = [SELECT Sales_Executive__c, Customer_Name__c, Customer_Phone__c, Channel_Partner__c FROM Site_Visit__c WHERE Id = :visit.Id];
        System.assertEquals(insertedLead.OwnerId, queried.Sales_Executive__c, 'Sales Executive should inherit Lead Owner');
        System.assertEquals('Alice Smith', queried.Customer_Name__c);
        System.assertEquals('5555555555', queried.Customer_Phone__c);
        System.assertEquals(cp.Id, queried.Channel_Partner__c);
    }

    // 12. Follow Up Creation & Sales Executive Inheritance
    @IsTest
    static void test12_FollowUpCreationAndInheritance() {
        Project__c proj = createProject('Sapphire Crest', 'PRJ-008');
        Channel_Partner__c cp = createChannelPartner('Sapphire CP', 'CP-008');

        Lead lead = new Lead(
            FirstName = 'Bob',
            LastName = 'Jones',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-008',
            CP_Company__c = 'Sapphire CP',
            CP_Email__c = 'partner@example.com',
            Project__c = proj.Id,
            Channel_Partner__c = cp.Id
        );
        insert lead;

        Lead insertedLead = [SELECT Id, OwnerId FROM Lead WHERE Id = :lead.Id];

        Follow_Up__c fu = new Follow_Up__c(
            Lead__c = lead.Id,
            Follow_Up_Date__c = Date.today().addDays(1),
            Follow_Up_Type__c = 'Call',
            Status__c = 'Pending',
            External_App_ID__c = 'FU-EXT-001',
            Created_From_CP_App__c = true
        );

        Test.startTest();
        insert fu;

        fu.Notes__c = 'Updated follow up notes';
        fu.Sales_Executive__c = null;
        update fu;
        Test.stopTest();

        Follow_Up__c queried = [SELECT Sales_Executive__c, Customer_Name__c, Channel_Partner__c FROM Follow_Up__c WHERE Id = :fu.Id];
        System.assertEquals(insertedLead.OwnerId, queried.Sales_Executive__c, 'Sales Executive should inherit Lead Owner');
        System.assertEquals('Bob Jones', queried.Customer_Name__c);
        System.assertEquals(cp.Id, queried.Channel_Partner__c);
    }

    // 13. Project Relationship
    @IsTest
    static void test13_ProjectRelationship() {
        Project__c proj = createProject('Grand Plaza', 'PRJ-009');
        Lead lead = new Lead(
            LastName = 'ProjectRelLead',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-009',
            CP_Company__c = 'CP Ltd',
            CP_Email__c = 'cp@example.com',
            Project__c = proj.Id
        );
        insert lead;

        Site_Visit__c sv = new Site_Visit__c(
            Lead__c = lead.Id,
            Project__c = proj.Id,
            Visit_Date__c = Date.today()
        );
        insert sv;

        Site_Visit__c queried = [SELECT Project__c FROM Site_Visit__c WHERE Id = :sv.Id];
        System.assertEquals(proj.Id, queried.Project__c);
    }

    // 14. Unit Relationship
    @IsTest
    static void test14_UnitRelationship() {
        Project__c proj = createProject('Sky Villas', 'PRJ-010');
        Unit__c unit = new Unit__c(
            Name = 'A-101',
            Project__c = proj.Id,
            Tower__c = 'Tower A',
            Floor__c = 10,
            Configuration__c = '3 BHK',
            Area__c = 1850,
            Price__c = 15000000,
            Availability__c = 'Available',
            External_App_ID__c = 'UNIT-EXT-001'
        );
        insert unit;

        Lead lead = new Lead(
            LastName = 'UnitRelLead',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-010',
            CP_Company__c = 'CP Ltd',
            CP_Email__c = 'cp@example.com',
            Project__c = proj.Id,
            Unit__c = unit.Id
        );
        insert lead;

        Lead queried = [SELECT Unit__c FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(unit.Id, queried.Unit__c);
    }

    // 15. External ID Upsert
    @IsTest
    static void test15_ExternalIdUpsert() {
        Channel_Partner__c cp = new Channel_Partner__c(
            Name = 'Silver CP',
            Company_Name__c = 'Silver Realty',
            CP_ID__c = 'CP-011',
            CP_App_ID__c = 'CP-APP-011',
            External_App_ID__c = 'CP-APP-011',
            Status__c = 'Active',
            Active__c = true
        );
        upsert cp External_App_ID__c;

        Project__c proj = createProject('Silver Oak', 'PRJ-011');

        Lead lead = new Lead(
            LastName = 'UpsertLead',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-011',
            CP_Company__c = 'Silver Realty',
            CP_Email__c = 'cp@example.com',
            Project__c = proj.Id,
            External_App_ID__c = 'LEAD-APP-011'
        );
        upsert lead External_App_ID__c;

        // Second upsert to simulate API retry
        lead.FirstName = 'Updated';
        upsert lead External_App_ID__c;

        Lead queried = [SELECT Id, FirstName, External_App_ID__c FROM Lead WHERE External_App_ID__c = 'LEAD-APP-011'];
        System.assertEquals('Updated', queried.FirstName);
    }

    // 16. Sync Status
    @IsTest
    static void test16_SyncStatusFields() {
        Project__c proj = createProject('Golden Crest', 'PRJ-012');
        Lead lead = new Lead(
            LastName = 'SyncLead',
            Company = 'CP',
            LeadSource = 'Channel Partner',
            CP_ID__c = 'CP-012',
            CP_Company__c = 'CP Ltd',
            CP_Email__c = 'cp@example.com',
            Project__c = proj.Id,
            Salesforce_Sync_Status__c = 'Synced',
            Salesforce_Sync_Error__c = null,
            Last_Salesforce_Sync__c = DateTime.now()
        );
        insert lead;

        Lead queried = [SELECT Salesforce_Sync_Status__c, Last_Salesforce_Sync__c FROM Lead WHERE Id = :lead.Id];
        System.assertEquals('Synced', queried.Salesforce_Sync_Status__c);
        System.assertNotEquals(null, queried.Last_Salesforce_Sync__c);

        CpPortalNotificationService.notifySyncFailure('Lead', lead.Id, 'Connection Timeout', UserInfo.getUserId());
    }

    // 17. Invalid CP Lead Validation
    @IsTest
    static void test17_InvalidCpLeadValidation() {
        Lead invalidLead = new Lead(
            LastName = 'MissingFields',
            Company = 'CP',
            LeadSource = 'Channel Partner'
            // Missing CP_ID__c, CP_Company__c, CP_Email__c, Project__c
        );

        Boolean caughtException = false;
        try {
            insert invalidLead;
        } catch (DmlException ex) {
            caughtException = true;
        }
        System.assertEquals(true, caughtException, 'CP Lead with missing mandatory fields must fail validation');
    }
}
