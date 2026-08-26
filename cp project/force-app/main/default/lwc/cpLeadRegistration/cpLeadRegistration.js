import { LightningElement, api, track, wire } from 'lwc';
import getAuthorizedProjects from '@salesforce/apex/ProjectController.getAuthorizedProjects';
import getInventory from '@salesforce/apex/InventoryController.getInventory';
import submitLeadRegistration from '@salesforce/apex/LeadRegistrationController.submitLeadRegistration';
import checkDuplicate from '@salesforce/apex/LeadRegistrationController.checkDuplicate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CpLeadRegistration extends LightningElement {
    @api preselectedProjectId;
    @track projectOptions = [];
    @track unitOptions = [];
    @track form = {
        customerName: '',
        phone: '',
        email: '',
        projectId: '',
        inventoryUnitId: null,
        budget: null,
        requirement: '',
        expectedPurchaseDate: null,
        notes: ''
    };

    @track isLoading = false;
    @track isRegistered = false;
    @track registrationResponse = null;
    @track duplicateWarning = '';

    @wire(getAuthorizedProjects)
    wiredProjects({ error, data }) {
        if (data) {
            this.projectOptions = data.map(p => ({ label: p.Name, value: p.Id }));
            if (this.preselectedProjectId) {
                this.form.projectId = this.preselectedProjectId;
                this.loadUnitsForProject(this.preselectedProjectId);
            } else if (this.projectOptions.length > 0 && !this.form.projectId) {
                this.form.projectId = this.projectOptions[0].value;
                this.loadUnitsForProject(this.form.projectId);
            }
        }
    }

    connectedCallback() {
        if (this.preselectedProjectId) {
            this.form.projectId = this.preselectedProjectId;
        }
    }

    handleInputChange(event) {
        const field = event.target.name;
        this.form[field] = event.target.value;
    }

    handleProjectChange(event) {
        this.form.projectId = event.target.value;
        this.loadUnitsForProject(this.form.projectId);
        this.handleDuplicateCheck();
    }

    loadUnitsForProject(projectId) {
        if (!projectId) {
            this.unitOptions = [];
            return;
        }
        getInventory({ projectId: projectId, statusFilter: 'Available', unitTypeFilter: 'All' })
            .then(result => {
                this.unitOptions = result.map(u => ({
                    label: `Unit ${u.Unit_Number__c} (${u.Unit_Type__c} • ₹${u.Base_Price__c})`,
                    value: u.Id
                }));
            })
            .catch(err => {
                console.error('Error fetching units for project', err);
            });
    }

    get isUnitSelectDisabled() {
        return !this.form.projectId || this.unitOptions.length === 0;
    }

    get isSubmitDisabled() {
        return !this.form.customerName || !this.form.phone || !this.form.projectId || this.isLoading;
    }

    get formattedProtectionDate() {
        return this.registrationResponse && this.registrationResponse.protectionEndDate
            ? this.registrationResponse.protectionEndDate
            : '';
    }

    handleDuplicateCheck() {
        if (!this.form.projectId || (!this.form.phone && !this.form.email)) {
            return;
        }

        checkDuplicate({
            projectId: this.form.projectId,
            phone: this.form.phone,
            email: this.form.email
        })
        .then(result => {
            if (result.isDuplicate) {
                this.duplicateWarning = result.message;
            } else {
                this.duplicateWarning = '';
            }
        })
        .catch(err => {
            console.error('Error during duplicate check', err);
        });
    }

    handleSubmitLead() {
        if (!this.form.customerName || !this.form.phone || !this.form.projectId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: 'Please complete all required fields.',
                variant: 'error'
            }));
            return;
        }

        this.isLoading = true;
        submitLeadRegistration({ request: this.form })
            .then(response => {
                this.isLoading = false;
                this.registrationResponse = response;
                this.isRegistered = true;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Lead Registered & Protected!',
                    message: response.message,
                    variant: 'success'
                }));
            })
            .catch(err => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Registration Rejected',
                    message: err.body ? err.body.message : err.message,
                    variant: 'error'
                }));
            });
    }

    handleDone() {
        this.dispatchEvent(new CustomEvent('registrationsuccess', { bubbles: true, composed: true }));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel', { bubbles: true, composed: true }));
    }
}
