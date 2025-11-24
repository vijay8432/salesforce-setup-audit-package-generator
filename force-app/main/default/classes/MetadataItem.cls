/**
 * @description
 *  Represents a single metadata component used for building package.xml files.
 *
 *  A MetadataItem acts as a standardized structure to store:
 *      - The metadata type (ApexClass, Flow, CustomObject, etc.)
 *      - The actual component/member name
 *      - The original source text from SetupAuditTrail (for display/UI/debugging)
 *
 *  This class is commonly produced by:
 *      - SetupAuditService.parseAndMapEntries()
 *      - AuditParser (for name extraction)
 *
 *  And consumed by:
 *      - PackageXmlBuilder.buildPackageXml()
 */
public class MetadataItem {

    /**
     * @description Salesforce metadata type name.
     *              Example: "ApexClass", "Flow", "CustomObject", "CustomField".
     */
    @AuraEnabled
    public String typeName { get; set; }

    /**
     * @description The actual metadata component name to include inside <members>.
     *              Example: "LeadProcessor", "MyFlow", "Inventory__c".
     */
    @AuraEnabled
    public String memberName { get; set; }

    /**
     * @description
     *  Original SetupAuditTrail.Display text from which this item was extracted.
     *  This is helpful for UI purposes or debugging.
     */
    @AuraEnabled
    public String sourceText { get; set; }

    /**
     * @description
     *  REQUIRED: No-argument constructor for Aura/LWC/JSON deserialization
     */
    public MetadataItem() {
        // empty on purpose
    }
    
    /**
     * @description
     *  Constructor used to create a metadata item.
     *
     * @param typeName
     *      The Salesforce metadata type. (e.g., ApexClass, Flow, CustomObject)
     *
     * @param memberName
     *      The component name that will appear in <members> inside package.xml.
     *
     * @param sourceText
     *      The unmodified display text from the Setup Audit Trail record.
     *      This helps trace how the metadata name was parsed.
     */
    public MetadataItem(String typeName, String memberName, String sourceText) {
        this.typeName = typeName;
        this.memberName = memberName;
        this.sourceText = sourceText;
    }
}