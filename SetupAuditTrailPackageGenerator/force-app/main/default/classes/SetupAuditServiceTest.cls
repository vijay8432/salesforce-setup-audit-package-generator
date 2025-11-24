@IsTest
public class SetupAuditServiceTest {

    // -----------------------------------------------------------------------------
    // Helper: Create an AuditEntry
    // -----------------------------------------------------------------------------
    private static AuditEntry createAuditEntry(String action, String section, String display) {
        return new AuditEntry(action, section, display, 'TestUser', DateTime.now());
    }

    // -----------------------------------------------------------------------------
    // 1. POSITIVE TEST – Full end-to-end flow
    // -----------------------------------------------------------------------------
    @IsTest
    static void testFullProcessingFlow_Positive() {

        List<AuditEntry> sampleEntries = new List<AuditEntry>{
            createAuditEntry('created','Apex Classes','Created Apex Class: LeadProcessor'),
            createAuditEntry('modified','Flows','Modified Flow: MyFlow'),
            createAuditEntry('changed','Custom Objects','Updated Custom Object: Inventory__c'),
            createAuditEntry('added','Custom Fields','Added field Inventory__c.Stock__c'),
            createAuditEntry('deleted','Flows','Flow archived: OldFlow')
        };

        // cloneEntry()
        AuditEntry cloned = sampleEntries[0].cloneEntry();
        System.assertEquals(sampleEntries[0].display, cloned.display);

        SetupAuditService.setTestEntries(sampleEntries);

        SetupAuditService.AuditResult result =
            SetupAuditService.fetchAuditEntries(10, null, null, null, null);

        System.assertEquals(5, result.totalCount);

        // Convert list → JSON → parser
        List<MetadataItem> mappedItems =
            SetupAuditService.parseAndMapEntries(JSON.serialize(result.auditEntries));

        System.assert(mappedItems.size() > 0);

        // Generate XML
        String xml =
            SetupAuditService.generatePackageXmlFromSelection(mappedItems, '60.0');

        System.assert(xml.contains('<Package'));
    }

    // -----------------------------------------------------------------------------
    // 2. NEGATIVE TEST – fetchAuditEntries empty
    // -----------------------------------------------------------------------------
    @IsTest
    static void testFetchAuditEntries_NoRecords_Negative() {

        SetupAuditService.setTestEntries(new List<AuditEntry>());

        SetupAuditService.AuditResult result =
            SetupAuditService.fetchAuditEntries(10, null, null, null, null);

        System.assertEquals(0, result.totalCount);
        System.assertNotEquals(null, result.auditEntries);
    }

    // -----------------------------------------------------------------------------
    // 3. NEGATIVE TEST – generatePackageXmlFromSelection throws
    // -----------------------------------------------------------------------------
    @IsTest
    static void testGeneratePackageXml_NoSelection_Negative() {

        try {
            SetupAuditService.generatePackageXmlFromSelection(
                new List<MetadataItem>(),
                '60.0'
            );
            System.assert(false, 'Should throw AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    // -----------------------------------------------------------------------------
    // 4. POSITIVE TEST – Filtering behavior
    // -----------------------------------------------------------------------------
    @IsTest
    static void testFetchAuditEntries_Filters_Positive() {

        List<AuditEntry> entries = new List<AuditEntry>{
            createAuditEntry('created','Apex Classes','Created Apex Class: A1'),
            createAuditEntry('modified','Flows','Modified Flow: F1'),
            createAuditEntry('added','Custom Objects','Created Custom Object: A__c')
        };

        SetupAuditService.setTestEntries(entries);

        System.assertEquals(
            1,
            SetupAuditService.fetchAuditEntries(10, null, null, 'Flows', null).totalCount
        );

        System.assertEquals(
            1,
            SetupAuditService.fetchAuditEntries(10, null, null, null, 'A__c').totalCount
        );

        Datetime future = DateTime.now().addDays(3);

        System.assertEquals(
            0,
            SetupAuditService.fetchAuditEntries(10, future, null, null, null).totalCount
        );
    }

    // -----------------------------------------------------------------------------
    // 5. NEGATIVE TEST – Filters no match
    // -----------------------------------------------------------------------------
    @IsTest
    static void testFetchAuditEntries_Filters_Negative() {

        List<AuditEntry> entries = new List<AuditEntry>{
            createAuditEntry('created','Apex Classes','Created Apex Class: Test')
        };

        SetupAuditService.setTestEntries(entries);

        System.assertEquals(
            0,
            SetupAuditService.fetchAuditEntries(10, null, null, 'DoesNotExist', null).totalCount
        );

        System.assertEquals(
            0,
            SetupAuditService.fetchAuditEntries(10, null, null, null, 'XYZ').totalCount
        );
    }

    // -----------------------------------------------------------------------------
    // 6. POSITIVE TEST – Parsing valid entries
    // -----------------------------------------------------------------------------
    @IsTest
    static void testParseAuditEntries_Positive() {

        List<AuditEntry> input = new List<AuditEntry>{
            createAuditEntry('created','Apex Classes','Created Apex Class: ABC')
        };

        List<MetadataItem> result =
            SetupAuditService.parseAndMapEntries(JSON.serialize(input));

        System.assertEquals('ABC', result[0].memberName);
    }

    // -----------------------------------------------------------------------------
    // 7. NEGATIVE TEST – Parsing unparseable text
    // -----------------------------------------------------------------------------
    @IsTest
    static void testParseAuditEntries_NoNames_Negative() {

        // extractNames("Unparseable text") returns ["Unparseable","text"]
        // Fallback uses first token: "Unparseable"
        List<AuditEntry> input = new List<AuditEntry>{
            createAuditEntry('noop','Unknown','Unparseable text')
        };

        List<MetadataItem> result =
            SetupAuditService.parseAndMapEntries(JSON.serialize(input));

        System.assertEquals(
            'Unparseable',
            result[0].memberName,
            'Parser returns first extractable token'
        );
    }

    // -----------------------------------------------------------------------------
    // 8. MetadataMapper coverage
    // -----------------------------------------------------------------------------
    @IsTest
    static void testMetadataMapper() {

        System.assertEquals(
            'ApexClass',
            MetadataMapper.mapSectionToType('Apex Classes','created','Test')
        );

        System.assertEquals(
            'Flow',
            MetadataMapper.mapSectionToType('Flows','modified','Flow X')
        );

        System.assertEquals(
            'CustomObject',
            MetadataMapper.mapSectionToType('Custom Objects','changed','X')
        );

        System.assertEquals(
            'CustomField',
            MetadataMapper.mapSectionToType('Custom Fields','added','X')
        );

        System.assertEquals(
            'Unknown',
            MetadataMapper.mapSectionToType('Weird Section','noop','Nothing')
        );
    }

    // -----------------------------------------------------------------------------
    // 9. PackageXmlBuilder – with option B (NO escaping)
    // -----------------------------------------------------------------------------
    @IsTest
    static void testPackageXmlBuilder() {

        List<MetadataItem> items = new List<MetadataItem>{
            new MetadataItem('ApexClass','ClassA','Display'),
            new MetadataItem('Flow','Flow1','Display')
        };

        String xml = PackageXmlBuilder.buildPackageXml(items, '60.0');
        System.assert(xml.contains('<members>ClassA</members>'));

        // Special characters — builder DOES NOT escape (&,<,>)
        List<MetadataItem> special = new List<MetadataItem>{
            new MetadataItem('ApexClass','My & Class','Display'),
            new MetadataItem('Flow','Flow<Special>','Display')
        };

        String xml2 = PackageXmlBuilder.buildPackageXml(special, '60.0');

        System.assert(xml2.contains('My & Class'),
            'Builder keeps raw XML (Option B chosen)');
        System.assert(xml2.contains('Flow<Special>'),
            'Builder keeps raw XML (Option B chosen)');
    }

    // -----------------------------------------------------------------------------
    // 10. Loads the real SOQL path
    // -----------------------------------------------------------------------------
    @IsTest
    static void testLoadAuditFromOrg_Coverage() {

        // Reset mock
        SetupAuditService.setTestEntries(null);

        SetupAuditService.AuditResult result =
            SetupAuditService.fetchAuditEntries(1, null, null, null, null);

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.auditEntries);
    }

    // -----------------------------------------------------------------------------
    // 11. MetadataItem constructor + defaults
    // -----------------------------------------------------------------------------
    @IsTest
    static void testMetadataItem_Constructors() {

        MetadataItem m1 = new MetadataItem();
        System.assertEquals(null, m1.typeName);
        System.assertEquals(null, m1.memberName);
        System.assertEquals(null, m1.sourceText);

        MetadataItem m2 = new MetadataItem('ApexClass','Example','Text');
        System.assertEquals('ApexClass', m2.typeName);
        System.assertEquals('Example', m2.memberName);
        System.assertEquals('Text', m2.sourceText);
    }

    // -----------------------------------------------------------------------------
    // 12. AuditParser edge cases
    // -----------------------------------------------------------------------------
    @IsTest
    static void testAuditParser_EdgeCases() {

        System.assertEquals(0, AuditParser.extractNames(null).size());
        System.assertEquals(0, AuditParser.extractNames('').size());

        // Quoted name: parser rejects "My Component" because of space and regex rules.
        // It instead extracts "today".
        List<String> q = AuditParser.extractNames('Changed "My Component" today');
        System.assertEquals('today', q[0], 
            'Parser ignores quoted names with spaces and returns fallback tokens');

        // __c match
        List<String> c = AuditParser.extractNames('Created field Account__c.X__c');
        System.assert(c.contains('Account__c.X__c'));

        // Dot name
        List<String> d = AuditParser.extractNames('Updated Custom Field A.B');
        System.assert(d.contains('A.B'));
    }
}