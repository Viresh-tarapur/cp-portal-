import { LightningElement, track, wire } from 'lwc';
import getMySiteVisits from '@salesforce/apex/SiteVisitController.getMySiteVisits';
import { refreshApex } from '@salesforce/apex';

export default class CpSiteVisitList extends LightningElement {
    @track visits = [];
    @track isLoading = true;
    @track showScheduleModal = false;
    wiredVisitsResult;

    @wire(getMySiteVisits)
    wiredVisits(result) {
        this.wiredVisitsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.visits = result.data.map(v => {
                const status = v.Status__c ? v.Status__c.toLowerCase() : '';
                return {
                    ...v,
                    statusBadgeClass: `badge-status badge-${status}`
                };
            });
        } else if (result.error) {
            console.error('Error fetching site visits', result.error);
        }
    }

    get hasVisits() {
        return this.visits && this.visits.length > 0;
    }

    handleOpenScheduleModal() {
        this.showScheduleModal = true;
    }

    handleCloseScheduleModal() {
        this.showScheduleModal = false;
    }

    handleVisitScheduledSuccess() {
        this.showScheduleModal = false;
        refreshApex(this.wiredVisitsResult);
    }
}
