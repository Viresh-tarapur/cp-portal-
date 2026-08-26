/**
 * @description Nightly Batch Job to automatically expire elapsed Project Access records.
 */
public with sharing class ProjectAccessExpiryBatch implements Database.Batchable<sObject>, Database.Stateful {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();
        return Database.getQueryLocator([
            SELECT Id, Partner__c, Project__c, Access_Status__c, End_Date__c 
            FROM Project_Access__c 
            WHERE Access_Status__c = 'Active' 
              AND End_Date__c < :today
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Project_Access__c> scope) {
        for (Project_Access__c pa : scope) {
            pa.Access_Status__c = 'Expired';
        }
        update scope;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('ProjectAccessExpiryBatch completed successfully.');
    }
}
