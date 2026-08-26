/**
 * @description Enterprise Interest Engine for Post-Sales CRM
 * Formulas strictly aligned with Slide 18 & 23 of Fingertipplus Post-Sales Flow
 */
public with sharing class InterestCalculator {
    public static final Decimal DEFAULT_ANNUAL_RATE = 12.0;

    /**
     * @description Calculates daily interest based on overdue days and project rate.
     * Interest = Principal * (AnnualRate / 365 / 100) * OverdueDays
     */
    public static Decimal calculateDailyInterest(Decimal principalAmount, Integer overdueDays, Decimal annualRate) {
        if (principalAmount == null || principalAmount <= 0 || overdueDays == null || overdueDays <= 0) {
            return 0.00;
        }
        Decimal effectiveRate = (annualRate != null && annualRate > 0) ? annualRate : DEFAULT_ANNUAL_RATE;
        Decimal dailyRate = (effectiveRate / 100.0) / 365.0;
        Decimal accruedInterest = principalAmount * dailyRate * overdueDays;
        return accruedInterest.setScale(2, System.RoundingMode.HALF_UP);
    }

    /**
     * @description Slide 24 Rule: Checks if interest is applicable (Agreement must be Executed).
     */
    public static Boolean isInterestApplicable(String agreementStatus, Integer overdueDays) {
        if (String.isBlank(agreementStatus) || !'Executed'.equalsIgnoreCase(agreementStatus)) {
            return false;
        }
        return (overdueDays != null && overdueDays > 0);
    }
}