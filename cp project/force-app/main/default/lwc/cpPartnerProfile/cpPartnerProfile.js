import { LightningElement, track, wire } from 'lwc';
import getDashboardMetrics from '@salesforce/apex/PartnerPortalController.getDashboardMetrics';
import updatePartnerProfile from '@salesforce/apex/PartnerPortalController.updatePartnerProfile';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CpPartnerProfile extends LightningElement {
    @track partner = null;
    @track isLoading = true;
    @track isEditing = false;
    @track editForm = {};

    wiredMetricsResult;

    @wire(getDashboardMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        this.isLoading = false;
        if (result.data && result.data.partner) {
            this.partner = result.data.partner;
            this.editForm = { ...this.partner };
        } else if (result.error) {
            console.error('Error loading partner profile', result.error);
        }
    }

    get tierBadgeClass() {
        const tier = this.partner && this.partner.Partner_Tier__c ? this.partner.Partner_Tier__c.toLowerCase() : 'bronze';
        return `tier-pill tier-${tier}`;
    }

    get commissionEligibleText() {
        return this.partner && this.partner.Commission_Eligible__c ? 'YES (Active)' : 'NO (Pending Verification)';
    }

    handleStartEdit() {
        this.editForm = { ...this.partner };
        this.isEditing = true;
    }

    handleCancelEdit() {
        this.editForm = { ...this.partner };
        this.isEditing = false;
    }

    handleInputChange(event) {
        const field = event.target.name;
        this.editForm[field] = event.target.value;
    }

    handleSaveProfile() {
        this.isLoading = true;
        updatePartnerProfile({ partnerData: this.editForm })
            .then(updatedPartner => {
                this.partner = updatedPartner;
                this.isEditing = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Profile Updated',
                    message: 'Contact and banking details have been successfully updated.',
                    variant: 'success'
                }));
                return refreshApex(this.wiredMetricsResult);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Update Failed',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}
