/**
 * @description Handler to automatically populate Booking__c fields from related records
 * (Lead, Opportunity, Unit, Quotation) on before insert and before update events.
 */
public without sharing class BookingAutoPopulateHandler {

    public static void handleBeforeInsert(List<Booking__c> newBookings) {
        populateFields(newBookings, null);
    }

    public static void handleBeforeUpdate(List<Booking__c> newBookings, Map<Id, Booking__c> oldMap) {
        populateFields(newBookings, oldMap);
    }

    private static void populateFields(List<Booking__c> bookings, Map<Id, Booking__c> oldMap) {
        Set<Id> oppIds = new Set<Id>();
        Set<Id> leadIds = new Set<Id>();
        Set<Id> unitIds = new Set<Id>();

        for (Booking__c bk : bookings) {
            Booking__c old = oldMap != null ? oldMap.get(bk.Id) : null;
            
            if (bk.Opportunity__c != null && (old == null || bk.Opportunity__c != old.Opportunity__c)) {
                oppIds.add(bk.Opportunity__c);
            }
            if (bk.Lead__c != null && (old == null || bk.Lead__c != old.Lead__c)) {
                leadIds.add(bk.Lead__c);
            }
        }

        // 1. Fetch Opportunity data
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        Map<Id, String> oppEmailMap = new Map<Id, String>();
        Map<Id, String> oppPhoneMap = new Map<Id, String>();
        Map<Id, Quotation__c> oppQuoteMap = new Map<Id, Quotation__c>();
        
        if (!oppIds.isEmpty()) {
            oppMap = new Map<Id, Opportunity>([
                SELECT Id, AccountId, Account.Name, Account.Phone, OwnerId, Project__c, Tower__c, Unit__c, Booking_Amount__c, Discount__c,
                       Lead_Registration__r.Customer_Name__c, Lead_Registration__r.Customer_Email__c, Lead_Registration__r.Customer_Phone__c
                FROM Opportunity
                WHERE Id IN :oppIds
            ]);
            
            Set<Id> accIds = new Set<Id>();
            for (Opportunity opp : oppMap.values()) {
                if (opp.AccountId != null) accIds.add(opp.AccountId);
            }
            
            Map<Id, Contact> contactMap = new Map<Id, Contact>();
            if (!accIds.isEmpty()) {
                List<Contact> contacts = [
                    SELECT AccountId, Email, Phone, MobilePhone 
                    FROM Contact 
                    WHERE AccountId IN :accIds
                    ORDER BY LastModifiedDate DESC
                ];
                for (Contact c : contacts) {
                    if (!contactMap.containsKey(c.AccountId)) {
                        contactMap.put(c.AccountId, c);
                    }
                }
            }

            for (Opportunity opp : oppMap.values()) {
                String email = null;
                String phone = null;
                
                if (opp.Lead_Registration__r != null) {
                    email = opp.Lead_Registration__r.Customer_Email__c;
                    phone = opp.Lead_Registration__r.Customer_Phone__c;
                }
                
                if (String.isBlank(email) && opp.AccountId != null && contactMap.containsKey(opp.AccountId)) {
                    email = contactMap.get(opp.AccountId).Email;
                }
                if (String.isBlank(phone) && opp.AccountId != null) {
                    phone = opp.Account.Phone;
                    if (String.isBlank(phone) && contactMap.containsKey(opp.AccountId)) {
                        Contact c = contactMap.get(opp.AccountId);
                        phone = String.isNotBlank(c.Phone) ? c.Phone : c.MobilePhone;
                    }
                }
                
                if (String.isNotBlank(email)) oppEmailMap.put(opp.Id, email);
                if (String.isNotBlank(phone)) oppPhoneMap.put(opp.Id, phone);
            }

            List<Quotation__c> quotes = [
                SELECT Opportunity__c, Taxes__c
                FROM Quotation__c
                WHERE Opportunity__c IN :oppIds AND Status__c = 'Accepted'
            ];
            for (Quotation__c q : quotes) {
                oppQuoteMap.put(q.Opportunity__c, q);
            }
        }

        // 2. Fetch Lead data
        Map<Id, Lead> leadMap = new Map<Id, Lead>();
        if (!leadIds.isEmpty()) {
            leadMap = new Map<Id, Lead>([
                SELECT Id, Name, Email, Phone, MobilePhone, LeadSource, OwnerId, Project__c, Tower__c, Budget__c
                FROM Lead
                WHERE Id IN :leadIds
            ]);
        }

        // Gather Unit IDs from bookings, plus their related opportunities and leads
        for (Booking__c bk : bookings) {
            Booking__c old = oldMap != null ? oldMap.get(bk.Id) : null;
            if (bk.Unit__c != null) {
                unitIds.add(bk.Unit__c);
            }
            if (bk.Opportunity__c != null && (old == null || bk.Opportunity__c != old.Opportunity__c)) {
                Opportunity opp = oppMap.get(bk.Opportunity__c);
                if (opp != null && opp.Unit__c != null) {
                    unitIds.add(opp.Unit__c);
                }
            }
            if (bk.Lead__c != null && (old == null || bk.Lead__c != old.Lead__c)) {
                Lead ld = leadMap.get(bk.Lead__c);
                if (ld != null && ld.Unit__c != null) {
                    unitIds.add(ld.Unit__c);
                }
            }
        }

        // 3. Fetch Unit data
        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>();
        if (!unitIds.isEmpty()) {
            unitMap = new Map<Id, Unit__c>([
                SELECT Id, Name, Floor__c, Tower__c, Facing__c, Area_Sq_Ft__c, Bedrooms__c, Unit_Type__c, Bathrooms__c, Balcony__c, Car_Parking__c, Price_per_Sq_Ft__c, Base_Price__c, Parking_Charges__c, Other_Charges__c, Price__c
                FROM Unit__c
                WHERE Id IN :unitIds
            ]);
        }

        // 4. Populate Booking fields
        for (Booking__c bk : bookings) {
            Booking__c old = oldMap != null ? oldMap.get(bk.Id) : null;

            // --- Opportunity Population ---
            if (bk.Opportunity__c != null && (old == null || bk.Opportunity__c != old.Opportunity__c)) {
                Opportunity opp = oppMap.get(bk.Opportunity__c);
                if (opp != null) {
                    if (bk.Project__c == null) bk.Project__c = opp.Project__c;
                    if (bk.Tower__c == null) bk.Tower__c = opp.Tower__c;
                    if (bk.Unit__c == null) bk.Unit__c = opp.Unit__c;
                    if (bk.Booking_Amount__c == null || bk.Booking_Amount__c == 0) bk.Booking_Amount__c = opp.Booking_Amount__c;

                    Boolean forceUpdate = (old != null && bk.Opportunity__c != old.Opportunity__c);
                    if (bk.Customer_Name__c == null || forceUpdate) {
                        bk.Customer_Name__c = (opp.Lead_Registration__r != null && String.isNotBlank(opp.Lead_Registration__r.Customer_Name__c)) ? 
                                              opp.Lead_Registration__r.Customer_Name__c : 
                                              (opp.Account != null ? opp.Account.Name : null);
                    }
                    if (bk.Customer_Phone__c == null || forceUpdate) {
                        bk.Customer_Phone__c = oppPhoneMap.get(opp.Id);
                    }
                    if (bk.Customer_Email__c == null || forceUpdate) {
                        bk.Customer_Email__c = oppEmailMap.get(opp.Id);
                    }

                    if (bk.Taxes__c == null || forceUpdate) {
                        Quotation__c q = oppQuoteMap.get(opp.Id);
                        if (q != null) bk.Taxes__c = q.Taxes__c;
                    }

                    if (bk.Discount_Amount__c == null || forceUpdate) {
                        bk.Discount_Amount__c = opp.Discount__c != null ? opp.Discount__c : 0.00;
                    }

                    if (bk.CRM_Executive__c == null) bk.CRM_Executive__c = opp.OwnerId;
                    if (bk.Booking_Owner__c == null) bk.Booking_Owner__c = opp.OwnerId;
                    if (bk.OwnerId == null || bk.OwnerId == UserInfo.getUserId()) bk.OwnerId = opp.OwnerId;
                }
            }

            // --- Lead Population ---
            if (bk.Lead__c != null && (old == null || bk.Lead__c != old.Lead__c)) {
                Lead ld = leadMap.get(bk.Lead__c);
                if (ld != null) {
                    if (bk.Project__c == null) bk.Project__c = ld.Project__c;
                    if (bk.Tower__c == null) bk.Tower__c = ld.Tower__c;
                    if (bk.Booking_Amount__c == null || bk.Booking_Amount__c == 0) bk.Booking_Amount__c = ld.Budget__c;

                    Boolean forceUpdate = (old != null && bk.Lead__c != old.Lead__c);
                    if (bk.Customer_Name__c == null || forceUpdate) {
                        bk.Customer_Name__c = ld.Name;
                    }
                    if (bk.Customer_Phone__c == null || forceUpdate) {
                        bk.Customer_Phone__c = String.isNotBlank(ld.Phone) ? ld.Phone : ld.MobilePhone;
                    }
                    if (bk.Customer_Email__c == null || forceUpdate) {
                        bk.Customer_Email__c = ld.Email;
                    }

                    if (bk.CRM_Executive__c == null) bk.CRM_Executive__c = ld.OwnerId;
                    if (bk.Booking_Owner__c == null) bk.Booking_Owner__c = ld.OwnerId;
                    if (bk.OwnerId == null || bk.OwnerId == UserInfo.getUserId()) bk.OwnerId = ld.OwnerId;
                }
            }

            // --- Unit Population ---
            if (bk.Unit__c != null) {
                Boolean forceUpdateUnit = (old == null || bk.Unit__c != old.Unit__c);
                
                Unit__c u = unitMap.get(bk.Unit__c);
                if (u != null) {
                    if (bk.Project__c == null) bk.Project__c = u.Project__c;
                    if (bk.Tower__c == null) bk.Tower__c = u.Tower__c;

                    if (bk.Unit_Number__c == null || forceUpdateUnit) bk.Unit_Number__c = u.Name;
                    if (bk.Floor__c == null || forceUpdateUnit) bk.Floor__c = u.Floor__c != null ? String.valueOf(u.Floor__c.intValue()) : null;
                    if (bk.Facing__c == null || forceUpdateUnit) bk.Facing__c = u.Facing__c;
                    if (bk.Area_Sq_Ft__c == null || forceUpdateUnit) bk.Area_Sq_Ft__c = u.Area_Sq_Ft__c;
                    if (bk.Bedrooms__c == null || forceUpdateUnit) bk.Bedrooms__c = u.Bedrooms__c;
                    if (bk.Unit_Type__c == null || forceUpdateUnit) bk.Unit_Type__c = u.Unit_Type__c;
                    if (bk.Bathrooms__c == null || forceUpdateUnit) bk.Bathrooms__c = u.Bathrooms__c;
                    if (bk.Balcony__c == null || forceUpdateUnit) bk.Balcony__c = u.Balcony__c;
                    
                    if (bk.Parking__c == null || forceUpdateUnit) {
                        bk.Parking__c = u.Car_Parking__c ? 'Yes' : 'No';
                    }
                    if (bk.Price_per_Sq_Ft__c == null || forceUpdateUnit) bk.Price_per_Sq_Ft__c = u.Price_per_Sq_Ft__c;
                    if (bk.Base_Price__c == null || forceUpdateUnit) bk.Base_Price__c = u.Base_Price__c;
                    if (bk.Parking_Charges__c == null || forceUpdateUnit) bk.Parking_Charges__c = u.Parking_Charges__c;
                    if (bk.Other_Charges__c == null || forceUpdateUnit) bk.Other_Charges__c = u.Other_Charges__c;
                    
                    if (bk.Unit_Price__c == null || forceUpdateUnit) bk.Unit_Price__c = u.Price__c;
                    if (bk.Agreement_Value__c == null || forceUpdateUnit) bk.Agreement_Value__c = u.Price__c;
                    if (bk.Final_Property_Value__c == null || forceUpdateUnit) bk.Final_Property_Value__c = u.Price__c;
                    if (bk.Total_Property_Plot_Amount__c == null || forceUpdateUnit) bk.Total_Property_Plot_Amount__c = u.Price__c;

                    Boolean isInsert = (old == null);
                    if (bk.Pending_Dues__c == null || (isInsert && bk.Pending_Dues__c == 0) || (forceUpdateUnit && old != null && old.Unit__c != bk.Unit__c)) {
                        bk.Pending_Dues__c = u.Price__c;
                    }
                    if (bk.Outstanding_Amount__c == null || (isInsert && bk.Outstanding_Amount__c == 0) || (forceUpdateUnit && old != null && old.Unit__c != bk.Unit__c)) {
                        bk.Outstanding_Amount__c = u.Price__c;
                    }
                }
            }

            if (bk.Booking_Date__c == null) bk.Booking_Date__c = Date.today();
            if (bk.Booking_Status__c == null) bk.Booking_Status__c = 'Pending';
            if (bk.Payment_Status__c == null) bk.Payment_Status__c = 'Pending';
        }
    }
}
