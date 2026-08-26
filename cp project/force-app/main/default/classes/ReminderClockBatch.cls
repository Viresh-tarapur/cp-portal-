/**
 * Schedulable / Batchable service enforcing the 30-Day Reminder Clock.
 * Fingertipplus Technologies Pvt Ltd - Slide 16 & Golden Rule 4
 */
public with sharing class ReminderClockBatch {
    public enum ReminderAction {
        DEMAND_RAISED, // Day 0
        FIRST_REMINDER, // Day 7
        SECOND_REMINDER, // Day 14
        TERMINATION_NOTICE, // Day 21
        UNIT_RELEASED_AUTO_CANCEL // Day 30
    }

    public static ReminderAction evaluateReminderTrigger(Integer daysElapsed) {
        if (daysElapsed >= 30) {
            return ReminderAction.UNIT_RELEASED_AUTO_CANCEL;
        } else if (daysElapsed >= 21) {
            return ReminderAction.TERMINATION_NOTICE;
        } else if (daysElapsed >= 14) {
            return ReminderAction.SECOND_REMINDER;
        } else if (daysElapsed >= 7) {
            return ReminderAction.FIRST_REMINDER;
        } else {
            return ReminderAction.DEMAND_RAISED;
        }
    }
}