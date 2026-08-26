/**
 * @description Dynamic Commission Calculation Engine.
 * Resolves project and tier-specific commission rules without hardcoded rates.
 */
public with sharing class CommissionCalculator {

    public class CalculationResult {
        @AuraEnabled public Id appliedRuleId { get; set; }
        @AuraEnabled public String ruleName { get; set; }
        @AuraEnabled public Decimal propertyValue { get; set; }
        @AuraEnabled public Decimal commissionRate { get; set; }
        @AuraEnabled public Decimal grossCommission { get; set; }
        @AuraEnabled public Decimal tdsRate { get; set; }
        @AuraEnabled public Decimal taxDeduction { get; set; }
        @AuraEnabled public Decimal gstRate { get; set; }
        @AuraEnabled public Decimal gstAmount { get; set; }
        @AuraEnabled public Decimal netCommission { get; set; }
        @AuraEnabled public String calculationSummary { get; set; }
    }

    /**
     * @description Calculates partner commission based on active configurable Commission Rules.
     * @param partnerId Channel Partner ID
     * @param projectId Project ID
     * @param propertyValue Agreement / booking property value
     * @param bookingDate Date of transaction
     * @return CalculationResult with complete tax and payout breakdown
     */
    public static CalculationResult calculateCommission(Id partnerId, Id projectId, Decimal propertyValue, Date bookingDate) {
        CalculationResult result = new CalculationResult();
        result.propertyValue = propertyValue != null ? propertyValue : 0;
        result.tdsRate = 5.00; // 5% TDS
        result.gstRate = 0.00;
        result.gstAmount = 0.00;

        if (bookingDate == null) {
            bookingDate = Date.today();
        }

        // 1. Retrieve Partner details (Tier and GST status)
        List<Partner__c> partners = [
            SELECT Id, Name, Partner_Tier__c, Commission_Eligible__c, GST_Number__c
            FROM Partner__c
            WHERE Id = :partnerId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        String partnerTier = 'All';
        Boolean isGstRegistered = false;
        if (!partners.isEmpty()) {
            partnerTier = partners[0].Partner_Tier__c != null ? partners[0].Partner_Tier__c : 'All';
            isGstRegistered = String.isNotBlank(partners[0].GST_Number__c);
            if (isGstRegistered) {
                result.gstRate = 18.00; // 18% GST for registered partners
            }
        }

        // 2. Query Applicable Commission Rules (ordered by specificity)
        List<Commission_Rule__c> rules = [
            SELECT Id, Name, Project__c, Partner_Tier__c, Commission_Type__c, Commission_Rate__c,
                   Fixed_Amount__c, Minimum_Booking_Amount__c, Maximum_Booking_Amount__c,
                   Effective_From__c, Effective_To__c
            FROM Commission_Rule__c
            WHERE Active__c = true
              AND (Project__c = :projectId OR Project__c = null)
              AND (Partner_Tier__c = :partnerTier OR Partner_Tier__c = 'All')
              AND Effective_From__c <= :bookingDate
              AND (Effective_To__c = null OR Effective_To__c >= :bookingDate)
              AND (Minimum_Booking_Amount__c = null OR Minimum_Booking_Amount__c <= :propertyValue)
              AND (Maximum_Booking_Amount__c = null OR Maximum_Booking_Amount__c >= :propertyValue)
            WITH SYSTEM_MODE
            ORDER BY Project__c NULLS LAST, Partner_Tier__c NULLS LAST, Minimum_Booking_Amount__c DESC
            LIMIT 1
        ];

        if (rules.isEmpty()) {
            // Fallback default rule calculation (e.g. 2% default) if no explicit rule matrix matches
            result.commissionRate = 2.00;
            result.grossCommission = (result.propertyValue * 0.02).setScale(2, RoundingMode.HALF_UP);
            result.ruleName = 'Standard Real Estate Default (2.00%)';
        } else {
            Commission_Rule__c rule = rules[0];
            result.appliedRuleId = rule.Id;
            result.ruleName = rule.Name;

            if (rule.Commission_Type__c == 'Percentage') {
                result.commissionRate = rule.Commission_Rate__c != null ? rule.Commission_Rate__c : 2.00;
                result.grossCommission = (result.propertyValue * (result.commissionRate / 100)).setScale(2, RoundingMode.HALF_UP);
            } else if (rule.Commission_Type__c == 'Fixed Amount') {
                result.commissionRate = 0;
                result.grossCommission = rule.Fixed_Amount__c != null ? rule.Fixed_Amount__c : 0;
            } else {
                // Slab or Percentage fallback
                result.commissionRate = rule.Commission_Rate__c != null ? rule.Commission_Rate__c : 2.00;
                result.grossCommission = (result.propertyValue * (result.commissionRate / 100)).setScale(2, RoundingMode.HALF_UP);
            }
        }

        // 3. Tax Deductions & Net Payout Calculation
        result.taxDeduction = (result.grossCommission * (result.tdsRate / 100)).setScale(2, RoundingMode.HALF_UP);
        if (isGstRegistered) {
            result.gstAmount = (result.grossCommission * (result.gstRate / 100)).setScale(2, RoundingMode.HALF_UP);
        }
        result.netCommission = (result.grossCommission - result.taxDeduction + result.gstAmount).setScale(2, RoundingMode.HALF_UP);

        result.calculationSummary = 'Gross: ₹' + result.grossCommission.format() + 
                                   ' | TDS (5%): -₹' + result.taxDeduction.format() + 
                                   (isGstRegistered ? ' | GST (18%): +₹' + result.gstAmount.format() : '') + 
                                   ' | Net Payable: ₹' + result.netCommission.format();

        return result;
    }
}
