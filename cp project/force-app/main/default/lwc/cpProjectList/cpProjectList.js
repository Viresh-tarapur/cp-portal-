import { LightningElement, track, wire } from 'lwc';
import getAuthorizedProjects from '@salesforce/apex/ProjectController.getAuthorizedProjects';

export default class CpProjectList extends LightningElement {
    @track projects = [];
    @track filteredProjects = [];
    @track searchKey = '';
    @track isLoading = true;

    @wire(getAuthorizedProjects)
    wiredProjects({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.projects = data;
            this.applyFilter();
        } else if (error) {
            console.error('Error fetching projects', error);
        }
    }

    get hasFilteredProjects() {
        return this.filteredProjects && this.filteredProjects.length > 0;
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value.toLowerCase();
        this.applyFilter();
    }

    applyFilter() {
        if (!this.searchKey) {
            this.filteredProjects = [...this.projects];
        } else {
            this.filteredProjects = this.projects.filter(p => 
                (p.Name && p.Name.toLowerCase().includes(this.searchKey)) ||
                (p.City__c && p.City__c.toLowerCase().includes(this.searchKey)) ||
                (p.Location__c && p.Location__c.toLowerCase().includes(this.searchKey)) ||
                (p.Project_Type__c && p.Project_Type__c.toLowerCase().includes(this.searchKey))
            );
        }
    }

    handleSelectProject(event) {
        const projectId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('selectproject', {
            detail: { projectId: projectId },
            bubbles: true,
            composed: true
        }));
    }
}
