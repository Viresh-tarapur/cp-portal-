import { LightningElement, track, wire } from 'lwc';
import getMyCommissions from '@salesforce/apex/CommissionController.getMyCommissions';

export default class CpCommission extends LightningElement {
    @track summary = {};
    @track commissions = [];
    @track isLoading = true;

    @wire(getMyCommissions)
    wiredCommissions({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.summary = data;
            this.commissions = (data.commissions || []).map(c => {
                const appStatus = c.Approval_Status__c ? c.Approval_Status__c.toLowerCase().replace(' ', '-') : '';
                const payStatus = c.Payment_Status__c ? c.Payment_Status__c.toLowerCase() : '';
                return {
                    ...c,
                    approvalBadgeClass: `status-pill app-${appStatus}`,
                    paymentBadgeClass: `status-pill pay-${payStatus}`
                };
            });
        } else if (error) {
            console.error('Error loading commissions', error);
        }
    }

    get formattedEarned() {
        return this.summary.totalEarned ? Number(this.summary.totalEarned).toLocaleString('en-IN') : '0';
    }

    get formattedPending() {
        return this.summary.totalPending ? Number(this.summary.totalPending).toLocaleString('en-IN') : '0';
    }

    get formattedPaid() {
        return this.summary.totalPaid ? Number(this.summary.totalPaid).toLocaleString('en-IN') : '0';
    }

    get hasCommissions() {
        return this.commissions && this.commissions.length > 0;
    }
}
