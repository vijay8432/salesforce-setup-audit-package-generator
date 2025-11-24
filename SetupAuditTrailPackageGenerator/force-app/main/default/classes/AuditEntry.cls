/**
 * Represents a single record from Salesforce Setup Audit Trail.\
 * This class is used to pass audit data between Apex and UI components (LWC/Aura).
 * It mirrors key fields from the SetupAuditTrail object, which tracks configuration
 * and metadata changes and provides a clean, typed structure to work with these change logs.
 */
public class AuditEntry {

    /** Action performed (Created, Modified, Deleted, etc.) */
    @AuraEnabled public String action;

    /** The setup area where the change occurred (Apex Classes, Flows, Objects, etc.) */
    @AuraEnabled public String section;

    /** The full descriptive message recorded by Salesforce. Often includes component names. */
    @AuraEnabled public String display;

    /** Name of the user who made the change */
    @AuraEnabled public String createdByName;

    /** Timestamp of when the change occurred */
    @AuraEnabled public Datetime createdDate;


    /**
     * No-arg constructor required for AuraEnabled serialization and JSON parsing.
     */
    public AuditEntry() {}


    /**
     * @description
     *  Convenience constructor used primarily in Apex test methods to
     *  quickly create realistic AuditEntry objects.
     *
     * @param action          The action performed (Created, Modified, etc.)
     * @param section         The Setup section where change occurred
     * @param display         Human-readable description of the change
     * @param createdByName   User responsible for the change
     * @param createdDate     Timestamp of the change
     */
    public AuditEntry(
        String action,
        String section,
        String display,
        String createdByName,
        Datetime createdDate
    ) {
        this.action = action;
        this.section = section;
        this.display = display;
        this.createdByName = createdByName;
        this.createdDate = createdDate;
    }


    /**
     * Creates and returns a copy of this instance.
     * Useful when modifying values without altering the original.
     */
    public AuditEntry cloneEntry() {
        return new AuditEntry(action, section, display, createdByName, createdDate);
    }
}