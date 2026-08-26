/**
 * @description Stores Lead Conversion transaction context to pass converted Lead data to Opportunity trigger.
 */
public without sharing class LeadConversionContext {
    // Maps Converted Account Id -> Converted Lead record
    public static Map<Id, Lead> convertedLeadsByAccountId = new Map<Id, Lead>();
}
