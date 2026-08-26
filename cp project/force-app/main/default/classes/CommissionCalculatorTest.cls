@isTest
private class CommissionCalculatorTest {

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Prestige Realty Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Email__c = 'prestige@test.com',
            Phone__c = '9876543299',
            Partner_Tier__c = 'Gold',
            GST_Number__c = '29ABCDE1234F1Z5',
            Commission_Eligible__c = true
        );
        insert partner;

        Project__c proj = new Project__c(
            Name = 'Emerald Bay Villas',
            Project_Code__c = 'EBV-01',
            Location__c = 'Devanahalli',
            City__c = 'Bengaluru',
            Status__c = 'Ongoing',
            Active__c = true
        );
        insert proj;

        // Create Percentage Commission Rule (2.5% for Gold Tier on Emerald Bay)
        Commission_Rule__c rule = new Commission_Rule__c(
            Name = 'Emerald Bay - Gold Tier 2.5%',
            Project__c = proj.Id,
            Partner_Tier__c = 'Gold',
            Commission_Type__c = 'Percentage',
            Commission_Rate__c = 2.50,
            Effective_From__c = Date.today().addMonths(-1),
            Active__c = true
        );
        insert rule;
    }

    @isTest
    static void testPercentageCommissionCalculationWithGST() {
        Partner__c partner = [SELECT Id FROM Partner__c LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Decimal propertyValue = 10000000; // 1 Crore (10,000,000)

        Test.startTest();
        CommissionCalculator.CalculationResult result = CommissionCalculator.calculateCommission(
            partner.Id,
            proj.Id,
            propertyValue,
            Date.today()
        );
        Test.stopTest();

        // 2.5% of 10,000,000 = 250,000
        System.assertEquals(250000, result.grossCommission, 'Gross commission should be 2.5% of deal value');
        // TDS (5% of 250,000) = 12,500
        System.assertEquals(12500, result.taxDeduction, 'TDS deduction should be 5% of gross');
        // GST (18% of 250,000) = 45,000 (partner has GST Number)
        System.assertEquals(45000, result.gstAmount, 'GST should be 18% of gross');
        // Net Payable: 250,000 - 12,500 + 45,000 = 282,500
        System.assertEquals(282500, result.netCommission, 'Net payable should accurately combine TDS and GST');
    }

    @isTest
    static void testFallbackDefaultRuleCalculation() {
        Partner__c partner = [SELECT Id FROM Partner__c LIMIT 1];

        // Property with no matching custom rule -> uses 2.00% standard default
        Test.startTest();
        CommissionCalculator.CalculationResult result = CommissionCalculator.calculateCommission(
            partner.Id,
            null, // No project
            5000000,
            Date.today()
        );
        Test.stopTest();

        System.assertEquals(2.00, result.commissionRate, 'Should fallback to standard 2% rate');
        System.assertEquals(100000, result.grossCommission, 'Gross should be 2% of 5,000,000 = 100,000');
    }
}
