import { LightningElement, api, track, wire } from 'lwc';
import getProjectDetails from '@salesforce/apex/ProjectController.getProjectDetails';

export default class CpProjectDetails extends LightningElement {
    @api projectId;
    @track project;
    @track isLoading = true;

    @wire(getProjectDetails, { projectId: '$projectId' })
    wiredProject({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.project = data;
        } else if (error) {
            console.error('Error fetching project details', error);
        }
    }

    get projectDescription() {
        return this.project && this.project.Description__c
            ? this.project.Description__c
            : 'Premium residential community featuring world-class architecture, expansive green spaces, state-of-the-art club amenities, 24/7 security, and seamless connectivity to major business and transit corridors.';
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('backtoprojects', { bubbles: true, composed: true }));
    }

    handleViewInventory() {
        this.dispatchEvent(new CustomEvent('viewinventory', {
            detail: { projectId: this.projectId },
            bubbles: true,
            composed: true
        }));
    }

    handleRegisterLead() {
        this.dispatchEvent(new CustomEvent('registerleadforproject', {
            detail: { projectId: this.projectId },
            bubbles: true,
            composed: true
        }));
    }
}
