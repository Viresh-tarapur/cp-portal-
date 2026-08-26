import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getBookingDetails from '@salesforce/apex/BookingPaymentPlanController.getBookingDetails';
import previewSchedules from '@salesforce/apex/BookingPaymentPlanController.previewSchedules';
import activatePaymentPlan from '@salesforce/apex/BookingPaymentPlanController.activatePaymentPlan';

export default class BookingPaymentPlan extends LightningElement {
    @api recordId;

    @track booking = {};
    @track schedules = [];
    @track hasModifyAccess = false;
    @track isLoading = false;
    @track isConfiguring = false;
    
    @track totalAmount = 0;
    @track planType = '';
    @track months = 12;
    @track errorMessage = '';
    @track schedulePreview = [];

    planOptions = [
        { label: 'Full Amount', value: 'Full Amount' },
        { label: 'Monthly Payment', value: 'Monthly Payment' }
    ];

    connectedCallback() {
        this.fetchBookingData();
    }

    fetchBookingData() {
        this.isLoading = true;
        this.errorMessage = '';
        getBookingDetails({ bookingId: this.recordId })
            .then(result => {
                this.booking = result.booking || {};
                this.schedules = result.schedules || [];
                this.hasModifyAccess = result.hasModifyAccess;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.errorMessage = error.body ? error.body.message : 'Error fetching Booking details';
            });
    }

    get isActivated() {
        return this.booking && this.booking.Payment_Plan_Activated__c;
    }

    get isMonthly() {
        return this.planType === 'Monthly Payment';
    }

    get isMonthlyPlanActivated() {
        return this.booking && this.booking.Payment_Plan_Type__c === 'Monthly Payment';
    }

    get monthlyInstallment() {
        // Calculate dynamic monthly installment for preview
        let preservedCount = 0;
        let preservedTotal = 0;
        if (this.schedules) {
            this.schedules.forEach(sch => {
                if (sch.Paid_Amount__c > 0 || sch.Status__c === 'Paid' || sch.Status__c === 'Partially Paid') {
                    preservedCount++;
                    preservedTotal += (sch.Amount__c || 0);
                }
            });
        }
        let remaining = this.totalAmount - preservedTotal;
        if (remaining < 0) remaining = 0;
        let futureMonths = this.months - preservedCount;
        if (futureMonths <= 0) futureMonths = 1;

        if (remaining && futureMonths && futureMonths > 0) {
            return (remaining / futureMonths);
        }
        return 0;
    }

    get isActivateDisabled() {
        if (!this.totalAmount || this.totalAmount <= 0) return true;
        if (this.planType === 'Monthly Payment' && (!this.months || this.months <= 0)) return true;
        return false;
    }

    handleStartConfig() {
        this.errorMessage = '';
        this.isConfiguring = true;
        
        // Initialize config inputs with existing values or fallbacks
        this.totalAmount = this.booking.Total_Property_Plot_Amount__c || this.booking.Booking_Amount__c || 0;
        this.planType = this.booking.Payment_Plan_Type__c || 'Full Amount';
        this.months = this.booking.Payment_Plan_Months__c || 12;
        
        this.fetchPreview();
    }

    handleCancelConfig() {
        this.isConfiguring = false;
        this.schedulePreview = [];
        this.errorMessage = '';
    }

    handleAmountChange(event) {
        this.totalAmount = parseFloat(event.target.value) || 0;
        this.fetchPreview();
    }

    handlePlanTypeChange(event) {
        this.planType = event.target.value;
        this.fetchPreview();
    }

    handleMonthsChange(event) {
        this.months = parseInt(event.target.value, 10) || 0;
        this.fetchPreview();
    }

    fetchPreview() {
        if (this.totalAmount <= 0) {
            this.schedulePreview = [];
            return;
        }
        if (this.planType === 'Monthly Payment' && this.months <= 0) {
            this.schedulePreview = [];
            return;
        }

        previewSchedules({
            bookingId: this.recordId,
            planType: this.planType,
            months: this.months,
            totalAmount: this.totalAmount
        })
        .then(result => {
            this.schedulePreview = result;
            this.errorMessage = '';
        })
        .catch(error => {
            this.schedulePreview = [];
            this.errorMessage = error.body ? error.body.message : 'Error generating schedule preview';
        });
    }

    handleActivatePlan() {
        this.isLoading = true;
        this.errorMessage = '';

        activatePaymentPlan({
            bookingId: this.recordId,
            planType: this.planType,
            months: this.months,
            totalAmount: this.totalAmount
        })
        .then(result => {
            this.booking = result.booking || {};
            this.schedules = result.schedules || [];
            this.hasModifyAccess = result.hasModifyAccess;
            this.isConfiguring = false;
            this.schedulePreview = [];
            this.isLoading = false;
            this.showToast('Success', 'Payment Plan activated successfully!', 'success');
        })
        .catch(error => {
            this.isLoading = false;
            this.errorMessage = error.body ? error.body.message : 'Error activating payment plan';
            this.showToast('Error', this.errorMessage, 'error');
        });
    }

    handleModifyPlan() {
        this.handleStartConfig();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}
