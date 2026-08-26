import { LightningElement, track, wire } from 'lwc';
import getKycStatus from '@salesforce/apex/KycController.getKycStatus';
import submitKycDocument from '@salesforce/apex/KycController.submitKycDocument';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CpKyc extends LightningElement {
    @track kycData = null;
    @track documents = [];
    @track overallKycStatus = 'Pending';
    @track isLoading = true;

    @track newDoc = {
        docType: '',
        docNumber: '',
        contentDocumentId: '',
        fileName: ''
    };
    @track uploadedFileName = '';

    wiredKycResult;

    docTypeOptions = [
        { label: 'PAN Card', value: 'PAN' },
        { label: 'GST Registration Certificate', value: 'GST' },
        { label: 'Bank Account Proof / Cheque', value: 'Bank Proof' },
        { label: 'RERA Agent Certificate', value: 'RERA Certificate' },
        { label: 'Company Registration / Incorporation', value: 'Company Registration' },
        { label: 'Address Proof', value: 'Address Proof' },
        { label: 'Channel Partner Agreement', value: 'Agreement' },
        { label: 'Other Document', value: 'Other' }
    ];

    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg'];

    @wire(getKycStatus)
    wiredKyc(result) {
        this.wiredKycResult = result;
        this.isLoading = false;
        if (result.data) {
            this.kycData = result.data;
            this.overallKycStatus = result.data.kycStatus || 'Pending';
            this.documents = (result.data.documents || []).map(d => {
                const status = d.Document_Status__c ? d.Document_Status__c.toLowerCase().replace(' ', '-') : '';
                return {
                    ...d,
                    formattedDate: d.Uploaded_Date__c ? d.Uploaded_Date__c.slice(0, 10) : '',
                    statusBadgeClass: `status-badge badge-${status}`
                };
            });
        } else if (result.error) {
            console.error('Error fetching KYC status', result.error);
        }
    }

    get isKycPending() {
        return this.overallKycStatus === 'Pending';
    }

    get isKycUnderReview() {
        return this.overallKycStatus === 'Under Review' || this.overallKycStatus === 'Submitted';
    }

    get isKycApproved() {
        return this.overallKycStatus === 'Approved';
    }

    get overallKycBadgeClass() {
        const s = this.overallKycStatus.toLowerCase().replace(' ', '-');
        return `kyc-header-badge badge-${s}`;
    }

    get hasDocuments() {
        return this.documents && this.documents.length > 0;
    }

    // Checklist Helpers
    get panStatusText() {
        const d = this.documents.find(doc => doc.Document_Type__c === 'PAN');
        return d ? d.Document_Status__c : 'Not Uploaded';
    }
    get panBadgeClass() {
        const s = this.panStatusText.toLowerCase().replace(' ', '-');
        return `chk-badge chk-${s}`;
    }
    get panStatusIconClass() {
        return this.panStatusText === 'Verified' ? 'chk-dot dot-verified' : 'chk-dot dot-pending';
    }

    get bankStatusText() {
        const d = this.documents.find(doc => doc.Document_Type__c === 'Bank Proof');
        return d ? d.Document_Status__c : 'Not Uploaded';
    }
    get bankBadgeClass() {
        const s = this.bankStatusText.toLowerCase().replace(' ', '-');
        return `chk-badge chk-${s}`;
    }
    get bankStatusIconClass() {
        return this.bankStatusText === 'Verified' ? 'chk-dot dot-verified' : 'chk-dot dot-pending';
    }

    get gstStatusText() {
        const d = this.documents.find(doc => doc.Document_Type__c === 'GST');
        return d ? d.Document_Status__c : 'Optional';
    }
    get gstBadgeClass() {
        const s = this.gstStatusText.toLowerCase().replace(' ', '-');
        return `chk-badge chk-${s}`;
    }
    get gstStatusIconClass() {
        return this.gstStatusText === 'Verified' ? 'chk-dot dot-verified' : 'chk-dot dot-optional';
    }

    get reraStatusText() {
        const d = this.documents.find(doc => doc.Document_Type__c === 'RERA Certificate');
        return d ? d.Document_Status__c : 'Optional';
    }
    get reraBadgeClass() {
        const s = this.reraStatusText.toLowerCase().replace(' ', '-');
        return `chk-badge chk-${s}`;
    }
    get reraStatusIconClass() {
        return this.reraStatusText === 'Verified' ? 'chk-dot dot-verified' : 'chk-dot dot-optional';
    }

    get isSubmitDisabled() {
        return !this.newDoc.docType || !this.newDoc.contentDocumentId;
    }

    handleDocTypeChange(event) {
        this.newDoc.docType = event.target.value;
    }

    handleDocNumberChange(event) {
        this.newDoc.docNumber = event.target.value;
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            this.newDoc.contentDocumentId = uploadedFiles[0].documentId;
            this.newDoc.fileName = uploadedFiles[0].name;
            this.uploadedFileName = uploadedFiles[0].name;

            this.dispatchEvent(new ShowToastEvent({
                title: 'File Uploaded',
                message: `${uploadedFiles[0].name} attached successfully. Click Submit to finish.`,
                variant: 'success'
            }));
        }
    }

    handleSubmitDocument() {
        if (!this.newDoc.docType) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: 'Please select a document type.',
                variant: 'error'
            }));
            return;
        }

        this.isLoading = true;
        submitKycDocument({
            documentType: this.newDoc.docType,
            documentNumber: this.newDoc.docNumber,
            contentDocumentId: this.newDoc.contentDocumentId,
            fileName: this.newDoc.fileName
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'KYC Document submitted for verification.',
                variant: 'success'
            }));
            this.newDoc = { docType: '', docNumber: '', contentDocumentId: '', fileName: '' };
            this.uploadedFileName = '';
            return refreshApex(this.wiredKycResult);
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error Submitting Document',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        })
        .finally(() => {
            this.isLoading = false;
        });
    }
}
