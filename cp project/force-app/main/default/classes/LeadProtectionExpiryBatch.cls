/**
 * @description Nightly Batch Job to automatically expire elapsed Lead Protection exclusivity periods.
 */
public with sharing class LeadProtectionExpiryBatch implements Database.Batchable<sObject>, Database.Stateful {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();
        return Database.getQueryLocator([
            SELECT Id, Partner__c, Lead__c, Ownership_Status__c, Protection_End_Date__c, Registration_Status__c 
            FROM Lead_Registration__c 
            WHERE Ownership_Status__c = 'Protected' 
              AND Protection_End_Date__c < :today
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Lead_Registration__c> scope) {
        for (Lead_Registration__c reg : scope) {
            reg.Ownership_Status__c = 'Expired';
            reg.Registration_Status__c = 'Expired';
        }
        update scope;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('LeadProtectionExpiryBatch completed successfully.');
    }
}
