/**
 * @description
 *  Utility class responsible for converting Setup Audit Trail "Section" and
 *  "Display" text into Salesforce Metadata API component types.
 *
 *  This class is used during audit parsing to determine the correct
 *  metadata type (ApexClass, Flow, CustomObject, etc.) for each audit entry.
 *
 *  The mapping logic is intentionally simple and pattern-based:
 *  - First, match metadata type from SetupAuditTrail.Section
 *  - If no match, fallback to matching keywords inside the display text
 *  - If still no match, return "Unknown"
 */
public with sharing class MetadataMapper {

    /**
     * Maps a Setup Audit Trail entry to the correct Salesforce Metadata API type.
     *
     * @param section SetupAuditTrail.Section
     * @param action  SetupAuditTrail.Action
     * @param display SetupAuditTrail.Display
     * @return Salesforce Metadata API type (ApexClass, Flow, CustomObject, etc.)
     */
    public static String mapSectionToType(String section, String action, String display) {
        if (section == null && action == null && display == null) return 'Unknown';
        String sec = String.isNotBlank(section) ? section.toLowerCase() : '';
        String act = String.isNotBlank(action) ? action.toLowerCase() : '';
        String dis = String.isNotBlank(display) ? display.toLowerCase() : '';

        // Lightning / LWC
        if (sec.contains('lightning web component') || sec.contains('lwc') || dis.contains('lightning web component') || dis.contains('lightning web component')) return 'LightningComponentBundle';
        if (sec.contains('lightning component') || dis.contains('aura component')) return 'AuraDefinitionBundle';

        // Apex
        if (sec.contains('apex class') || dis.contains('apex class')) return 'ApexClass';
        if (sec.contains('apex trigger') || dis.contains('apex trigger')) return 'ApexTrigger';
        if (sec.contains('apex page') || dis.contains('visualforce page') || sec.contains('page')) return 'ApexPage';
        if (sec.contains('apex component') || sec.contains('component')) return 'ApexComponent';

        // Custom Objects & Fields
        if (sec.contains('custom object') || dis.contains('custom object')) return 'CustomObject';
        if (sec.contains('custom field') || dis.contains('field')) return 'CustomField';
        if (sec.contains('formula field')) return 'CustomField';
        if (sec.contains('validation rule')) return 'ValidationRule';
        if (sec.contains('workflow rule') || act.contains('workflow rule') || dis.contains('workflow rule')) return 'WorkflowRule';
        if (sec.contains('process builder') || act.contains('process builder') || dis.contains('process builder')) return 'Flow';
        if (sec.contains('flow') || act.contains('flow') || dis.contains('flow')) return 'Flow';
        if (sec.contains('layout')) return 'Layout';
        if (sec.contains('record type')) return 'RecordType';

        // Security
        if (sec.contains('profile') || dis.contains('profile')) return 'Profile';
        if (sec.contains('permission set') || dis.contains('permission set')) return 'PermissionSet';
        if (sec.contains('role') || dis.contains('role')) return 'Role';
        if (sec.contains('sharing rule')) return 'SharingRules';

        // Automation & Logic
        if (sec.contains('approval process')) return 'ApprovalProcess';
        if (sec.contains('assignment rule')) return 'AssignmentRules';
        if (sec.contains('auto-response rule')) return 'AutoResponseRules';
        if (sec.contains('escalation rule')) return 'EscalationRules';

        // Email & Communication
        if (sec.contains('email template') || dis.contains('email template')) return 'EmailTemplate';
        if (sec.contains('email service')) return 'EmailService';

        // Reports & Dashboards
        if (sec.contains('report') || dis.contains('report')) return 'Report';
        if (sec.contains('dashboard') || dis.contains('dashboard')) return 'Dashboard';

        // Resources & Static Files
        if (sec.contains('static resource') || dis.contains('static resource')) return 'StaticResource';
        if (sec.contains('document') || dis.contains('document')) return 'Document';
        if (sec.contains('content asset')) return 'ContentAsset';

        // Apps & Tabs
        if (sec.contains('app menu') || sec.contains('custom app') || dis.contains('app')) return 'CustomApplication';
        if (sec.contains('tab')) return 'CustomTab';

        // Communities / Sites
        if (sec.contains('site') || sec.contains('experience cloud')) return 'SiteDotCom';
        if (sec.contains('community')) return 'Community';

        // Labels & Value Sets
        if (sec.contains('label')) return 'CustomLabels';
        if (sec.contains('global value set')) return 'GlobalValueSet';
        if (sec.contains('field set')) return 'FieldSet';
        if (sec.contains('named credential')) return 'NamedCredential';
        if (sec.contains('custom metadata type')) return 'CustomMetadata';
        if (sec.contains('permission set group')) return 'PermissionSetGroup';
        if (sec.contains('flexi page') || sec.contains('record page')) return 'FlexiPage';

        // Streaming / Event metadata
        if (sec.contains('streaming topic') || dis.contains('streaming topic')) return 'StreamingChannel';
        if (sec.contains('platform event') || dis.contains('platform event')) return 'PlatformEvent';
        if (sec.contains('change data capture') || dis.contains('change data capture')) return 'ChangeDataCapture';

        // Internal Salesforce processes
        if (dis.contains('payment credit process exception releasable action')) return 'InternalProcess';
        if (dis.contains('auto activate release updates')) return 'InternalProcess';
        if (dis.contains('release update')) return 'InternalProcess';
        if (dis.contains('batch job') || dis.contains('scheduled job')) return 'InternalProcess';
        if (dis.contains('orchestration records for standard orchestrations release task')) return 'InternalProcess';

        // Org Setup / Feature toggles
        if (dis.contains('changed allow agent-session linking')) return 'OrgSetupChange';
        if (dis.contains('organization setup action') || dis.contains('remotehomeorgopsenabledoffon')) return 'OrgSetupChange';
        if (dis.contains('org feature enabled') || dis.contains('org action')) return 'OrgSetupChange';

        // Fallback
        return 'Unknown';
    }
}