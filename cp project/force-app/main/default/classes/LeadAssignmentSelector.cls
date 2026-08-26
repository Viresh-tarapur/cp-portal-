/**
 * @description Selector layer for Round Robin Lead Assignment.
 * Encapsulates all SOQL queries for Projects, Users, Metadata, and persistent States.
 * Fingertipplus Technologies - Real Estate Pre-Sales CRM
 */
public without sharing class LeadAssignmentSelector {

    @TestVisible
    private static List<Round_Robin_Config__mdt> mockConfigs;

    @TestVisible
    private static List<User> mockUsers;

    /**
     * @description Retrieves active Round Robin configurations sorted by evaluation order.
     * @return List of active Round_Robin_Config__mdt records.
     */
    public static List<Round_Robin_Config__mdt> getRoundRobinConfigs() {
        if (mockConfigs != null) {
            return mockConfigs;
        }
        return [
            SELECT Id, DeveloperName, MasterLabel, Team_Name__c, Location__c,
                   Role_Developer_Names__c, Profile_Names__c, User_City__c,
                   User_Department__c, Fallback_Username__c, Active__c, Order__c
            FROM Round_Robin_Config__mdt
            WHERE Active__c = true
            ORDER BY Order__c ASC NULLS LAST
        ];
    }

    /**
     * @description Queries Project records to resolve project locations/cities.
     * @param projectIds Set of Project IDs.
     * @return Map of Project Id to Project__c record.
     */
    public static Map<Id, Project__c> getProjectsByIds(Set<Id> projectIds) {
        if (projectIds == null || projectIds.isEmpty()) {
            return new Map<Id, Project__c>();
        }
        return new Map<Id, Project__c>([
            SELECT Id, Name, City__c, State__c, Project_Code__c
            FROM Project__c
            WHERE Id IN :projectIds
        ]);
    }

    /**
     * @description Queries all active standard users in deterministic order (Name ASC, Id ASC).
     * Excludes system and integration accounts by filtering UserType and active status.
     * @return List of active User records.
     */
    public static List<User> getActiveStandardUsers() {
        if (mockUsers != null) {
            return mockUsers;
        }
        return [
            SELECT Id, Name, Username, FirstName, LastName, Alias, Email,
                   IsActive, UserRoleId, UserRole.Name, UserRole.DeveloperName,
                   ProfileId, Profile.Name, UserType, Department, City, State, Title
            FROM User
            WHERE IsActive = true
              AND UserType = 'Standard'
            ORDER BY Name ASC, Id ASC
        ];
    }

    /**
     * @description Queries Round_Robin_State__c records FOR UPDATE to lock records during assignment.
     * @param teamNames Set of unique Team Names.
     * @return Map of Team_Name__c to Round_Robin_State__c.
     */
    public static Map<String, Round_Robin_State__c> getRoundRobinStatesForUpdate(Set<String> teamNames) {
        Map<String, Round_Robin_State__c> stateMap = new Map<String, Round_Robin_State__c>();
        if (teamNames == null || teamNames.isEmpty()) {
            return stateMap;
        }

        List<Round_Robin_State__c> states = [
            SELECT Id, Name, Team_Name__c, Last_Assigned_User__c,
                   Last_Assigned_User_Id__c, Last_Assignment_Date__c, Total_Assignments__c
            FROM Round_Robin_State__c
            WHERE Team_Name__c IN :teamNames
            FOR UPDATE
        ];

        for (Round_Robin_State__c state : states) {
            if (state.Team_Name__c != null) {
                stateMap.put(state.Team_Name__c.toUpperCase(), state);
            }
        }
        return stateMap;
    }
}
