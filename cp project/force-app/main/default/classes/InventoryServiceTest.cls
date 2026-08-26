@isTest
private class InventoryServiceTest {

    @testSetup
    static void setupTestData() {
        Partner__c partner = new Partner__c(
            Name = 'Prime Real Estate',
            Email__c = 'partner@primerealestate.com',
            Phone__c = '+91 9988776655',
            Partner_Type__c = 'Brokerage Firm',
            Status__c = 'Approved',
            KYC_Status__c = 'Approved',
            Partner_Tier__c = 'Gold',
            Commission_Eligible__c = true
        );
        insert partner;

        Project__c proj = new Project__c(
            Name = 'Prime Oasis',
            Project_Code__c = 'PRJ-PO-001',
            Active__c = true,
            Status__c = 'Ongoing',
            City__c = 'Bengaluru',
            Available_Units__c = 10,
            Sold_Units__c = 0
        );
        insert proj;

        Project_Access__c pa = new Project_Access__c(
            Partner__c = partner.Id,
            Project__c = proj.Id,
            Access_Status__c = 'Active',
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(60),
            Can_Register_Lead__c = true,
            Can_View_Inventory__c = true
        );
        insert pa;

        Inventory_Unit__c unit = new Inventory_Unit__c(
            Project__c = proj.Id,
            Unit_Number__c = 'A-101',
            Floor__c = 1,
            Unit_Type__c = '2BHK',
            Area__c = 1200,
            Base_Price__c = 7500000,
            Status__c = 'Available',
            Booking_Amount__c = 200000
        );
        insert unit;
    }

    @isTest
    static void testGetInventoryForProject() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        List<Inventory_Unit__c> units = InventoryService.getInventoryForProject(p.Id, proj.Id, 'All', 'All');
        List<Inventory_Unit__c> filteredUnits = InventoryController.getInventory(proj.Id, 'Available', '2BHK');
        Test.stopTest();

        System.assertEquals(1, units.size(), 'Should find 1 unit');
        System.assertEquals(1, filteredUnits.size(), 'Should find 1 filtered unit');
        System.assertEquals('A-101', units[0].Unit_Number__c);
    }

    @isTest
    static void testReserveUnitSuccess() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];
        Inventory_Unit__c unit = [SELECT Id FROM Inventory_Unit__c LIMIT 1];

        Test.startTest();
        Inventory_Unit__c reserved = InventoryService.reserveUnit(p.Id, unit.Id, 30);
        Test.stopTest();

        System.assertEquals('Reserved', reserved.Status__c);
        System.assertEquals(p.Id, reserved.Blocked_By_Partner__c);
    }

    @isTest
    static void testReserveUnitDuplicateHoldThrowsException() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];
        Inventory_Unit__c unit = [SELECT Id FROM Inventory_Unit__c LIMIT 1];

        InventoryService.reserveUnit(p.Id, unit.Id, 30);

        try {
            Test.startTest();
            InventoryService.reserveUnit(p.Id, unit.Id, 30);
            Test.stopTest();
            System.assert(false, 'Should throw exception on duplicate reservation');
        } catch (InventoryService.InventoryException e) {
            System.assert(true);
        }
    }

    @isTest
    static void testBookUnitSuccess() {
        Partner__c p = [SELECT Id FROM Partner__c LIMIT 1];
        Inventory_Unit__c unit = [SELECT Id FROM Inventory_Unit__c LIMIT 1];

        Test.startTest();
        Inventory_Unit__c booked = InventoryService.bookUnit(p.Id, unit.Id, null);
        Test.stopTest();

        System.assertEquals('Booked', booked.Status__c);
        Project__c proj = [SELECT Sold_Units__c, Available_Units__c FROM Project__c LIMIT 1];
        System.assertEquals(1, proj.Sold_Units__c);
        System.assertEquals(9, proj.Available_Units__c);
    }

    @isTest
    static void testInventoryControllerReserve() {
        Inventory_Unit__c unit = [SELECT Id FROM Inventory_Unit__c LIMIT 1];

        Test.startTest();
        Inventory_Unit__c res = InventoryController.reserveInventoryUnit(unit.Id, 45);
        Test.stopTest();

        System.assertNotEquals(null, res);
    }
}
