import { LightningElement, track, wire } from 'lwc';
import getMySupportCases from '@salesforce/apex/SupportController.getMySupportCases';
import createSupportCase from '@salesforce/apex/SupportController.createSupportCase';
import getAuthorizedProjects from '@salesforce/apex/ProjectController.getAuthorizedProjects';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CpSupport extends LightningElement {
    @track cases = [];
    @track projectOptions = [];
    @track isLoading = true;
    @track showNewTicketModal = false;

    @track form = {
        subject: '',
        category: 'Commission Issue',
        description: '',
        projectId: null,
        leadId: null
    };

    categoryOptions = [
        { label: 'Commission Issue', value: 'Commission Issue' },
        { label: 'Lead Registration & Exclusivity', value: 'Lead Issue' },
        { label: 'Inventory & Pricing Dispute', value: 'Inventory Issue' },
        { label: 'Payment & Payout Status', value: 'Payment Issue' },
        { label: 'KYC & Compliance Verification', value: 'KYC Issue' },
        { label: 'Portal Access / Technical', value: 'Technical Issue' },
        { label: 'General / Other Inquiry', value: 'Other' }
    ];

    wiredCasesResult;

    @wire(getMySupportCases)
    wiredCases(result) {
        this.wiredCasesResult = result;
        this.isLoading = false;
        if (result.data) {
            this.cases = result.data.map(c => {
                const status = c.Status ? c.Status.toLowerCase().replace(' ', '-') : '';
                const priority = c.Priority ? c.Priority.toLowerCase() : 'medium';
                return {
                    ...c,
                    projectName: c.Project__r ? c.Project__r.Name : '—',
                    formattedCreatedDate: c.CreatedDate ? c.CreatedDate.slice(0, 10) : '',
                    statusBadgeClass: `status-badge badge-${status}`,
                    priorityBadgeClass: `prio-badge prio-${priority}`
                };
            });
        } else if (result.error) {
            console.error('Error fetching support cases', result.error);
        }
    }

    @wire(getAuthorizedProjects)
    wiredProjects({ error, data }) {
        if (data) {
            this.projectOptions = [
                { label: '-- None --', value: '' },
                ...data.map(p => ({ label: p.Name, value: p.Id }))
            ];
        }
    }

    get totalCasesCount() {
        return this.cases.length;
    }

    get openCasesCount() {
        return this.cases.filter(c => c.Status !== 'Resolved' && c.Status !== 'Closed').length;
    }

    get resolvedCasesCount() {
        return this.cases.filter(c => c.Status === 'Resolved' || c.Status === 'Closed').length;
    }

    get hasCases() {
        return this.cases && this.cases.length > 0;
    }

    get isSubmitDisabled() {
        return !this.form.subject || !this.form.description || !this.form.category;
    }

    handleOpenNewTicketModal() {
        this.form = {
            subject: '',
            category: 'Commission Issue',
            description: '',
            projectId: null,
            leadId: null
        };
        this.showNewTicketModal = true;
    }

    handleCloseNewTicketModal() {
        this.showNewTicketModal = false;
    }

    handleFormChange(event) {
        const field = event.target.name;
        this.form[field] = event.target.value;
    }

    handleSubmitTicket() {
        if (!this.form.subject || !this.form.description) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: 'Please provide both a Subject and Description.',
                variant: 'error'
            }));
            return;
        }

        this.isLoading = true;
        createSupportCase({
            subject: this.form.subject,
            category: this.form.category,
            description: this.form.description,
            projectId: this.form.projectId ? this.form.projectId : null,
            leadId: this.form.leadId ? this.form.leadId : null
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Ticket Raised Successfully',
                message: 'Support ticket submitted. A Channel Manager has been notified.',
                variant: 'success'
            }));
            this.showNewTicketModal = false;
            return refreshApex(this.wiredCasesResult);
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error Creating Support Ticket',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        })
        .finally(() => {
            this.isLoading = false;
        });
    }
}
