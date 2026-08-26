/**
 * @description Trigger to automatically synchronize Date changes from Lead Registration to active Opportunities.
 */
trigger LeadRegistrationTrigger on Lead_Registration__c (after update) {
    Set<Id> regIds = new Set<Id>();
    for (Lead_Registration__c reg : Trigger.new) {
        Lead_Registration__c old = Trigger.oldMap.get(reg.Id);
        if (reg.Expected_Purchase_Date__c != old.Expected_Purchase_Date__c) {
            regIds.add(reg.Id);
        }
    }
    
    if (!regIds.isEmpty()) {
        List<Opportunity> opps = [
            SELECT Id, Expected_Registration_Date__c, Lead_Registration__c
            FROM Opportunity
            WHERE Lead_Registration__c IN :regIds AND StageName != 'Closed Won' AND StageName != 'Closed Lost'
        ];
        
        if (!opps.isEmpty()) {
            List<Opportunity> oppsToUpdate = new List<Opportunity>();
            for (Opportunity opp : opps) {
                Lead_Registration__c reg = Trigger.newMap.get(opp.Lead_Registration__c);
                if (opp.Expected_Registration_Date__c != reg.Expected_Purchase_Date__c) {
                    opp.Expected_Registration_Date__c = reg.Expected_Purchase_Date__c;
                    oppsToUpdate.add(opp);
                }
            }
            if (!oppsToUpdate.isEmpty()) {
                update oppsToUpdate;
            }
        }
    }
}
