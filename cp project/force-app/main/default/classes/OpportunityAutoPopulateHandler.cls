/**
 * @description Handler to automatically populate Opportunity fields from converted Lead,
 * selected Project, and selected Unit, and compute standard Amount from Unit pricing.
 * Synchronizes Unit__c and Inventory_Unit__c lookups bidirectionally based on matching name/tower.
 */
public without sharing class OpportunityAutoPopulateHandler {

    public static void handleBeforeInsert(List<Opportunity> newOpps) {
        populateFields(newOpps, null);
    }

    public static void handleBeforeUpdate(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        populateFields(newOpps, oldMap);
    }

    private static void populateFields(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {
        Set<Id> leadRegIds = new Set<Id>();

        // 1. Gather Lead Registration IDs from Opps
        for (Opportunity opp : opps) {
            Opportunity old = oldMap != null ? oldMap.get(opp.Id) : null;
            if (opp.Lead_Registration__c != null && (old == null || opp.Lead_Registration__c != old.Lead_Registration__c)) {
                leadRegIds.add(opp.Lead_Registration__c);
            }
        }

        // 2. Map fields from Converted Lead (if converted in this transaction)
        for (Opportunity opp : opps) {
            if (opp.AccountId != null && LeadConversionContext.convertedLeadsByAccountId.containsKey(opp.AccountId)) {
                Lead convertedLead = LeadConversionContext.convertedLeadsByAccountId.get(opp.AccountId);
                
                if (opp.LeadSource == null) opp.LeadSource = convertedLead.LeadSource;
                if (opp.OwnerId == null || opp.OwnerId == UserInfo.getUserId()) {
                    if (convertedLead.OwnerId != null) {
                        opp.OwnerId = convertedLead.OwnerId;
                    }
                }
                if (opp.Project__c == null) opp.Project__c = convertedLead.Project__c;
                if (opp.Tower__c == null) opp.Tower__c = convertedLead.Tower__c;
                if (opp.Unit__c == null) {
                }
                if (opp.Lead_Registration__c == null) {
                    opp.Lead_Registration__c = convertedLead.Lead_Registration__c;
                    if (convertedLead.Lead_Registration__c != null) {
                        leadRegIds.add(convertedLead.Lead_Registration__c);
                    }
                }

                if (opp.Description == null) opp.Description = convertedLead.Description;
            }
        }

        // 3. Fetch and map from Lead Registration
        Map<Id, Lead_Registration__c> leadRegMap = new Map<Id, Lead_Registration__c>();
        if (!leadRegIds.isEmpty()) {
            leadRegMap = new Map<Id, Lead_Registration__c>([
                SELECT Id, Expected_Purchase_Date__c, Project__c, Inventory_Unit__c, Partner__c
                FROM Lead_Registration__c
                WHERE Id IN :leadRegIds
            ]);
        }

        for (Opportunity opp : opps) {
            if (opp.Lead_Registration__c != null) {
                Lead_Registration__c reg = leadRegMap.get(opp.Lead_Registration__c);
                if (reg != null) {
                    if (opp.Project__c == null) opp.Project__c = reg.Project__c;
                    if (opp.Inventory_Unit__c == null && reg.Inventory_Unit__c != null) {
                        opp.Inventory_Unit__c = reg.Inventory_Unit__c;
                    }
                    if (opp.Partner__c == null) opp.Partner__c = reg.Partner__c;
                    if (opp.Expected_Registration_Date__c == null && reg.Expected_Purchase_Date__c != null) {
                        opp.Expected_Registration_Date__c = reg.Expected_Purchase_Date__c;
                    }
                }
            }
        }

        // 4. Synchronize Unit__c and Inventory_Unit__c lookups bidirectionally (only if inserted or changed)
        Set<Id> unitIdsForSync = new Set<Id>();
        Set<Id> invUnitIdsForSync = new Set<Id>();

        for (Opportunity opp : opps) {
            Opportunity old = oldMap != null ? oldMap.get(opp.Id) : null;
            
            Boolean isInsert = (old == null);
            Boolean unitChanged = (old != null && opp.Unit__c != old.Unit__c);
            Boolean invUnitChanged = (old != null && opp.Inventory_Unit__c != old.Inventory_Unit__c);
            
            if (isInsert || unitChanged || invUnitChanged) {
                if (opp.Unit__c != null && opp.Inventory_Unit__c == null) {
                    unitIdsForSync.add(opp.Unit__c);
                } else if (opp.Inventory_Unit__c != null && opp.Unit__c == null) {
                    invUnitIdsForSync.add(opp.Inventory_Unit__c);
                } else if (opp.Unit__c != null && opp.Inventory_Unit__c != null && !isInsert) {
                    if (unitChanged) {
                        unitIdsForSync.add(opp.Unit__c);
                    } else if (invUnitChanged) {
                        invUnitIdsForSync.add(opp.Inventory_Unit__c);
                    }
                }
            }
        }

        Map<Id, Unit__c> unitsForSync = new Map<Id, Unit__c>();
        if (!unitIdsForSync.isEmpty()) {
            unitsForSync = new Map<Id, Unit__c>([
                SELECT Id, Name, Tower__c FROM Unit__c WHERE Id IN :unitIdsForSync
            ]);
        }

        Map<Id, Inventory_Unit__c> invUnitsForSync = new Map<Id, Inventory_Unit__c>();
        if (!invUnitIdsForSync.isEmpty()) {
            invUnitsForSync = new Map<Id, Inventory_Unit__c>([
                SELECT Id, Unit_Number__c, Tower__c FROM Inventory_Unit__c WHERE Id IN :invUnitIdsForSync
            ]);
        }

        Map<String, Id> keyToInvUnitId = new Map<String, Id>();
        if (!unitsForSync.isEmpty()) {
            Set<String> unitNames = new Set<String>();
            Set<Id> towerIds = new Set<Id>();
            for (Unit__c u : unitsForSync.values()) {
                unitNames.add(u.Name);
                if (u.Tower__c != null) towerIds.add(u.Tower__c);
            }
            List<Inventory_Unit__c> invList = [
                SELECT Id, Unit_Number__c, Tower__c FROM Inventory_Unit__c 
                WHERE Unit_Number__c IN :unitNames AND Tower__c IN :towerIds
            ];
            for (Inventory_Unit__c iu : invList) {
                keyToInvUnitId.put(iu.Unit_Number__c + '_' + iu.Tower__c, iu.Id);
            }
        }

        Map<String, Id> keyToUnitId = new Map<String, Id>();
        if (!invUnitsForSync.isEmpty()) {
            Set<String> unitNames = new Set<String>();
            Set<Id> towerIds = new Set<Id>();
            for (Inventory_Unit__c iu : invUnitsForSync.values()) {
                unitNames.add(iu.Unit_Number__c);
                if (iu.Tower__c != null) towerIds.add(iu.Tower__c);
            }
            List<Unit__c> uList = [
                SELECT Id, Name, Tower__c FROM Unit__c 
                WHERE Name IN :unitNames AND Tower__c IN :towerIds
            ];
            for (Unit__c u : uList) {
                keyToUnitId.put(u.Name + '_' + u.Tower__c, u.Id);
            }
        }

        for (Opportunity opp : opps) {
            Opportunity old = oldMap != null ? oldMap.get(opp.Id) : null;
            Boolean isInsert = (old == null);
            Boolean unitChanged = (old != null && opp.Unit__c != old.Unit__c);

            if (opp.Unit__c != null && (isInsert || unitChanged)) {
                Unit__c u = unitsForSync.get(opp.Unit__c);
                if (u != null) {
                    String key = u.Name + '_' + u.Tower__c;
                    if (keyToInvUnitId.containsKey(key)) {
                        opp.Inventory_Unit__c = keyToInvUnitId.get(key);
                    }
                }
            } else if (opp.Inventory_Unit__c != null && (isInsert || (old != null && opp.Inventory_Unit__c != old.Inventory_Unit__c))) {
                Inventory_Unit__c iu = invUnitsForSync.get(opp.Inventory_Unit__c);
                if (iu != null) {
                    String key = iu.Unit_Number__c + '_' + iu.Tower__c;
                    if (keyToUnitId.containsKey(key)) {
                        opp.Unit__c = keyToUnitId.get(key);
                    }
                }
            }
        }

        // 5. Gather Unit IDs for final property value calculation & project/tower population
        Set<Id> finalUnitIds = new Set<Id>();
        for (Opportunity opp : opps) {
            Opportunity old = oldMap != null ? oldMap.get(opp.Id) : null;
            
            Boolean needsRecalculation = (old == null) ? (opp.Amount == null || opp.Amount == 0) :
                                          (opp.Unit__c != old.Unit__c || 
                                           opp.Discount__c != old.Discount__c || 
                                           opp.Amount == null);
                                           
            if (opp.Unit__c != null && (needsRecalculation || opp.Project__c == null || opp.Tower__c == null)) {
                finalUnitIds.add(opp.Unit__c);
            }
        }

        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>();
        if (!finalUnitIds.isEmpty()) {
            unitMap = new Map<Id, Unit__c>([
                SELECT Id, Name, Project__c, Tower__c, Floor__c, Base_Price__c, Parking_Charges__c, Other_Charges__c, Price__c, Price_per_Sq_Ft__c, Area_Sq_Ft__c
                FROM Unit__c
                WHERE Id IN :finalUnitIds
            ]);
        }

        // 6. Final Sync of Project/Tower & Standard Amount calculation
        for (Opportunity opp : opps) {
            Opportunity old = oldMap != null ? oldMap.get(opp.Id) : null;
            
            Boolean needsRecalculation = (old == null) ? (opp.Amount == null || opp.Amount == 0) :
                                          (opp.Unit__c != old.Unit__c || 
                                           opp.Discount__c != old.Discount__c || 
                                           opp.Amount == null);
                                           
            if (opp.Unit__c != null) {
                Unit__c u = unitMap.get(opp.Unit__c);

                if (u != null) {
                    if (opp.Project__c == null) opp.Project__c = u.Project__c;
                    if (opp.Tower__c == null) opp.Tower__c = u.Tower__c;
                    
                    if (needsRecalculation) {
                        Decimal basePrice = (u.Base_Price__c != null && u.Base_Price__c > 0) ? u.Base_Price__c : 
                                           (u.Price__c != null ? u.Price__c : 8500000.00);
                        Decimal parking = (u.Parking_Charges__c != null) ? u.Parking_Charges__c : 300000.00;
                        Decimal other = (u.Other_Charges__c != null) ? u.Other_Charges__c : 200000.00;
                        Decimal subTotal = basePrice + parking + other;
                        
                        Decimal discount = 0.00;
                        if (opp.Discount__c != null && opp.Discount__c > 0) {
                            discount = (subTotal * (opp.Discount__c / 100.0)).setScale(2, System.RoundingMode.HALF_UP);
                        }
                        
                        Decimal taxableAmount = subTotal - discount;
                        Decimal taxes = (taxableAmount * 0.05).setScale(2, System.RoundingMode.HALF_UP);
                        Decimal finalValue = (taxableAmount + taxes).setScale(2, System.RoundingMode.HALF_UP);
                        
                        opp.Amount = finalValue;
                    }
                }
            }

            if (opp.CloseDate == null) {
                opp.CloseDate = Date.today().addDays(60);
            }
        }
    }
}
