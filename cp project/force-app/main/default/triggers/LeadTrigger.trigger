/**
 * @description Master Trigger on Lead for Real Estate Pre-Sales CRM.
 * Executes Round Robin auto-assignment and assignment history logging.
 * Fingertipplus Technologies - Real Estate Pre-Sales CRM
 */
trigger LeadTrigger on Lead (before insert, before update, after insert, after update) {

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            LeadTriggerHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            for (Lead ld : Trigger.new) {
                Lead oldLd = Trigger.oldMap.get(ld.Id);
                if (ld.IsConverted && !oldLd.IsConverted && ld.ConvertedAccountId != null) {
                    LeadConversionContext.convertedLeadsByAccountId.put(ld.ConvertedAccountId, ld);
                }
            }
        }
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        LeadTriggerHandler.handleAfterInsert(Trigger.new);
    }
}
