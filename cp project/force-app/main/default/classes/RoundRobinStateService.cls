/**
 * @description State management and deterministic Round Robin computation engine.
 * Ensures thread safety, inactive user handling, wrap-around, and persistent state storage.
 * Fingertipplus Technologies - Real Estate Pre-Sales CRM
 */
public without sharing class RoundRobinStateService {

    private Map<String, Round_Robin_State__c> stateCache;
    private Set<String> modifiedTeams;

    public RoundRobinStateService() {
        this.stateCache = new Map<String, Round_Robin_State__c>();
        this.modifiedTeams = new Set<String>();
    }

    /**
     * @description Pre-loads Round Robin states with FOR UPDATE record locking.
     * @param teamNames Set of Team Names required for this transaction.
     */
    public void loadStates(Set<String> teamNames) {
        if (teamNames == null || teamNames.isEmpty()) {
            return;
        }

        Map<String, Round_Robin_State__c> existingStates = LeadAssignmentSelector.getRoundRobinStatesForUpdate(teamNames);

        for (String teamName : teamNames) {
            if (String.isBlank(teamName)) {
                continue;
            }
            String teamKey = teamName.toUpperCase();
            if (existingStates.containsKey(teamKey)) {
                this.stateCache.put(teamKey, existingStates.get(teamKey));
            } else {
                // Initialize in-memory state if first time for this team
                Round_Robin_State__c newState = new Round_Robin_State__c(
                    Team_Name__c = teamName,
                    Total_Assignments__c = 0
                );
                this.stateCache.put(teamKey, newState);
            }
        }
    }

    /**
     * @description Computes the next eligible user for a team using deterministic Round Robin.
     * Skips inactive users automatically and wraps around cleanly.
     * @param teamName The name of the team.
     * @param eligibleUsers Deterministically sorted list of active eligible users.
     * @return Selected User to receive the Lead.
     */
    public User getNextUser(String teamName, List<User> eligibleUsers) {
        if (String.isBlank(teamName) || eligibleUsers == null || eligibleUsers.isEmpty()) {
            return null;
        }

        String teamKey = teamName.toUpperCase();
        Round_Robin_State__c state = this.stateCache.get(teamKey);
        if (state == null) {
            state = new Round_Robin_State__c(
                Team_Name__c = teamName,
                Total_Assignments__c = 0
            );
            this.stateCache.put(teamKey, state);
        }

        Integer userCount = eligibleUsers.size();
        Integer nextIndex = 0;

        Id lastUserId = (state.Last_Assigned_User__c != null) 
            ? state.Last_Assigned_User__c 
            : (Id)state.Last_Assigned_User_Id__c;

        if (lastUserId != null) {
            Integer lastUserIndex = -1;
            for (Integer i = 0; i < userCount; i++) {
                if (eligibleUsers[i].Id == lastUserId) {
                    lastUserIndex = i;
                    break;
                }
            }

            if (lastUserIndex != -1) {
                // Last user is still active in the pool -> pick the next user
                nextIndex = Math.mod(lastUserIndex + 1, userCount);
            } else {
                // Last user is no longer in the active pool (deactivated/reassigned).
                // Maintain sequence by selecting the next user based on cumulative assignment count.
                Decimal totalAssigned = state.Total_Assignments__c != null ? state.Total_Assignments__c : 0;
                nextIndex = Math.mod(totalAssigned.intValue(), userCount);
            }
        } else {
            // First assignment for this team
            nextIndex = 0;
        }

        User selectedUser = eligibleUsers[nextIndex];

        // Update state in cache
        state.Last_Assigned_User__c = selectedUser.Id;
        state.Last_Assigned_User_Id__c = String.valueOf(selectedUser.Id);
        state.Last_Assignment_Date__c = System.now();
        state.Total_Assignments__c = (state.Total_Assignments__c != null ? state.Total_Assignments__c : 0) + 1;

        this.modifiedTeams.add(teamKey);

        System.debug(LoggingLevel.INFO, 'RoundRobinStateService: Team=' + teamName + 
            ' | User=' + selectedUser.Id + 
            ' | Index=' + nextIndex + '/' + userCount + 
            ' | Total=' + state.Total_Assignments__c);

        return selectedUser;
    }

    /**
     * @description Persists all modified Round Robin states to the database in bulk.
     */
    public void persistStates() {
        if (this.modifiedTeams.isEmpty()) {
            return;
        }

        List<Round_Robin_State__c> statesToPersist = new List<Round_Robin_State__c>();
        for (String teamKey : this.modifiedTeams) {
            Round_Robin_State__c state = this.stateCache.get(teamKey);
            if (state != null) {
                statesToPersist.add(state);
            }
        }

        if (!statesToPersist.isEmpty()) {
            upsert statesToPersist Team_Name__c;
        }
    }
}
