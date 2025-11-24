/**
 * @description
 *  Service class responsible for:
 *    1. Fetching Setup Audit Trail entries (from org OR test data)
 *    2. Filtering entries by date, section, and keyword
 *    3. Mapping raw audit entries to MetadataItem objects
 *    4. Generating package.xml content based on selected metadata items
 *
 *  This class is used by LWC and Aura components through @AuraEnabled methods.
 */
public with sharing class SetupAuditService {

    /**
     * @description Used only for test injection.
     *              When populated, fetchAuditEntries() will return these values
     *              instead of querying SetupAuditTrail.
     */
    @TestVisible private static List<AuditEntry> mockAuditEntries;


    /**
     * @description DTO used to return the full audit result to LWC.
     */
    public class AuditResult {
        @AuraEnabled public List<AuditEntry> auditEntries;
        @AuraEnabled public Integer totalCount;
    }


    /**
     * @description
     *  Fetches Setup Audit Trail entries (either from test data or the org),
     *  applies optional filters, and returns the filtered result.
     *
     * @param maxRecords     Maximum number of audit records to fetch.
     * @param filterFromDate Include only audit records created after this date.
     * @param filterToDate   Include only audit records created before this date.
     * @param sectionFilter  Filter records by Setup section name.
     * @param keywordFilter  Filter records by keyword found in the Display text.
     *
     * @return AuditResult containing filtered audit entries + total count.
     */
    @AuraEnabled
    public static AuditResult fetchAuditEntries(
        Integer maxRecords,
        Datetime filterFromDate,
        Datetime filterToDate,
        String sectionFilter,
        String keywordFilter
    ) {
        List<AuditEntry> allEntries =
            (mockAuditEntries != null)
                ? mockAuditEntries
                : loadAuditEntriesFromOrg(maxRecords);

        List<AuditEntry> filteredEntries = new List<AuditEntry>();

        for (AuditEntry entry : allEntries) {
            Boolean include = true;

            if (filterFromDate != null && entry.createdDate < filterFromDate) include = false;
            if (filterToDate != null && entry.createdDate > filterToDate) include = false;

            if (!String.isBlank(sectionFilter)) {
                if (entry.section == null || !entry.section.toLowerCase().contains(sectionFilter.toLowerCase())) include = false;
            }
            if (!String.isBlank(keywordFilter)) {
                if (entry.display == null || !entry.display.toLowerCase().contains(keywordFilter.toLowerCase())) include = false;
            }

            if (include) filteredEntries.add(entry);
        }

        AuditResult result = new AuditResult();
        result.auditEntries = filteredEntries;
        result.totalCount = filteredEntries.size();
        return result;
    }


    /**
     * @description
     *  Queries SetupAuditTrail and maps rows into AuditEntry objects.
     *
     * @param maxRecords Maximum number of SetupAuditTrail records to query.
     *
     * @return List<AuditEntry> mapped from org audit trail.
     */
    private static List<AuditEntry> loadAuditEntriesFromOrg(Integer maxRecords) {
        String soqlQuery = 'SELECT Action, Section, Display, CreatedBy.Name, CreatedDate FROM SetupAuditTrail ORDER BY CreatedDate DESC';
        if (maxRecords != null && maxRecords > 0) soqlQuery += ' LIMIT ' + maxRecords;

        List<AuditEntry> auditList = new List<AuditEntry>();
        for (SObject row : Database.query(soqlQuery)) {
            AuditEntry entry = new AuditEntry();
            entry.action        = (String) row.get('Action');
            entry.section       = (String) row.get('Section');
            entry.display       = (String) row.get('Display');
            entry.createdDate   = (Datetime) row.get('CreatedDate');
            User createdByUser  = (User) row.getSObject('CreatedBy');
            entry.createdByName = (createdByUser == null ? null : createdByUser.Name);
            auditList.add(entry);
        }
        return auditList;
    }


    /**
     * @description
     *  Converts AuditEntry records into MetadataItem objects.
     *  Uses AuditParser to extract member names from the display text,
     *  and MetadataMapper to determine metadata type.
     *
     * @param request.
     *
     * @return List<MetadataItem> Metadata items suitable for package.xml generation.
     */
    @AuraEnabled
    public static List<MetadataItem> parseAndMapEntries(String request) {
        List<AuditEntry> auditEntries = (List<AuditEntry>)JSON.deserialize(request, List<AuditEntry>.class);
        List<MetadataItem> metadataList = new List<MetadataItem>();

        for (AuditEntry entry : auditEntries) {
            List<String> extractedNames = AuditParser.extractNames(entry.display);
            String metadataType = MetadataMapper.mapSectionToType(entry.section, entry.action, entry.display);

            // Skip if no meaningful metadata name was extracted
            if (extractedNames.isEmpty()) {
                // fallback: try using token by splitting on spaces and taking first CamelCase token
                List<String> fallback = AuditParser.extractNames(entry.display);
                if (!fallback.isEmpty()) extractedNames = fallback;
                else extractedNames.add(entry.display.split(' ')[1]); // e.g. SetupAuditService
            }

            for (String name : extractedNames) {
                metadataList.add(new MetadataItem(metadataType, name, entry.display));
            }
        }
        return metadataList;
    }

    @AuraEnabled
    public static String generatePackageXmlFromSelection(
        List<MetadataItem> selectedItems,
        String apiVersion
    ) {
        if (selectedItems == null || selectedItems.isEmpty()) {
            throw new AuraHandledException('No items selected.');
        }
        return PackageXmlBuilder.buildPackageXml(selectedItems, apiVersion);
    }

    @TestVisible
    public static void setTestEntries(List<AuditEntry> auditEntries) {
        mockAuditEntries = auditEntries;
    }
}