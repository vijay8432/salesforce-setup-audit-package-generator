/**
 * AuditContainer LWC
 *
 * This component fetches Setup Audit Trail records, extracts metadata references,
 * displays them in a lightning-datatable with infinite scrolling, and allows users
 * to select items to generate a package.xml file.
 *
 * Key features:
 *  • Fetch & normalize audit log entries from Apex
 *  • Parse display text to identify metadata components
 *  • Filter by section name or keyword
 *  • Infinite scrolling support for large datasets
 *  • package.xml creation from selected metadata rows
 *  • Download modal UI
 */

import { LightningElement, track } from 'lwc';

// Apex methods
import fetchAuditEntries from '@salesforce/apex/SetupAuditService.fetchAuditEntries';
import parseAndMapEntries from '@salesforce/apex/SetupAuditService.parseAndMapEntries';
import generatePackageXmlFromSelection from '@salesforce/apex/SetupAuditService.generatePackageXmlFromSelection';

// Toast API
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AuditContainer extends LightningElement {

    /* --------------------- STATE & FILTERS --------------------- */

    @track sectionFilter = '';       // Filter by Setup section name
    @track keywordFilter = '';       // Filter by text within Display or metadata name

    @track auditEntries = [];        // Raw audit dataset returned from Apex
    @track metadataItems = [];       // Parsed metadata name mappings
    @track combinedRows = [];        // Final merged (audit + metadata) dataset
    @track filteredRows = [];        // Rows after filter applied
    @track pagedRows = [];           // Rows currently visible (lazy loading)

    selectedFullRows = [];           // Full objects selected for package.xml
    @track selectedRowIds = [];      // Selected row IDs from datatable

    pageSize = 50;                   // Page size for infinite scrolling
    loadMoreOffset = 0;
    @track isLoading = false;
    @track isLoadingLazy = false;

    isApplyDisabled = true;          // Filter "Apply" button disabled state
    hideCheckboxColumn = false;      // Optionally hide selection column

    @track showDownloadModal = false;
    xmlContent = '';

    // Datatable columns
    columns = [
        { label: 'Action', fieldName: 'action', type: 'text', wrapText: true },
        { label: 'Section', fieldName: 'section', type: 'text', wrapText: true },
        { label: 'Display', fieldName: 'display', type: 'text', wrapText: true },
        { label: 'Created By', fieldName: 'createdByName', type: 'text', wrapText: true },
        { label: 'Created Date', fieldName: 'createdDateFormatted', type: 'text' }
    ];

    /* --------------------- LIFECYCLE HOOK --------------------- */

    /**
     * Called when the component loads.
     * Triggers initial audit trail fetch.
     */
    connectedCallback() {
        this.loadEntries();
    }

    /* --------------------- DATA LOADING --------------------- */

    /**
     * Retrieves audit records from Apex, parses metadata references,
     * builds final display rows, and initializes infinite scrolling.
     */
    async loadEntries() {
        this.isLoading = true;
        this.resetData();

        try {
            const result = await fetchAuditEntries({
                maxRecords: 100,
                filterFromDate: null,
                filterToDate: null,
                sectionFilter: this.sectionFilter || null,
                keywordFilter: this.keywordFilter || null
            });

            if (!result || !result.auditEntries) {
                this.showToast('Info', 'No audit entries found.', 'info');
                return;
            }

            // Normalization of audit result
            this.auditEntries = result.auditEntries.map((entry, idx) => ({
                __idx: idx,
                action: entry.action || '',
                section: entry.section || '',
                display: entry.display || '',
                createdByName: entry.createdByName || '',
                createdDate: entry.createdDate || ''
            }));

            // Parse metadata references via Apex
            const mapped = await parseAndMapEntries({ request: JSON.stringify(this.auditEntries) });
            this.metadataItems = mapped || [];

            // Build lookup dictionary
            const metaMap = {};
            this.metadataItems.forEach(m => {
                const key = m.sourceText || '';
                if (!metaMap[key]) metaMap[key] = [];
                metaMap[key].push(m);
            });

            let idCounter = 0;
            const builtRows = [];

            // Construct final rows
            for (const ae of this.auditEntries) {
                const matches = metaMap[ae.display] || [];

                if (matches.length) {
                    for (const m of matches) {
                        builtRows.push(this.buildFullRow(ae, m, ++idCounter));
                    }
                } else {
                    builtRows.push(
                        this.buildFullRow(ae, { typeName: '', memberName: '', sourceText: ae.display }, ++idCounter)
                    );
                }
            }

            // Deduping rows based on audit index value
            const unique = new Map();
            builtRows.forEach(r => {
                const key = r.id.split('-')[0];
                if (!unique.has(key)) unique.set(key, r);
            });

            this.combinedRows = Array.from(unique.values());

            // Enable infinite loading on table again
            this.template.querySelector('lightning-datatable').enableInfiniteLoading = true;

            this.filteredRows = [...this.combinedRows];
            this.pagedRows = this.filteredRows.slice(0, this.pageSize);
            this.loadMoreOffset = this.pagedRows.length;

        } catch (e) {
            console.error('Load error:', e);
            this.showToast('Error', this.safeError(e), 'error');
        } finally {
            this.isLoading = false;
            this.isLoadingLazy = false;
        }
    }

    /**
     * Clears all working state and selections.
     */
    resetData() {
        this.auditEntries = [];
        this.metadataItems = [];
        this.combinedRows = [];
        this.filteredRows = [];
        this.pagedRows = [];
        this.loadMoreOffset = 0;
        this.selectedRowIds = [];
        this.selectedFullRows = [];
    }

    /* --------------------- ROW UI BUILDING --------------------- */

    /**
     * Builds a single row combining audit entry fields with metadata mapping values.
     */
    buildFullRow(ae, mm, id) {
        let isoDate = null;

        if (ae.createdDate) {
            try {
                isoDate = new Date(ae.createdDate).toISOString();
            } catch (e) {
                isoDate = ae.createdDate;
            }
        }

        const readable = this.formatReadableDate(ae.createdDate);

        return {
            id: ae.__idx + '-' + id,
            action: ae.action,
            section: ae.section,
            display: ae.display,
            createdByName: ae.createdByName,
            createdDateFormatted: readable,
            createdDate: isoDate,
            typeName: mm.typeName || '',
            memberName: mm.memberName || '',
            sourceText: mm.sourceText || ''
        };
    }

    /**
     * Formats a date to human-friendly text like: "5th Feb, 2025 02:35 PM"
     */
    formatReadableDate(raw) {
        if (!raw) return '';
        const date = new Date(raw);
        if (isNaN(date.getTime())) return raw;

        const day = date.getDate();
        const suffix =
            day % 10 === 1 && day !== 11 ? 'st' :
                day % 10 === 2 && day !== 12 ? 'nd' :
                    day % 10 === 3 && day !== 13 ? 'rd' : 'th';

        const month = date.toLocaleString('en-US', { month: 'short' });
        const year = date.getFullYear();
        let hours = date.getHours();
        const minutes = String(date.getMinutes()).padStart(2, '0');
        const ampm = hours >= 12 ? 'PM' : 'AM';
        hours = hours % 12 || 12;

        return `${day}${suffix} ${month}, ${year} ${String(hours).padStart(2, '0')}:${minutes} ${ampm}`;
    }

    /* --------------------- INFINITE LOADING --------------------- */

    /**
     * Loads additional rows when the datatable scrolls down.
     */
    loadMoreData(event) {
        if (this.isLoadingLazy) return;
        this.isLoadingLazy = true;

        const target = event.target;
        const nextChunk = this.filteredRows.slice(
            this.loadMoreOffset,
            this.loadMoreOffset + this.pageSize
        );

        if (nextChunk.length) {
            this.pagedRows = [...this.pagedRows, ...nextChunk];
            this.loadMoreOffset = this.pagedRows.length;
        }

        this.isLoadingLazy = false;
        target.isLoading = false;

        if (this.pagedRows.length >= this.filteredRows.length) {
            target.enableInfiniteLoading = false;
        } else {
            target.enableInfiniteLoading = true;
        }
    }

    /* --------------------- FILTERING --------------------- */

    handleSectionChange(e) {
        this.sectionFilter = e.target.value || '';
        this.updateApplyState();
    }

    handleKeywordChange(e) {
        this.keywordFilter = e.target.value || '';
        this.updateApplyState();
    }

    /**
     * Enables Apply button when filter text has at least 3 characters.
     */
    updateApplyState() {
        this.isApplyDisabled = !(
            (this.sectionFilter && this.sectionFilter.length >= 3) ||
            (this.keywordFilter && this.keywordFilter.length >= 3)
        );
    }

    /**
     * Clears both filters and reloads the full dataset.
     */
    clearFilters() {
        this.sectionFilter = '';
        this.keywordFilter = '';
        this.updateApplyState();
        this.loadEntries();
    }

    /**
     * Applies section or keyword filters to the displayed rows.
     */
    applyFilters() {
        const s = (this.sectionFilter || '').trim().toLowerCase();
        const k = (this.keywordFilter || '').trim().lowerCase();

        let rows = this.combinedRows;

        if (s) rows = rows.filter(r => r.section.toLowerCase().includes(s));
        if (k) rows = rows.filter(r =>
            r.display.toLowerCase().includes(k) ||
            r.memberName.toLowerCase().includes(k)
        );

        this.filteredRows = rows;
        this.pagedRows = rows.slice(0, this.pageSize);
        this.loadMoreOffset = this.pagedRows.length;

        if (!rows.length) {
            this.showToast('Info', 'No rows match your filter.', 'info');
        }
    }

    /* --------------------- SELECTION HANDLERS --------------------- */

    handleRowSelection(event) {
        const selectedIds = event.detail.selectedRows.map(r => r.id);
        this.selectedRowIds = selectedIds;
        this.selectedFullRows = this.combinedRows.filter(r => selectedIds.includes(r.id));
    }

    get disableGenerateButton() {
        return this.selectedFullRows.length === 0;
    }

    /* --------------------- PACKAGE.XML GENERATION --------------------- */

    /**
     * Generates package.xml based on selected metadata items.
     */
    async generatePackage() {
        const validItems = this.selectedFullRows
            .filter(r => r.typeName && r.memberName)
            .map(r => ({
                typeName: r.typeName,
                memberName: r.memberName,
                sourceText: r.sourceText
            }));

        if (!validItems.length) {
            this.showToast('Warning', 'Selected rows do not contain valid metadata.', 'warning');
            return;
        }

        // Remove duplicates (type + name)
        const uniqueMap = new Map();
        validItems.forEach(item => {
            const key = item.typeName + '::' + item.memberName;
            if (!uniqueMap.has(key)) uniqueMap.set(key, item);
        });

        const uniqueItems = Array.from(uniqueMap.values());

        try {
            const xml = await generatePackageXmlFromSelection({
                selectedItems: uniqueItems,
                apiVersion: '60.0'
            });

            this.xmlContent = xml;

            Promise.resolve().then(() => {
                this.showDownloadModal = true;
                this.showToast('Success', 'package.xml generated. Confirm download.', 'success');
            });

        } catch (e) {
            console.error('XML error', e);
            this.showToast('Error', this.safeError(e), 'error');
        }
    }

    /**
     * Pretty printing XML for modal preview.
     */
    get prettyXmlContent() {
        if (!this.xmlContent) return 'No XML content available.';

        let formatted = this.xmlContent.replace(/>\s*</g, '>\n<');

        let level = 0;
        formatted = formatted.split('\n').map(line => {
            if (line.match(/^<\/[\w:-]+>/)) level = Math.max(level - 1, 0);

            const indented = '  '.repeat(level) + line.trim();

            if (
                line.match(/^<[\w:-]+[^>]*>$/) &&
                !line.match(/^<[\w:-]+>\s*<\/[\w:-]+>$/)
            ) {
                level++;
            }

            return indented;
        }).join('\n');

        return formatted;
    }

    /* --------------------- DOWNLOAD & UTILITIES --------------------- */

    closeModal() {
        this.showDownloadModal = false;
    }

    confirmDownload() {
        this.downloadXml(this.xmlContent);
        this.closeModal();
    }

    /**
     * Creates and triggers local download of package.xml.
     */
    downloadXml(xml) {
        if (!xml) return;

        const blob = new Blob([xml], { type: 'application/octet-stream' });
        const url = window.URL.createObjectURL(blob);

        const anchor = document.createElement('a');
        anchor.href = url;
        anchor.download = 'package.xml';
        anchor.target = '_self';
        document.body.appendChild(anchor);

        anchor.click();
        document.body.removeChild(anchor);

        window.URL.revokeObjectURL(url);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    /**
     * Safely extract error message from Apex or JS.
     */
    safeError(err) {
        return err?.body?.message || err?.message || 'Unknown error';
    }
}