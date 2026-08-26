import { LightningElement, track, wire } from 'lwc';
import getDashboardMetrics from '@salesforce/apex/PartnerPortalController.getDashboardMetrics';

export default class CpPortalDashboard extends LightningElement {
    @track metrics = {};
    @track isLoading = true;

    @wire(getDashboardMetrics)
    wiredMetrics({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.metrics = data;
        } else if (error) {
            console.error('Error fetching dashboard metrics', error);
        }
    }

    get partnerName() {
        return this.metrics.partner ? this.metrics.partner.Name : 'Partner';
    }

    get partnerTier() {
        return this.metrics.partner ? (this.metrics.partner.Partner_Tier__c || 'BRONZE') : 'BRONZE';
    }

    get partnerKycStatus() {
        return this.metrics.partner ? (this.metrics.partner.KYC_Status__c || 'Pending') : 'Pending';
    }

    get tierBadgeClass() {
        const tier = (this.partnerTier).toLowerCase();
        return `tier-pill tier-${tier}`;
    }

    get kycBadgeClass() {
        const status = (this.partnerKycStatus).toLowerCase();
        return status === 'approved' ? 'kyc-pill kyc-approved' : 'kyc-pill kyc-pending';
    }

    get formattedEarnedCommission() {
        return this.metrics.commissionEarned ? Number(this.metrics.commissionEarned).toLocaleString('en-IN') : '0';
    }

    get formattedPendingCommission() {
        return this.metrics.commissionPending ? Number(this.metrics.commissionPending).toLocaleString('en-IN') : '0';
    }

    get hasProjects() {
        return this.metrics.authorizedProjects && this.metrics.authorizedProjects.length > 0;
    }

    get authorizedProjectsCount() {
        return this.metrics.authorizedProjects ? this.metrics.authorizedProjects.length : 0;
    }

    get hasLeads() {
        return this.metrics.recentLeads && this.metrics.recentLeads.length > 0;
    }

    get hasUpcomingVisits() {
        return this.metrics.upcomingVisits && this.metrics.upcomingVisits.length > 0;
    }

    get hasCommissions() {
        return this.metrics.recentCommissions && this.metrics.recentCommissions.length > 0;
    }

    handleQuickRegisterLead() {
        this.dispatchEvent(new CustomEvent('openregisterlead', { bubbles: true, composed: true }));
    }

    handleNavProjects() {
        this.dispatchEvent(new CustomEvent('navigateto', { detail: { target: 'projects' }, bubbles: true, composed: true }));
    }

    handleNavLeads() {
        this.dispatchEvent(new CustomEvent('navigateto', { detail: { target: 'leads' }, bubbles: true, composed: true }));
    }

    handleNavVisits() {
        this.dispatchEvent(new CustomEvent('navigateto', { detail: { target: 'visits' }, bubbles: true, composed: true }));
    }

    handleNavCommissions() {
        this.dispatchEvent(new CustomEvent('navigateto', { detail: { target: 'commissions' }, bubbles: true, composed: true }));
    }
}
