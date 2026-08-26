import { LightningElement, api, track, wire } from 'lwc';
import getAuthorizedProjects from '@salesforce/apex/ProjectController.getAuthorizedProjects';
import scheduleVisit from '@salesforce/apex/SiteVisitController.scheduleVisit';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CpSiteVisit extends LightningElement {
    @api prefilledLeadId;
    @api prefilledProjectId;
    @api prefilledCustomerName;
    @api prefilledCustomerPhone;
    @api prefilledCustomerEmail;

    @track projectOptions = [];
    @track form = {
        leadId: null,
        projectId: '',
        customerName: '',
        customerPhone: '',
        customerEmail: '',
        visitDate: null,
        visitTime: '11:00 AM',
        numberOfVisitors: 1,
        remarks: ''
    };

    @track isLoading = false;

    timeSlotOptions = [
        { label: '10:00 AM - 11:00 AM', value: '10:00 AM' },
        { label: '11:00 AM - 12:00 PM', value: '11:00 AM' },
        { label: '12:00 PM - 01:00 PM', value: '12:00 PM' },
        { label: '02:00 PM - 03:00 PM', value: '02:00 PM' },
        { label: '03:00 PM - 04:00 PM', value: '03:00 PM' },
        { label: '04:00 PM - 05:00 PM', value: '04:00 PM' },
        { label: '05:00 PM - 06:00 PM', value: '05:00 PM' }
    ];

    get minDate() {
        return new Date().toISOString().slice(0, 10);
    }

    @wire(getAuthorizedProjects)
    wiredProjects({ error, data }) {
        if (data) {
            this.projectOptions = data.map(p => ({ label: p.Name, value: p.Id }));
            if (this.prefilledProjectId) {
                this.form.projectId = this.prefilledProjectId;
            } else if (this.projectOptions.length > 0 && !this.form.projectId) {
                this.form.projectId = this.projectOptions[0].value;
            }
        }
    }

    connectedCallback() {
        this.form.leadId = this.prefilledLeadId;
        this.form.projectId = this.prefilledProjectId;
        this.form.customerName = this.prefilledCustomerName || '';
        this.form.customerPhone = this.prefilledCustomerPhone || '';
        this.form.customerEmail = this.prefilledCustomerEmail || '';
        this.form.visitDate = new Date(Date.now() + 86400000).toISOString().slice(0, 10); // Tomorrow
    }

    handleInputChange(event) {
        const field = event.target.name;
        this.form[field] = event.target.value;
    }

    get isSubmitDisabled() {
        return !this.form.customerName || !this.form.customerPhone || !this.form.projectId || !this.form.visitDate || this.isLoading;
    }

    handleSubmitVisit() {
        this.isLoading = true;
        scheduleVisit({ request: this.form })
            .then(() => {
                this.isLoading = false;
                this.dispatchEvent(new CustomEvent('visitscheduled', { bubbles: true, composed: true }));
            })
            .catch(err => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error Scheduling Visit',
                    message: err.body ? err.body.message : err.message,
                    variant: 'error'
                }));
            });
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel', { bubbles: true, composed: true }));
    }
}
