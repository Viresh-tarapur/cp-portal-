import { LightningElement, track } from 'lwc';

export default class CpPortalApp extends LightningElement {
    @track currentTab = 'dashboard';
    @track selectedProjectId = null;
    @track showRegisterLeadModal = false;

    get isDashboard() { return this.currentTab === 'dashboard'; }
    get isProjects() { return this.currentTab === 'projects'; }
    get isProjectDetails() { return this.currentTab === 'project-details'; }
    get isInventory() { return this.currentTab === 'inventory'; }
    get isLeads() { return this.currentTab === 'leads'; }
    get isSiteVisits() { return this.currentTab === 'visits'; }
    get isCommission() { return this.currentTab === 'commissions'; }
    get isKyc() { return this.currentTab === 'kyc'; }
    get isSupport() { return this.currentTab === 'support'; }
    get isProfile() { return this.currentTab === 'profile'; }

    get dashboardTabClass() { return this.getTabClass('dashboard'); }
    get projectsTabClass() { return this.getTabClass('projects') || this.getTabClass('project-details'); }
    get inventoryTabClass() { return this.getTabClass('inventory'); }
    get leadsTabClass() { return this.getTabClass('leads'); }
    get siteVisitsTabClass() { return this.getTabClass('visits'); }
    get commissionTabClass() { return this.getTabClass('commissions'); }
    get kycTabClass() { return this.getTabClass('kyc'); }
    get supportTabClass() { return this.getTabClass('support'); }

    getTabClass(tabName) {
        return this.currentTab === tabName ? 'nav-item active' : 'nav-item';
    }

    handleNavDashboard() { this.currentTab = 'dashboard'; }
    handleNavProjects() { this.currentTab = 'projects'; this.selectedProjectId = null; }
    handleNavInventory() { this.currentTab = 'inventory'; }
    handleNavLeads() { this.currentTab = 'leads'; }
    handleNavSiteVisits() { this.currentTab = 'visits'; }
    handleNavCommission() { this.currentTab = 'commissions'; }
    handleNavKyc() { this.currentTab = 'kyc'; }
    handleNavSupport() { this.currentTab = 'support'; }
    handleNavProfile() { this.currentTab = 'profile'; }

    handleProjectSelected(event) {
        this.selectedProjectId = event.detail.projectId;
        this.currentTab = 'project-details';
    }

    handleViewProjectInventory(event) {
        this.selectedProjectId = event.detail.projectId;
        this.currentTab = 'inventory';
    }

    handleRegisterLeadForProject(event) {
        this.selectedProjectId = event.detail.projectId;
        this.showRegisterLeadModal = true;
    }

    handleChildNavigation(event) {
        const target = event.detail.target;
        if (target) {
            this.currentTab = target;
        }
    }

    handleOpenRegisterLeadModal() {
        this.showRegisterLeadModal = true;
    }

    handleCloseRegisterLeadModal() {
        this.showRegisterLeadModal = false;
    }

    handleRegistrationSuccess() {
        this.showRegisterLeadModal = false;
        this.currentTab = 'leads';
    }
}
