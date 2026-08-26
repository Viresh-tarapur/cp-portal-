trigger CpLeadRoundRobin on Lead (before insert, before update, after insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        CpLeadRoundRobin.assign(Trigger.new);
        CpLeadRoundRobin.checkDuplicates(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        CpLeadRoundRobin.checkDuplicates(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isInsert) {
        CpPortalNotificationService.notifyNewCpLeads(Trigger.new);
        CpPortalNotificationService.notifyDuplicateLeads(Trigger.new);
    }
}
