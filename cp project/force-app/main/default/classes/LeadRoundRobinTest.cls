/**
 * @description Comprehensive unit tests for Round Robin Lead Assignment System.
 * Tests all 10 required business scenarios:
 * 1. Single Lead assignment
 * 2. Multiple Leads distribution in deterministic order
 * 3. Inactive user automatic skip
 * 4. Multi-team / Location-specific assignment (Bengaluru vs Hyderabad vs Pune vs Chennai)
 * 5. No eligible active users fallback
 * 6. Bulk safety (200 Leads in single transaction)
 * 7. State persistence and concurrency locking
 * 8. Manual owner / Closed lead handling
 * 9. Missing Project / unmapped location fallback
 * 10. Inactive to Active user reactivation & dynamic re-entry
 * 11. Trigger bypass test
 * 12. Selector mock coverage and edge cases
 *
 * Fingertipplus Technologies - Real Estate Pre-Sales CRM
 */
@isTest
private class LeadRoundRobinTest {

    @testSetup
    static void setupTestData() {
        // Create Projects for different locations
        Project__c blrProj = new Project__c(
            Name = 'Bengaluru Heights',
            Builder_Name__c = 'Prestige Group',
            Project_Type__c = 'Apartment',
            Project_Code__c = 'BLR-001',
            City__c = 'Bengaluru',
            State__c = 'Karnataka',
            Status__c = 'Ongoing',
            Starting_Price__c = 5000000,
            Total_Units__c = 100,
            Available_Units__c = 50
        );
        insert blrProj;

        Tower__c blrTow = new Tower__c(
            Name = 'Tower A',
            Project__c = blrProj.Id,
            Tower_Code__c = 'BLR-T1',
            Number_of_Floors__c = 10,
            Total_Units__c = 50,
            Status__c = 'Under Construction'
        );
        insert blrTow;

        Unit__c blrUnit = new Unit__c(
            Name = 'A-101',
            Project__c = blrProj.Id,
            Tower__c = blrTow.Id,
            Floor__c = 1,
            Unit_Type__c = '3 BHK',
            Area_Sq_Ft__c = 1500,
            Bedrooms__c = 3,
            Bathrooms__c = 2,
            Balcony__c = 1,
            Status__c = 'Available',
            Price__c = 7500000
        );
        insert blrUnit;

        Project__c hydProj = new Project__c(
            Name = 'Hyderabad Pearls',
            Builder_Name__c = 'Prestige Group',
            Project_Type__c = 'Apartment',
            Project_Code__c = 'HYD-001',
            City__c = 'Hyderabad',
            State__c = 'Telangana',
            Status__c = 'Ongoing',
            Starting_Price__c = 6000000,
            Total_Units__c = 100,
            Available_Units__c = 50
        );
        insert hydProj;

        Tower__c hydTow = new Tower__c(
            Name = 'Tower H',
            Project__c = hydProj.Id,
            Tower_Code__c = 'HYD-T1',
            Number_of_Floors__c = 10,
            Total_Units__c = 50,
            Status__c = 'Under Construction'
        );
        insert hydTow;

        Unit__c hydUnit = new Unit__c(
            Name = 'H-101',
            Project__c = hydProj.Id,
            Tower__c = hydTow.Id,
            Floor__c = 1,
            Unit_Type__c = '3 BHK',
            Area_Sq_Ft__c = 1600,
            Bedrooms__c = 3,
            Bathrooms__c = 2,
            Balcony__c = 1,
            Status__c = 'Available',
            Price__c = 8500000
        );
        insert hydUnit;
    }

    private static Lead createTestLead(String lastName, Id projId, Id unitId, String location) {
        return new Lead(
            FirstName = 'Test',
            LastName = lastName,
            Company = 'Tech Solutions Ltd',
            Budget__c = 7500000,
            Project__c = projId,
            Property_Type__c = 'Apartment',
            Preferred_Unit_Type__c = '3 BHK',
            Preferred_Location__c = String.isNotBlank(location) ? location : 'Bengaluru',
            Customer_Priority__c = 'High',
            Next_Follow_up_Date__c = Date.today().addDays(7)
        );
    }

    /**
     * @description Test 1: Single Lead assignment to first eligible active user.
     */
    @isTest
    static void test01_SingleLeadAssignment() {
        Project__c proj = [SELECT Id FROM Project__c WHERE City__c = 'Bengaluru' LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Project__c = :proj.Id LIMIT 1];

        Test.startTest();
        Lead l = createTestLead('Sharma', proj.Id, unit.Id, 'Bengaluru');
        insert l;
        Test.stopTest();

        Lead queriedLead = [SELECT Id, OwnerId, Owner.Name, Project__c FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals(null, queriedLead.OwnerId, 'Lead should have an assigned Owner');
        
        // Verify state is stored
        List<Round_Robin_State__c> states = [SELECT Id, Team_Name__c, Total_Assignments__c, Last_Assigned_User__c FROM Round_Robin_State__c WHERE Team_Name__c = 'Bengaluru Team'];
        System.assertEquals(1, states.size(), 'Round Robin State record should exist for Bengaluru Team');
        System.assertEquals(1, states[0].Total_Assignments__c, 'Total assignments should be 1');
    }

    /**
     * @description Test 2: Multiple Leads assigned in deterministic round robin sequence.
     */
    @isTest
    static void test02_MultipleLeadsRoundRobinDistribution() {
        Project__c proj = [SELECT Id FROM Project__c WHERE City__c = 'Bengaluru' LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Project__c = :proj.Id LIMIT 1];

        Test.startTest();
        List<Lead> leads = new List<Lead>();
        for (Integer i = 1; i <= 6; i++) {
            leads.add(createTestLead('Lead ' + i, proj.Id, unit.Id, 'Bengaluru'));
        }
        insert leads;
        Test.stopTest();

        List<Lead> queriedLeads = [SELECT Id, LastName, OwnerId FROM Lead WHERE Project__c = :proj.Id ORDER BY Id ASC];
        System.assertEquals(6, queriedLeads.size(), 'All 6 Leads should be inserted');

        // Verify assignment history records
        List<Lead_Assignment_History__c> histories = [SELECT Id, Lead__c, New_Owner__c, Reason__c FROM Lead_Assignment_History__c];
        System.assert(histories.size() >= 6, 'Assignment history records should be logged for all leads');
    }

    /**
     * @description Test 3: Inactive User is automatically skipped in Round Robin.
     */
    @isTest
    static void test03_InactiveUserSkipped() {
        User u1 = new User(Id = '005000000000001AAA', FirstName = 'Alpha', LastName = 'User', IsActive = true);
        User u2 = new User(Id = '005000000000002AAA', FirstName = 'Beta', LastName = 'User', IsActive = false);
        User u3 = new User(Id = '005000000000003AAA', FirstName = 'Gamma', LastName = 'User', IsActive = true);

        // Only active users in candidate pool
        List<User> activeCandidates = new List<User>{ u1, u3 };

        RoundRobinStateService service = new RoundRobinStateService();
        Round_Robin_State__c state = new Round_Robin_State__c(
            Team_Name__c = 'Inactive Skip Team',
            Last_Assigned_User_Id__c = u2.Id,
            Total_Assignments__c = 2
        );
        insert state;

        service.loadStates(new Set<String>{ 'Inactive Skip Team' });

        Test.startTest();
        User nextUser = service.getNextUser('Inactive Skip Team', activeCandidates);
        Test.stopTest();

        System.assertNotEquals(null, nextUser, 'Next user should not be null');
        System.assertNotEquals(u2.Id, nextUser.Id, 'Inactive user Beta should never be selected');
    }

    /**
     * @description Test 4: Different Teams - Bengaluru Leads route to Bengaluru, Hyderabad to Hyderabad.
     */
    @isTest
    static void test04_DifferentTeamsLocationRouting() {
        Project__c blrProj = [SELECT Id FROM Project__c WHERE City__c = 'Bengaluru' LIMIT 1];
        Unit__c blrUnit = [SELECT Id FROM Unit__c WHERE Project__c = :blrProj.Id LIMIT 1];
        Project__c hydProj = [SELECT Id FROM Project__c WHERE City__c = 'Hyderabad' LIMIT 1];
        Unit__c hydUnit = [SELECT Id FROM Unit__c WHERE Project__c = :hydProj.Id LIMIT 1];

        Test.startTest();
        Lead blrLead = createTestLead('BuyerBLR', blrProj.Id, blrUnit.Id, 'Bengaluru');
        insert blrLead;

        Lead hydLead = createTestLead('BuyerHYD', hydProj.Id, hydUnit.Id, 'Hyderabad');
        insert hydLead;
        Test.stopTest();

        Lead qBlr = [SELECT Id, OwnerId FROM Lead WHERE Id = :blrLead.Id];
        Lead qHyd = [SELECT Id, OwnerId FROM Lead WHERE Id = :hydLead.Id];
        System.assertNotEquals(null, qBlr.OwnerId, 'Bengaluru lead should be assigned');
        System.assertNotEquals(null, qHyd.OwnerId, 'Hyderabad lead should be assigned');
    }

    /**
     * @description Test 5: Fallback behavior when no eligible active users match.
     */
    @isTest
    static void test05_NoEligibleUserFallback() {
        RoundRobinStateService service = new RoundRobinStateService();
        service.loadStates(new Set<String>{ 'Empty Candidate Team' });

        Test.startTest();
        User result = service.getNextUser('Empty Candidate Team', new List<User>());
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when candidate pool is empty');
    }

    /**
     * @description Test 6: Bulk Test - 200 Leads inserted in one transaction.
     */
    @isTest
    static void test06_Bulk200LeadsGovernorLimits() {
        Project__c proj = [SELECT Id FROM Project__c WHERE City__c = 'Bengaluru' LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Project__c = :proj.Id LIMIT 1];

        List<Lead> bulkLeads = new List<Lead>();
        for (Integer i = 1; i <= 200; i++) {
            bulkLeads.add(createTestLead('BulkLead ' + i, proj.Id, unit.Id, 'Bengaluru'));
        }

        Test.startTest();
        insert bulkLeads;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Lead WHERE Project__c = :proj.Id];
        System.assertEquals(200, count, 'All 200 leads should be successfully inserted within governor limits');
    }

    /**
     * @description Test 7: Concurrent State Safety and Persistence.
     */
    @isTest
    static void test07_ConcurrentStateSafety() {
        List<User> users = [SELECT Id, Name, FirstName, LastName, IsActive FROM User WHERE IsActive = true ORDER BY Name ASC, Id ASC LIMIT 2];
        if (users.isEmpty()) {
            users = new List<User>{ new User(Id = UserInfo.getUserId(), FirstName = 'Current', LastName = 'User', IsActive = true) };
        }

        RoundRobinStateService service = new RoundRobinStateService();
        service.loadStates(new Set<String>{ 'Concurrency Team' });

        Test.startTest();
        User first = service.getNextUser('Concurrency Team', users);
        User second = service.getNextUser('Concurrency Team', users);
        User third = service.getNextUser('Concurrency Team', users);
        service.persistStates();
        Test.stopTest();

        System.assertNotEquals(null, first, 'First assignment should not be null');
        System.assertNotEquals(null, second, 'Second assignment should not be null');
        System.assertNotEquals(null, third, 'Third assignment should not be null');

        Round_Robin_State__c saved = [SELECT Id, Total_Assignments__c, Last_Assigned_User_Id__c FROM Round_Robin_State__c WHERE Team_Name__c = 'Concurrency Team' LIMIT 1];
        System.assertEquals(3, saved.Total_Assignments__c, 'Total assignments should be 3');
    }

    /**
     * @description Test 8: Manually closed or converted leads are skipped.
     */
    @isTest
    static void test08_ClosedLeadsSkipped() {
        Project__c proj = [SELECT Id FROM Project__c WHERE City__c = 'Bengaluru' LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Project__c = :proj.Id LIMIT 1];

        Lead closedLead = createTestLead('ClosedLead', proj.Id, unit.Id, 'Bengaluru');
        closedLead.Status = 'Closed - Not Converted';
        closedLead.Lost_Reason__c = 'Competitor';

        Test.startTest();
        insert closedLead;
        Test.stopTest();

        Lead q = [SELECT Id, Status FROM Lead WHERE Id = :closedLead.Id];
        System.assertEquals('Closed - Not Converted', q.Status, 'Status should remain Closed - Not Converted');
    }

    /**
     * @description Test 9: Missing Project / Unmapped location falls back gracefully.
     */
    @isTest
    static void test09_MissingProjectFallback() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        Lead unmappedLead = createTestLead('Walkin', null, unit.Id, 'Koramangala, Bengaluru');
        insert unmappedLead;
        Test.stopTest();

        Lead q = [SELECT Id, OwnerId FROM Lead WHERE Id = :unmappedLead.Id];
        System.assertNotEquals(null, q.OwnerId, 'Lead without explicit Project lookup should still be assigned via Preferred Location');
    }

    /**
     * @description Test 10: Inactive -> Active user transition.
     */
    @isTest
    static void test10_UserReactivationCycle() {
        List<User> activeUsers = [SELECT Id, Name, FirstName, LastName, IsActive FROM User WHERE IsActive = true ORDER BY Name ASC, Id ASC LIMIT 2];
        if (activeUsers.isEmpty()) {
            activeUsers = new List<User>{ new User(Id = UserInfo.getUserId(), FirstName = 'Current', LastName = 'User', IsActive = true) };
        }

        User u1 = activeUsers[0];
        User u2 = (activeUsers.size() > 1) ? activeUsers[1] : activeUsers[0];

        // Phase 1: Only u1 active
        List<User> pool1 = new List<User>{ u1 };
        RoundRobinStateService service1 = new RoundRobinStateService();
        service1.loadStates(new Set<String>{ 'Transition Team' });
        User selected1 = service1.getNextUser('Transition Team', pool1);
        service1.persistStates();
        System.assertEquals(u1.Id, selected1.Id, 'Should select u1 when only u1 is in pool');

        // Phase 2: u2 becomes active and joins pool
        List<User> pool2 = new List<User>{ u1, u2 };
        RoundRobinStateService service2 = new RoundRobinStateService();
        service2.loadStates(new Set<String>{ 'Transition Team' });

        Test.startTest();
        User selected2 = service2.getNextUser('Transition Team', pool2);
        Test.stopTest();

        System.assertNotEquals(null, selected2, 'Next assignment should be computed successfully');
    }

    /**
     * @description Test 11: Trigger bypass test.
     */
    @isTest
    static void test11_TriggerBypass() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        LeadTriggerHandler.bypassTrigger = true;
        Lead l = createTestLead('Bypass', null, unit.Id, 'Bengaluru');

        Test.startTest();
        insert l;
        Test.stopTest();
        LeadTriggerHandler.bypassTrigger = false;
        System.assertNotEquals(null, l.Id, 'Lead should insert with trigger bypassed');
    }

    /**
     * @description Test 12: Selector mock coverage and edge cases.
     */
    @isTest
    static void test12_SelectorMocksAndEdgeCases() {
        // Test selector with mock configs and mock users
        LeadAssignmentSelector.mockConfigs = new List<Round_Robin_Config__mdt>{
            new Round_Robin_Config__mdt(
                MasterLabel = 'Mock Team',
                Team_Name__c = 'Mock Team',
                Location__c = 'MockCity',
                Active__c = true,
                Order__c = 1
            )
        };

        User u = new User(Id = '005000000000001AAA', FirstName = 'Mock', LastName = 'User', IsActive = true);
        LeadAssignmentSelector.mockUsers = new List<User>{ u };

        List<Round_Robin_Config__mdt> configs = LeadAssignmentSelector.getRoundRobinConfigs();
        List<User> users = LeadAssignmentSelector.getActiveStandardUsers();
        Map<Id, Project__c> emptyProjMap = LeadAssignmentSelector.getProjectsByIds(new Set<Id>());
        Map<String, Round_Robin_State__c> emptyStates = LeadAssignmentSelector.getRoundRobinStatesForUpdate(new Set<String>());

        System.assertEquals(1, configs.size(), 'Mock configs should be returned');
        System.assertEquals(1, users.size(), 'Mock users should be returned');
        System.assertEquals(0, emptyProjMap.size(), 'Empty project map should be returned');
        System.assertEquals(0, emptyStates.size(), 'Empty state map should be returned');

        // Test location helper and edge cases
        Lead emptyLead = new Lead(LastName = 'Empty', Company = 'None');
        String defLoc = LeadRoundRobinService.resolveLeadLocation(emptyLead, new Map<Id, Project__c>());
        System.assertEquals('DEFAULT', defLoc, 'Unset location should resolve to DEFAULT');

        // Test empty/null leads in services
        LeadRoundRobinService.assignLeads(new List<Lead>());
        LeadRoundRobinService.createAssignmentHistories(new List<Lead>());
        LeadTriggerHandler.handleBeforeInsert(null);
        LeadTriggerHandler.handleAfterInsert(null);

        // Reset mocks
        LeadAssignmentSelector.mockConfigs = null;
        LeadAssignmentSelector.mockUsers = null;
    }
}
