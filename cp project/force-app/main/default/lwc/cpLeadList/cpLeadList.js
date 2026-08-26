import { LightningElement, track, wire } from 'lwc';
import getMyLeads from '@salesforce/apex/LeadRegistrationController.getMyLeads';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CpLeadList extends LightningElement {
    @track leads = [];
    @track filteredLeads = [];
    @track searchKey = '';
    @track activeStatusFilter = 'All';
    @track isLoading = true;

    @track selectedLeadForView = null;
    @track showScheduleModal = false;
    @track selectedLeadForVisit = null;

    wiredLeadsResult;

    @wire(getMyLeads)
    wiredLeads(result) {
        this.wiredLeadsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.leads = result.data.map(l => {
                const today = new Date().toISOString().slice(0, 10);
                const isProtected = l.Ownership_Status__c === 'Protected' && l.Protection_End_Date__c >= today;
                const isDup = l.Registration_Status__c === 'Duplicate' || l.Potential_Duplicate__c === true || Boolean(l.Duplicate_Reason__c) || Boolean(l.Duplicate_Found__c);
                const ownerNameVal = (l.Lead__r && l.Lead__r.Owner && l.Lead__r.Owner.Name) ? l.Lead__r.Owner.Name : (l.Owner ? l.Owner.Name : (l.Owner_Name__c || 'Sales Executive'));
                const ownerIdVal = (l.Lead__r && l.Lead__r.OwnerId) ? l.Lead__r.OwnerId : (l.OwnerId || ownerNameVal);

                return {
                    ...l,
                    formattedRegDate: l.Registration_Date__c ? l.Registration_Date__c.slice(0, 10) : '',
                    protectionDateClass: isProtected ? 'date-protected' : 'date-expired',
                    statusBadgeClass: `badge-status badge-${l.Registration_Status__c ? l.Registration_Status__c.toLowerCase() : ''}`,
                    ownershipBadgeClass: `badge-own own-${l.Ownership_Status__c ? l.Ownership_Status__c.toLowerCase() : ''}`,
                    isDuplicate: isDup,
                    duplicateReasonTitle: l.Duplicate_Reason__c || 'Duplicate record identified',
                    ownerNameDisplay: ownerNameVal,
                    ownerIdDisplay: ownerIdVal,
                    ownerPillClass: this.getOwnerClass(ownerNameVal)
                };
            });

            // Calculate Same-Owner Duplicate Flag
            this.leads.forEach(l => {
                let sameOwnerDup = false;
                if (l.isDuplicate) {
                    const normEmail = l.Customer_Email__c ? l.Customer_Email__c.toLowerCase().trim() : null;
                    const normPhone = l.Customer_Phone__c ? l.Customer_Phone__c.trim() : null;
                    const normName = l.Customer_Name__c ? l.Customer_Name__c.toLowerCase().trim() : null;

                    const matchingOther = this.leads.find(o => o.Id !== l.Id && (
                        (normEmail && o.Customer_Email__c && o.Customer_Email__c.toLowerCase().trim() === normEmail) ||
                        (normPhone && o.Customer_Phone__c && o.Customer_Phone__c.trim() === normPhone) ||
                        (normName && o.Customer_Name__c && o.Customer_Name__c.toLowerCase().trim() === normName)
                    ));

                    if (matchingOther) {
                        if (l.ownerIdDisplay === matchingOther.ownerIdDisplay || l.ownerNameDisplay === matchingOther.ownerNameDisplay) {
                            sameOwnerDup = true;
                        }
                    }
                }
                l.showSameOwnerDup = sameOwnerDup;
            });

            this.applyFilters();
        } else if (result.error) {
            console.error('Error fetching leads', result.error);
        }
    }

    getOwnerClass(ownerName) {
        if (!ownerName) return 'owner-pill owner-pill-se1';
        const name = ownerName.toLowerCase();
        if (name.includes('1') || name.includes('sky')) return 'owner-pill owner-pill-se1';
        if (name.includes('2') || name.includes('green')) return 'owner-pill owner-pill-se2';
        if (name.includes('3') || name.includes('yellow')) return 'owner-pill owner-pill-se3';
        if (name.includes('4') || name.includes('purple')) return 'owner-pill owner-pill-se4';
        const colors = ['owner-pill-se1', 'owner-pill-se2', 'owner-pill-se3', 'owner-pill-se4'];
        let hash = 0;
        for (let i = 0; i < ownerName.length; i++) hash += ownerName.charCodeAt(i);
        return 'owner-pill ' + colors[Math.abs(hash) % colors.length];
    }

    get totalCount() { return this.leads.length; }
    get protectedCount() { return this.leads.filter(l => l.Ownership_Status__c === 'Protected').length; }
    get expiredCount() { return this.leads.filter(l => l.Ownership_Status__c === 'Expired').length; }
    get duplicateCount() { return this.leads.filter(l => l.Registration_Status__c === 'Duplicate' || l.isDuplicate).length; }

    get allFilterClass() { return this.activeStatusFilter === 'All' ? 'pill-btn active' : 'pill-btn'; }
    get acceptedFilterClass() { return this.activeStatusFilter === 'Accepted' ? 'pill-btn active' : 'pill-btn'; }
    get expiredFilterClass() { return this.activeStatusFilter === 'Expired' ? 'pill-btn active' : 'pill-btn'; }
    get duplicateFilterClass() { return this.activeStatusFilter === 'Duplicate' ? 'pill-btn active' : 'pill-btn'; }

    get hasLeads() { return this.filteredLeads && this.filteredLeads.length > 0; }

    handleSearchChange(event) {
        this.searchKey = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handleFilterStatus(event) {
        this.activeStatusFilter = event.currentTarget.dataset.status;
        this.applyFilters();
    }

    applyFilters() {
        let result = [...this.leads];

        if (this.activeStatusFilter !== 'All') {
            if (this.activeStatusFilter === 'Accepted') {
                result = result.filter(l => l.Ownership_Status__c === 'Protected');
            } else if (this.activeStatusFilter === 'Expired') {
                result = result.filter(l => l.Ownership_Status__c === 'Expired');
            } else if (this.activeStatusFilter === 'Duplicate') {
                result = result.filter(l => l.Registration_Status__c === 'Duplicate' || l.isDuplicate);
            }
        }

        if (this.searchKey) {
            result = result.filter(l => 
                (l.Customer_Name__c && l.Customer_Name__c.toLowerCase().includes(this.searchKey)) ||
                (l.Customer_Phone__c && l.Customer_Phone__c.includes(this.searchKey)) ||
                (l.Customer_Email__c && l.Customer_Email__c.toLowerCase().includes(this.searchKey)) ||
                (l.Project__r && l.Project__r.Name && l.Project__r.Name.toLowerCase().includes(this.searchKey)) ||
                (l.Name && l.Name.toLowerCase().includes(this.searchKey))
            );
        }

        this.filteredLeads = result.map((l, idx) => ({
            ...l,
            rowIndex: idx + 1,
            rowClass: l.showSameOwnerDup ? 'row-duplicate' : '',
            isDifferentOwnerDup: l.isDuplicate && !l.showSameOwnerDup
        }));

    }

    handleOpenRegisterLead() {
        this.dispatchEvent(new CustomEvent('openregisterlead', { bubbles: true, composed: true }));
    }

    handleImportClick() {
        this.dispatchEvent(new ShowToastEvent({ title: 'Import', message: 'Import wizard is available for Admins.', variant: 'info' }));
    }

    handleChangeOwnerClick() {
        this.dispatchEvent(new ShowToastEvent({ title: 'Change Owner', message: 'Lead ownership is assigned via Round Robin.', variant: 'info' }));
    }

    handleViewDetails(event) {
        const leadId = event.currentTarget.dataset.id;
        this.selectedLeadForView = this.leads.find(l => l.Id === leadId);
    }

    handleCloseDetailModal() {
        this.selectedLeadForView = null;
    }

    handleScheduleVisit(event) {
        const leadId = event.currentTarget.dataset.id;
        this.selectedLeadForVisit = this.leads.find(l => l.Id === leadId);
        this.showScheduleModal = true;
    }

    handleScheduleVisitFromDetail() {
        this.selectedLeadForVisit = this.selectedLeadForView;
        this.selectedLeadForView = null;
        this.showScheduleModal = true;
    }

    handleCloseScheduleModal() {
        this.showScheduleModal = false;
        this.selectedLeadForVisit = null;
    }

    handleVisitScheduledSuccess() {
        this.showScheduleModal = false;
        this.selectedLeadForVisit = null;
        refreshApex(this.wiredLeadsResult);
        this.dispatchEvent(new ShowToastEvent({
            title: 'Site Visit Scheduled',
            message: 'Your site visit request has been logged and assigned.',
            variant: 'success'
        }));
    }
}
