@IsTest
private class CpLeadRoundRobinTest {
    @IsTest
    static void testAssignAndDuplicatesInMemory() {
        Lead l1 = new Lead(LastName = 'Test1', Company = 'CP', LeadSource = 'Channel Partner');
        Lead l2 = new Lead(LastName = 'Test2', Company = 'CP', LeadSource = 'Web');
        CpLeadRoundRobin.assign(new List<Lead>{ l1, l2 });

        Lead l3 = new Lead(LastName = 'Dup1', Company = 'CP', LeadSource = 'Channel Partner', Email = 'dup@example.com', Phone = '1234567890');
        Lead l4 = new Lead(LastName = 'Dup2', Company = 'CP', LeadSource = 'Channel Partner', Email = 'dup@example.com', Phone = '9999999999');
        Lead l5 = new Lead(LastName = 'Dup3', Company = 'CP', LeadSource = 'Channel Partner', Email = 'other@example.com', Phone = '1234567890');
        Lead l6 = new Lead(LastName = 'Dup4', Company = 'CP', LeadSource = 'Channel Partner', Email = 'dup@example.com', Phone = '1234567890');
        CpLeadRoundRobin.checkDuplicates(new List<Lead>{ l3, l4, l5, l6 });
        
        System.assertEquals(true, l4.Potential_Duplicate__c);
        System.assertEquals(true, l5.Potential_Duplicate__c);
        System.assertEquals(true, l6.Potential_Duplicate__c);
    }

    @IsTest
    static void testNonCpLead() {
        Lead l = new Lead(LastName = 'WebLead', Company = 'Company', LeadSource = 'Web');
        CpLeadRoundRobin.assign(new List<Lead>{ l });
        CpLeadRoundRobin.checkDuplicates(new List<Lead>{ l });
        System.assertNotEquals(true, l.Potential_Duplicate__c);
    }
}
