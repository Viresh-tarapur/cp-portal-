/**
 * Data structures and models for Post-Sales Real Estate CRM
 * Fingertipplus Technologies Pvt Ltd
 */
public with sharing class PostSalesModels {
    public enum BookingStage {
        NEW_STAGE,
        BOOKED,
        AGREEMENT,
        DEMANDS,
        REGISTRATION,
        HANDOVER,
        CANCELLATION,
        SWAPPING
    }

    public enum ReceiptStatus {
        PENDING,
        APPROVED,
        REJECTED_DEAD
    }

    public enum DemandStatus {
        ISSUED,
        DUE,
        OVERDUE,
        PAID,
        CANCELLED
    }

    public enum WaiverStatus {
        NONE,
        PENDING_CRM_MANAGER,
        PENDING_FINANCE,
        APPROVED,
        REJECTED
    }

    public class BookingWrapper {
        @AuraEnabled public String bookingId { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String customerEmail { get; set; }
        @AuraEnabled public String customerPhone { get; set; }
        @AuraEnabled public String unitNumber { get; set; }
        @AuraEnabled public String unitType { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public String fundingType { get; set; } // 'Home Loan', 'Self Payment', 'Part Self + Part Loan'
        @AuraEnabled public String planType { get; set; } // 'Standard Payment Plan', 'Custom Payment Plan'
        @AuraEnabled public String stage { get; set; }
        @AuraEnabled public Boolean isLocked { get; set; }
        @AuraEnabled public String lockReason { get; set; }
        @AuraEnabled public Boolean kycVerified { get; set; }
        @AuraEnabled public Boolean welcomeMailSent { get; set; }
        @AuraEnabled public String welcomeCallRemarks { get; set; }
        @AuraEnabled public Boolean ddCopyUploaded { get; set; }
        @AuraEnabled public String ddReference { get; set; }
        @AuraEnabled public Boolean legalAgreementApproved { get; set; }
        @AuraEnabled public Boolean legalDeedApproved { get; set; }
        @AuraEnabled public String registrationNumber { get; set; }
        @AuraEnabled public Date registrationDate { get; set; }
        @AuraEnabled public Decimal totalDemanded { get; set; }
        @AuraEnabled public Decimal totalPaid { get; set; }
        @AuraEnabled public Decimal outstandingAmount { get; set; }
        @AuraEnabled public Decimal loanAmount { get; set; }
        @AuraEnabled public Decimal loanDisbursedAmount { get; set; }
        @AuraEnabled public String loanStatus { get; set; }
        @AuraEnabled public List<MilestoneWrapper> milestones { get; set; }
        @AuraEnabled public List<ReceiptWrapper> receipts { get; set; }

        public BookingWrapper() {
            this.milestones = new List<MilestoneWrapper>();
            this.receipts = new List<ReceiptWrapper>();
            this.isLocked = false;
        }
    }

    public class MilestoneWrapper {
        @AuraEnabled public String milestoneId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal percentage { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Date dueDate { get; set; }
    }

    public class DemandWrapper {
        @AuraEnabled public String demandId { get; set; }
        @AuraEnabled public String milestoneId { get; set; }
        @AuraEnabled public Decimal principalAmount { get; set; }
        @AuraEnabled public Decimal interestAmount { get; set; }
        @AuraEnabled public Date issueDate { get; set; }
        @AuraEnabled public Date dueDate { get; set; }
        @AuraEnabled public Integer daysElapsed { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class ReceiptWrapper {
        @AuraEnabled public String receiptId { get; set; }
        @AuraEnabled public Date receiptDate { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String paymentMode { get; set; }
        @AuraEnabled public String referenceNumber { get; set; }
        @AuraEnabled public String status { get; set; }
    }
}