/**
 * Parses Setup Audit Trail Display text to extract meaningful metadata names
 * (e.g., Apex classes, LWC components, custom fields). Removes generic action
 * words and formatting so UI and package.xml logic can use clean component names.
 */
public with sharing class AuditParser {

    /*
     * List of words we want to ignore when parsing the audit Display text.
     * These are generic action or filler terms commonly found in audit trail messages.
     */
    private static final Set<String> ACTION_KEYWORDS = new Set<String>{
        'changed','created','modified','deleted','added','removed','activated','deactivated',
        'enabled','disabled','component','webcomponent','lightning','bundle','update','view',
        'apex','class','code','auditparser','audit','container','the','by','with','value',
        'rule','workflow','page','employee','salesforce','mode','data','number','topics'
    };

    /**
     * Extracts likely metadata or component names from the SetupAuditTrail "Display" text.
     * Example input:
     *   "Modified Apex Class: LeadProcessor"
     *   "Deleted Custom Field Inventory__c.Stock__c (API Name)"
     *
     * @param display - Full descriptive audit message
     * @return List of detected component names (Apex classes, fields, flows, etc.)
     */
    public static List<String> extractNames(String display) {
        List<String> detectedNames = new List<String>();
        if (String.isBlank(display)) return detectedNames;

        // Quoted tokens
        Pattern pQuote = Pattern.compile('"([^"]+)"');
        Matcher mQuote = pQuote.matcher(display);
        while (mQuote.find()) {
            String name = strip(mQuote.group(1));
            if (isMetaName(name)) detectedNames.add(name);
        }
        if (!detectedNames.isEmpty()) return detectedNames;

        // Clean display text
        String cleanedDisplay = display.replaceAll(':', ' ');
        cleanedDisplay = cleanedDisplay.replaceAll('\\(', ' ').replaceAll('\\)', ' ');
        cleanedDisplay = cleanedDisplay.replaceAll('[,;]', ' ');
        cleanedDisplay = cleanedDisplay.replaceAll(' - ', ' ');
        cleanedDisplay = cleanedDisplay.replaceAll('  +', ' ');

        for (String kw : ACTION_KEYWORDS) {
            cleanedDisplay = cleanedDisplay.replaceAll('(?i)\\b' + Pattern.quote(kw) + '\\b', ' ');
        }

        List<String> tokens = cleanedDisplay.split('\\s+');
        for (String token : tokens) {
            String cleanToken = strip(token);
            if (isMetaName(cleanToken)) detectedNames.add(cleanToken);
        }

        return detectedNames;
    }

    /*
     * Determines whether a token resembles a real metadata name.
     */
    private static Boolean isMetaName(String token) {
        if (String.isBlank(token)) return false;
        String lowerToken = token.toLowerCase();

        if (ACTION_KEYWORDS.contains(lowerToken)) return false;
        if (lowerToken.equals('code') || lowerToken.equals('class') || lowerToken.equals('apex')) return false;

        if (token.contains('__c')) return true; 
        if (token.contains('.')) return true;   

        return Pattern.matches('[A-Za-z][A-Za-z0-9_]+', token);
    }

    /*
     * Removes quotes and trims whitespace.
     */
    private static String strip(String raw) {
        String value = raw == null ? '' : raw.trim();
        if (value.length() >= 2 && value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length() - 1);
        }
        return value.trim();
    }
}