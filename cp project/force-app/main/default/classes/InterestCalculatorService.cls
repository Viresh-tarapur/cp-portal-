/**
 * Service class for computing daily interest on overdue payments and managing 2-tier waivers.
 * Fingertipplus Technologies Pvt Ltd - Slide 18 Implementation
 */
public with sharing class InterestCalculatorService {
    public static final Decimal DEFAULT_ANNUAL_INTEREST_RATE = 0.12; // 12% per year
    public static final Integer DAYS_PER_YEAR = 365;

    /**
     * Calculates daily interest on overdue demand principal.
     * @param principal Principal amount (e.g. 10,00,000)
     * @param daysLate Number of days past the 15-day due date (e.g. 30 days)
     * @param annualRate Annual interest percentage (e.g. 0.12 for 12%)
     * @return Interest rounded to nearest integer (e.g. 9860)
     */
    public static Decimal calculateDailyInterest(Decimal principal, Integer daysLate, Decimal annualRate) {
        if (principal == null || principal <= 0 || daysLate == null || daysLate <= 0) {
            return 0.00;
        }

        Decimal rate = (annualRate != null && annualRate > 0) ? annualRate : DEFAULT_ANNUAL_INTEREST_RATE;
        Decimal dailyRate = rate / DAYS_PER_YEAR;
        Decimal interest = principal * dailyRate * daysLate;
        return interest.setScale(2, System.RoundingMode.HALF_UP);
    }

    /**
     * Slide 18 exact scenario verification helper:
     * Demand of 10,00,000 overdue for 30 days @ 12% p.a.
     */
    public static Decimal calculateStandardSlideScenario() {
        return calculateDailyInterest(1000000.00, 30, 0.12);
    }

    /**
     * Tier 1 Approval: CRM Manager
     */
    public static PostSalesModels.WaiverStatus approveWaiverByCRMManager(PostSalesModels.WaiverStatus currentStatus) {
        if (currentStatus == PostSalesModels.WaiverStatus.PENDING_CRM_MANAGER || currentStatus == PostSalesModels.WaiverStatus.NONE) {
            return PostSalesModels.WaiverStatus.PENDING_FINANCE;
        }
        return currentStatus;
    }

    /**
     * Tier 2 Approval: Finance User (Final Sign-off)
     */
    public static PostSalesModels.WaiverStatus approveWaiverByFinance(PostSalesModels.WaiverStatus currentStatus) {
        if (currentStatus == PostSalesModels.WaiverStatus.PENDING_FINANCE) {
            return PostSalesModels.WaiverStatus.APPROVED;
        }
        return currentStatus;
    }
}