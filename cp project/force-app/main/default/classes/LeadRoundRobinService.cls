/**
 * @description Core service responsible for evaluating and assigning Leads via Round Robin.
 * Real Estate CRM: Handles location/project resolution, team matching, state updates, and history logging.
 * Fingertipplus Technologies - Real Estate Pre-Sales CRM
 */
public without sharing class LeadRoundRobinService {

    // Cache of lead assignments for after-insert history generation
    private static Map<Id, LeadAssignmentInfo> pendingHistories = new Map<Id, LeadAssignmentInfo>();

    public class LeadAssignmentInfo {
        public Id leadId;
        public Id assignedOwnerId;
        public String teamName;
        public String location;
        public String projectName;
    }

    /**
     * @description Main entry point called before insert: Assigns OwnerId to eligible Leads.
     * @param newLeads List of Leads from Trigger.new
     */
    public static void assignLeads(List<Lead> newLeads) {
        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }

        // Step 1: Collect Project IDs
        Set<Id> projectIds = new Set<Id>();
        List<Lead> qualifyingLeads = new List<Lead>();

        for (Lead l : newLeads) {
            // Skip converted or closed leads
            if (l.IsConverted || l.Status == 'Closed - Converted' || l.Status == 'Closed - Not Converted') {
                continue;
            }
            qualifyingLeads.add(l);
            if (l.Project__c != null) {
                projectIds.add(l.Project__c);
            }
        }

        if (qualifyingLeads.isEmpty()) {
            return;
        }

        // Step 2: Fetch Projects, Metadata Configurations, and Active Standard Users
        Map<Id, Project__c> projectMap = LeadAssignmentSelector.getProjectsByIds(projectIds);
        List<Round_Robin_Config__mdt> configs = LeadAssignmentSelector.getRoundRobinConfigs();
        List<User> activeUsers = LeadAssignmentSelector.getActiveStandardUsers();

        if (configs.isEmpty() || activeUsers.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'LeadRoundRobinService: No active configs or active users found.');
            return;
        }

        // Step 3: Map candidate users for each Config rule
        Map<String, List<User>> teamCandidatesMap = buildTeamCandidateMap(configs, activeUsers);

        // Step 4: Identify all teams involved in this batch and load persistent states FOR UPDATE
        Set<String> neededTeams = new Set<String>();
        for (Round_Robin_Config__mdt config : configs) {
            if (String.isNotBlank(config.Team_Name__c)) {
                neededTeams.add(config.Team_Name__c);
            }
        }

        RoundRobinStateService stateService = new RoundRobinStateService();
        stateService.loadStates(neededTeams);

        // Step 5: Process each qualifying Lead
        for (Lead leadRecord : qualifyingLeads) {
            String resolvedLocation = resolveLeadLocation(leadRecord, projectMap);
            String projectName = (leadRecord.Project__c != null && projectMap.containsKey(leadRecord.Project__c)) 
                ? projectMap.get(leadRecord.Project__c).Name 
                : 'Direct / Unspecified';

            Round_Robin_Config__mdt matchedConfig = matchConfigForLocation(resolvedLocation, configs);
            if (matchedConfig == null) {
                System.debug(LoggingLevel.WARN, 'LeadRoundRobinService: No matching config for location: ' + resolvedLocation);
                continue;
            }

            String teamName = matchedConfig.Team_Name__c;
            List<User> candidates = teamCandidatesMap.get(teamName);

            if (candidates != null && !candidates.isEmpty()) {
                User nextUser = stateService.getNextUser(teamName, candidates);
                if (nextUser != null) {
                    leadRecord.OwnerId = nextUser.Id;

                    // Stash assignment info for after insert history tracking
                    LeadAssignmentInfo info = new LeadAssignmentInfo();
                    info.assignedOwnerId = nextUser.Id;
                    info.teamName = teamName;
                    info.location = resolvedLocation;
                    info.projectName = projectName;
                    
                    // We will match in after insert by index or Lead instance
                }
            } else {
                System.debug(LoggingLevel.WARN, 'LeadRoundRobinService: No eligible active users for team: ' + teamName);
            }
        }

        // Step 6: Persist updated Round Robin states
        stateService.persistStates();
    }

    /**
     * @description Creates audit records in Lead_Assignment_History__c after Lead insertion.
     * @param insertedLeads List of inserted Leads from Trigger.new in after insert
     */
    public static void createAssignmentHistories(List<Lead> insertedLeads) {
        if (insertedLeads == null || insertedLeads.isEmpty()) {
            return;
        }

        List<Lead_Assignment_History__c> historyRecords = new List<Lead_Assignment_History__c>();

        for (Lead l : insertedLeads) {
            if (l.OwnerId != null && String.valueOf(l.OwnerId).startsWith('005')) {
                Lead_Assignment_History__c hist = new Lead_Assignment_History__c(
                    Lead__c = l.Id,
                    New_Owner__c = l.OwnerId,
                    Assignment_Date__c = Date.today(),
                    Reason__c = 'Auto Assignment',
                    Remarks__c = 'Round Robin assigned to user: ' + l.OwnerId + ' for Lead: ' + l.LastName
                );
                historyRecords.add(hist);
            }
        }

        if (!historyRecords.isEmpty()) {
            Database.insert(historyRecords, false);
        }
    }

    /**
     * @description Resolves Lead location from Project City -> Preferred Location -> Lead City -> DEFAULT.
     */
    public static String resolveLeadLocation(Lead l, Map<Id, Project__c> projectMap) {
        if (l.Project__c != null && projectMap.containsKey(l.Project__c)) {
            Project__c p = projectMap.get(l.Project__c);
            if (String.isNotBlank(p.City__c)) {
                return p.City__c.trim();
            }
        }

        if (String.isNotBlank(l.Preferred_Location__c)) {
            return extractCityFromText(l.Preferred_Location__c);
        }

        if (String.isNotBlank(l.City)) {
            return l.City.trim();
        }

        return 'DEFAULT';
    }

    /**
     * @description Helper to extract standard city token (e.g. "Whitefield, Bengaluru" -> "Bengaluru").
     */
    private static String extractCityFromText(String loc) {
        if (String.isBlank(loc)) return 'DEFAULT';
        String lower = loc.toLowerCase();
        if (lower.contains('bengaluru') || lower.contains('bangalore')) return 'Bengaluru';
        if (lower.contains('hyderabad')) return 'Hyderabad';
        if (lower.contains('pune')) return 'Pune';
        if (lower.contains('chennai')) return 'Chennai';
        return loc.trim();
    }

    /**
     * @description Matches the highest priority active configuration rule for a location.
     */
    private static Round_Robin_Config__mdt matchConfigForLocation(String location, List<Round_Robin_Config__mdt> configs) {
        Round_Robin_Config__mdt defaultConfig = null;

        for (Round_Robin_Config__mdt config : configs) {
            if (String.isBlank(config.Location__c)) {
                continue;
            }

            if (config.Location__c.equalsIgnoreCase(location)) {
                return config;
            }

            if (config.Location__c.equalsIgnoreCase('DEFAULT') && defaultConfig == null) {
                defaultConfig = config;
            }
        }

        return (defaultConfig != null) ? defaultConfig : (configs.isEmpty() ? null : configs[0]);
    }

    /**
     * @description Builds a map of Team Name to filtered, deterministically sorted eligible active Users.
     */
    private static Map<String, List<User>> buildTeamCandidateMap(List<Round_Robin_Config__mdt> configs, List<User> activeUsers) {
        Map<String, List<User>> teamCandidates = new Map<String, List<User>>();

        for (Round_Robin_Config__mdt config : configs) {
            String teamName = config.Team_Name__c;
            if (String.isBlank(teamName)) {
                continue;
            }

            Set<String> allowedRoles = parseCommaSeparatedSet(config.Role_Developer_Names__c);
            Set<String> allowedProfiles = parseCommaSeparatedSet(config.Profile_Names__c);
            String requiredCity = (String.isNotBlank(config.User_City__c)) ? config.User_City__c.trim().toUpperCase() : null;
            String requiredDept = (String.isNotBlank(config.User_Department__c)) ? config.User_Department__c.trim().toUpperCase() : null;

            List<User> matchedUsers = new List<User>();

            for (User u : activeUsers) {
                // Must be active and standard user type
                if (!u.IsActive || u.UserType != 'Standard') {
                    continue;
                }

                // Check Role DeveloperName filter if configured
                if (!allowedRoles.isEmpty()) {
                    String userRoleDev = (u.UserRoleId != null && u.UserRole != null) ? u.UserRole.DeveloperName : '';
                    String userRoleName = (u.UserRoleId != null && u.UserRole != null) ? u.UserRole.Name : '';
                    if (!allowedRoles.contains(userRoleDev.toUpperCase()) && !allowedRoles.contains(userRoleName.toUpperCase())) {
                        continue;
                    }
                }

                // Check Profile filter if configured
                if (!allowedProfiles.isEmpty()) {
                    String userProfile = (u.ProfileId != null && u.Profile != null) ? u.Profile.Name : '';
                    if (!allowedProfiles.contains(userProfile.toUpperCase())) {
                        continue;
                    }
                }

                // Check City filter if configured
                if (requiredCity != null) {
                    String userCity = (String.isNotBlank(u.City)) ? u.City.trim().toUpperCase() : '';
                    if (userCity != requiredCity) {
                        continue;
                    }
                }

                // Check Department filter if configured
                if (requiredDept != null) {
                    String userDept = (String.isNotBlank(u.Department)) ? u.Department.trim().toUpperCase() : '';
                    if (userDept != requiredDept) {
                        continue;
                    }
                }

                matchedUsers.add(u);
            }

            // Fallback: If no users matched with strict city filter, allow users matching role and profile
            if (matchedUsers.isEmpty() && requiredCity != null) {
                for (User u : activeUsers) {
                    if (!u.IsActive || u.UserType != 'Standard') continue;
                    if (!allowedRoles.isEmpty()) {
                        String userRoleDev = (u.UserRoleId != null && u.UserRole != null) ? u.UserRole.DeveloperName : '';
                        String userRoleName = (u.UserRoleId != null && u.UserRole != null) ? u.UserRole.Name : '';
                        if (!allowedRoles.contains(userRoleDev.toUpperCase()) && !allowedRoles.contains(userRoleName.toUpperCase())) {
                            continue;
                        }
                    }
                    if (!allowedProfiles.isEmpty()) {
                        String userProfile = (u.ProfileId != null && u.Profile != null) ? u.Profile.Name : '';
                        if (!allowedProfiles.contains(userProfile.toUpperCase())) {
                            continue;
                        }
                    }
                    matchedUsers.add(u);
                }
            }

            teamCandidates.put(teamName, matchedUsers);
        }

        return teamCandidates;
    }

    private static Set<String> parseCommaSeparatedSet(String commaSeparatedStr) {
        Set<String> resultSet = new Set<String>();
        if (String.isBlank(commaSeparatedStr)) {
            return resultSet;
        }

        for (String item : commaSeparatedStr.split(',')) {
            if (String.isNotBlank(item)) {
                resultSet.add(item.trim().toUpperCase());
            }
        }
        return resultSet;
    }
}
