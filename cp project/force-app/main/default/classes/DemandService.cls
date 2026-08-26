/**
 * Service for raising Individual, Bulk, and Custom Demands with automatic roll-forward of dues & interest.
 * Fingertipplus Technologies Pvt Ltd - Slide 15 Implementation
 */
public with sharing class DemandService {
    public class DemandCalculationResult {
        @AuraEnabled public Decimal milestoneAmount { get; set; }
        @AuraEnabled public Decimal previousPendingDues { get; set; }
        @AuraEnabled public Decimal previousInterestDues { get; set; }
        @AuraEnabled public Decimal netPayableTotal { get; set; }

        public DemandCalculationResult() {
            this.milestoneAmount = 0.0;
            this.previousPendingDues = 0.0;
            this.previousInterestDues = 0.0;
            this.netPayableTotal = 0.0;
        }
    }

    /**
     * Calculates the total demand amount incorporating old pending dues and interest.
     * "Old dues never disappear" - Slide 15
     */
    public static DemandCalculationResult calculateDemandWithArrears(Decimal milestoneAmount, Decimal oldPendingAmount, Decimal oldInterestAmount) {
        DemandCalculationResult result = new DemandCalculationResult();
        result.milestoneAmount = (milestoneAmount != null) ? milestoneAmount : 0.0;
        result.previousPendingDues = (oldPendingAmount != null) ? oldPendingAmount : 0.0;
        result.previousInterestDues = (oldInterestAmount != null) ? oldInterestAmount : 0.0;
        result.netPayableTotal = result.milestoneAmount + result.previousPendingDues + result.previousInterestDues;
        return result;
    }

    /**
     * Raises a new demand record with 15-day payment due date.
     */
    public static PostSalesModels.DemandWrapper createDemand(String milestoneId, Decimal principalAmount, Decimal accruedInterest) {
        PostSalesModels.DemandWrapper demand = new PostSalesModels.DemandWrapper();
        demand.demandId = 'DEM-' + System.currentTimeMillis();
        demand.milestoneId = milestoneId;
        demand.principalAmount = principalAmount;
        demand.interestAmount = (accruedInterest != null) ? accruedInterest : 0.0;
        demand.issueDate = Date.today();
        demand.dueDate = Date.today().addDays(15);
        demand.daysElapsed = 0;
        demand.status = String.valueOf(PostSalesModels.DemandStatus.ISSUED);
        return demand;
    }
}