import { LightningElement, api, track, wire } from 'lwc';
import getAuthorizedProjects from '@salesforce/apex/ProjectController.getAuthorizedProjects';
import getInventory from '@salesforce/apex/InventoryController.getInventory';
import reserveInventoryUnit from '@salesforce/apex/InventoryController.reserveInventoryUnit';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CpInventory extends LightningElement {
    @api selectedProjectId;
    @track projectOptions = [];
    @track selectedStatus = 'All';
    @track selectedUnitType = 'All';
    @track units = [];
    @track isLoading = false;
    @track showReserveModal = false;
    @track selectedUnitForHold = null;

    statusOptions = [
        { label: 'All Statuses', value: 'All' },
        { label: 'Available', value: 'Available' },
        { label: 'Reserved', value: 'Reserved' },
        { label: 'Booked', value: 'Booked' }
    ];

    unitTypeOptions = [
        { label: 'All Unit Types', value: 'All' },
        { label: '1BHK', value: '1BHK' },
        { label: '2BHK', value: '2BHK' },
        { label: '3BHK', value: '3BHK' },
        { label: '4BHK', value: '4BHK' },
        { label: 'Penthouse', value: 'Penthouse' },
        { label: 'Villa', value: 'Villa' }
    ];

    @wire(getAuthorizedProjects)
    wiredProjects({ error, data }) {
        if (data) {
            this.projectOptions = data.map(p => ({ label: p.Name, value: p.Id }));
            if (!this.selectedProjectId && this.projectOptions.length > 0) {
                this.selectedProjectId = this.projectOptions[0].value;
            }
            if (this.selectedProjectId) {
                this.loadUnits();
            }
        }
    }

    connectedCallback() {
        if (this.selectedProjectId) {
            this.loadUnits();
        }
    }

    handleProjectChange(event) {
        this.selectedProjectId = event.target.value;
        this.loadUnits();
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value;
        this.loadUnits();
    }

    handleUnitTypeChange(event) {
        this.selectedUnitType = event.target.value;
        this.loadUnits();
    }

    loadUnits() {
        if (!this.selectedProjectId) return;

        this.isLoading = true;
        getInventory({
            projectId: this.selectedProjectId,
            statusFilter: this.selectedStatus,
            unitTypeFilter: this.selectedUnitType
        })
        .then(result => {
            this.units = result.map(u => {
                const isAvail = u.Status__c === 'Available';
                return {
                    ...u,
                    isAvailable: isAvail,
                    cardClass: `unit-card ${u.Status__c ? u.Status__c.toLowerCase() : ''}`,
                    statusBadgeClass: `status-chip-sm chip-${u.Status__c ? u.Status__c.toLowerCase() : 'avail'}`
                };
            });
            this.isLoading = false;
        })
        .catch(err => {
            this.isLoading = false;
            console.error('Error fetching inventory', err);
        });
    }

    get hasUnits() {
        return this.units && this.units.length > 0;
    }

    handleOpenReserveModal(event) {
        const unitId = event.currentTarget.dataset.id;
        this.selectedUnitForHold = this.units.find(u => u.Id === unitId);
        this.showReserveModal = true;
    }

    handleCloseReserveModal() {
        this.showReserveModal = false;
        this.selectedUnitForHold = null;
    }

    handleConfirmReservation() {
        if (!this.selectedUnitForHold) return;

        this.isLoading = true;
        reserveInventoryUnit({ unitId: this.selectedUnitForHold.Id, holdMinutes: 60 })
            .then(() => {
                this.isLoading = false;
                this.showReserveModal = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Unit Reserved Successfully',
                    message: `Unit ${this.selectedUnitForHold.Unit_Number__c} is now locked for your client for 60 minutes.`,
                    variant: 'success'
                }));
                this.loadUnits();
            })
            .catch(err => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Reservation Failed',
                    message: err.body ? err.body.message : err.message,
                    variant: 'error'
                }));
            });
    }
}
