public without sharing class CpPortalNotificationService {
    private static Id notificationTypeId;

    private static Id getNotificationTypeId() {
        if (notificationTypeId == null) {
            List<CustomNotificationType> types = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = 'CP_Portal_Notification'
                LIMIT 1
            ];
            if (!types.isEmpty()) {
                notificationTypeId = types[0].Id;
            }
        }
        return notificationTypeId;
    }

    public static void sendNotification(String title, String body, Id targetId, Set<String> recipientIds) {
        if (recipientIds == null || recipientIds.isEmpty()) return;
        Id typeId = getNotificationTypeId();
        if (typeId == null) return;

        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(title);
            notification.setBody(body);
            notification.setNotificationTypeId(typeId);
            if (targetId != null) {
                notification.setTargetId(targetId);
            }
            notification.send(recipientIds);
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'Notification send failed: ' + ex.getMessage());
        }
    }

    public static void notifyNewCpLeads(List<Lead> leads) {
        for (Lead l : leads) {
            if (l.LeadSource == 'Channel Partner' && l.OwnerId != null && String.valueOf(l.OwnerId).startsWith('005')) {
                String title = 'New CP Lead Assigned';
                String body = 'A new lead from Channel Partner (' + (l.CP_Company__c != null ? l.CP_Company__c : 'CP') + ') has been assigned to you: ' + (l.FirstName != null ? l.FirstName + ' ' : '') + l.LastName;
                sendNotification(title, body, l.Id, new Set<String>{ String.valueOf(l.OwnerId) });
            }
        }
    }

    public static void notifyDuplicateLeads(List<Lead> leads) {
        for (Lead l : leads) {
            if (l.LeadSource == 'Channel Partner' && l.Potential_Duplicate__c == true && l.OwnerId != null && String.valueOf(l.OwnerId).startsWith('005')) {
                String title = 'Potential Duplicate CP Lead';
                String body = 'A potential duplicate lead was detected (' + l.Duplicate_Reason__c + '): ' + (l.FirstName != null ? l.FirstName + ' ' : '') + l.LastName;
                sendNotification(title, body, l.Id, new Set<String>{ String.valueOf(l.OwnerId) });
            }
        }
    }

    public static void notifySiteVisit(List<Site_Visit__c> visits) {
        for (Site_Visit__c v : visits) {
            Id recipient = v.Sales_Executive__c;
            if (recipient == null && v.OwnerId != null && String.valueOf(v.OwnerId).startsWith('005')) {
                recipient = v.OwnerId;
            }
            if (recipient != null) {
                String title = 'New Site Visit Scheduled';
                String body = 'A new site visit has been created/assigned for customer: ' + (v.Customer_Name__c != null ? v.Customer_Name__c : 'Customer');
                sendNotification(title, body, v.Id, new Set<String>{ String.valueOf(recipient) });
            }
        }
    }

    public static void notifyFollowUp(List<Follow_Up__c> followUps) {
        for (Follow_Up__c f : followUps) {
            Id recipient = f.Sales_Executive__c;
            if (recipient == null && f.OwnerId != null && String.valueOf(f.OwnerId).startsWith('005')) {
                recipient = f.OwnerId;
            }
            if (recipient != null) {
                String title = 'New Follow-Up Scheduled';
                String body = 'A new follow-up (' + f.Follow_Up_Type__c + ') has been created for customer: ' + (f.Customer_Name__c != null ? f.Customer_Name__c : 'Customer');
                sendNotification(title, body, f.Id, new Set<String>{ String.valueOf(recipient) });
            }
        }
    }

    public static void notifySyncFailure(String objectName, String recordId, String errorMessage, Id recipientId) {
        if (recipientId != null) {
            String title = 'Salesforce Sync Failure (' + objectName + ')';
            String body = 'Sync failed for ' + objectName + ' ' + recordId + ': ' + errorMessage;
            sendNotification(title, body, recordId, new Set<String>{ String.valueOf(recipientId) });
        }
    }
}
