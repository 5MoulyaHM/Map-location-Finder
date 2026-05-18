import { LightningElement, track, api, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { getBarcodeScanner } from 'lightning/mobileCapabilities';
import saveCardId from '@salesforce/apex/PrepaidCardController.saveCardId';
import validateCardId from '@salesforce/apex/PrepaidCardController.validateCardId';
import getApplicationDetails from '@salesforce/apex/PrepaidCardController.getApplicationDetails';
import JSQR from '@salesforce/resourceUrl/jsQR';

export default class QrScanner extends LightningElement {

    @api recordId;

    @track cardId            = null;
    @track errorMessage      = null;
    @track validating        = false;
    @track cardValid         = false;
    @track cardInvalid       = false;
    @track validationMessage = null;
    @track alreadyAssigned   = false;
    @track existingCardId    = null;
    @track isMobileReady     = false;
    @track scanning          = false; // desktop webcam active

    barcodeScanner = null;
    stream         = null;
    scanInterval   = null;
    jsQRLoaded     = false;
    wiredAppResult = null;

    // ─── Load existing card on page open ────────────────────────────
    @wire(getApplicationDetails, { recordId: '$recordId' })
    wiredApp({ data, error }) {
        if (data) {
            this.wiredAppResult = data;
            if (data.Card_Assigned__c && data.Card_ID__c) {
                this.alreadyAssigned = true;
                this.existingCardId  = data.Card_ID__c;
            } else {
                this.alreadyAssigned = false;
                this.existingCardId  = null;
            }
        }
        if (error) {
            console.error('Error loading application:', error);
        }
    }

    // ─── On load: detect device and load jsQR for desktop ───────────
connectedCallback() {
    // Detect mobile by user agent — reliable on all devices
    const isMobileDevice = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
    console.log('userAgent:', navigator.userAgent);
    console.log('isMobileDevice:', isMobileDevice);

    this.barcodeScanner = getBarcodeScanner();

    // Use BarcodeScanner only on mobile AND if available
    this.isMobileReady = isMobileDevice && this.barcodeScanner != null;
    console.log('isMobileReady:', this.isMobileReady);

    // Load jsQR only for desktop
    if (!this.isMobileReady) {
        loadScript(this, JSQR)
            .then(() => {
                console.log('jsQR loaded successfully');
                this.jsQRLoaded = true;
            })
            .catch(() => {
                this.errorMessage = 'QR scanner library failed to load. Please refresh the page.';
            });
    }
}

    // ─── Main button: routes to mobile or desktop ────────────────────
    startScan() {
        this.errorMessage = null;
        this.cardId       = null;
        this.cardValid    = false;
        this.cardInvalid  = false;
        console.log('OUTPUT : startScan: ');

        // Use BarcodeScanner only if it exists AND is actually available
        // isAvailable() returns false on desktop/browser even if object exists
        const useMobile = this.barcodeScanner != null && this.barcodeScanner.isAvailable();
        console.log('startScan — useMobile:', useMobile);

        if (useMobile) {
            this.startMobileScan();
        } else {
            this.startDesktopScan();
        }
    }

    // ─── MOBILE: Salesforce native BarcodeScanner ────────────────────
    startMobileScan() {
        if (this.barcodeScanner.isAvailable()) {
            const options = {
                barcodeTypes: [ this.barcodeScanner.barcodeTypes.QR ],
                instructionText: 'Point camera at the card QR code',
                successText: 'QR Code scanned!'
            };

            this.barcodeScanner.beginCapture(options)
                .then((result) => {
                    this.cardId = result.value;
                    this.validateCard(result.value);
                })
                .catch((error) => {
                    if (error.code && error.code === 'USER_DISMISSED') return;
                    this.errorMessage = 'Scan failed: ' + error.message;
                })
                .finally(() => {
                    this.barcodeScanner.endCapture();
                });
        } else {
            this.errorMessage = 'Barcode scanner is not available right now. Please try again.';
        }
    }

    // ─── DESKTOP: webcam + jsQR ──────────────────────────────────────
    async startDesktopScan() {

        // jsQR may still be loading — wait up to 5 seconds
        console.log('OUTPUT : startDesktopScan:');
        let waited = 0;
        while (!this.jsQRLoaded && waited < 5000) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            await new Promise(resolve => setTimeout(resolve, 300));
            waited += 300;
        }

        if (!this.jsQRLoaded) {
            this.errorMessage = 'Scanner not ready. Please refresh the page and try again.';
            return;
        }

        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            this.errorMessage = 'Camera not supported. Please use Chrome or Edge.';
            return;
        }

        try {
            this.stream = await navigator.mediaDevices.getUserMedia({
                video: {
                    facingMode: 'environment',
                    width: { ideal: 1280 },
                    height: { ideal: 720 }
                }
            });

            this.scanning = true;

            // Wait for DOM to fully render the video element after scanning=true
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            await new Promise(resolve => setTimeout(resolve, 500));

            const video = this.refs.videoEl;
            if (!video) {
                this.errorMessage = 'Camera view failed to load. Please try again.';
                this.stopDesktopCamera();
                return;
            }

            video.srcObject = this.stream;
            video.setAttribute('playsinline', true);
            video.play();
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this.scanInterval = setInterval(() => this.scanFrame(), 300);

        } catch (err) {
            this.scanning = false;
            if (err.name === 'NotAllowedError') {
                this.errorMessage = 'Camera permission denied. Click the camera icon in your browser address bar → Allow → try again.';
            } else if (err.name === 'NotFoundError') {
                this.errorMessage = 'No camera found on this device.';
            } else {
                this.errorMessage = 'Could not open camera: ' + err.message;
            }
        }
    }

    // ─── DESKTOP: read one frame ─────────────────────────────────────
    scanFrame() {
        const video  = this.refs.videoEl;
        const canvas = this.refs.canvasEl;

        if (!video || !canvas || !this.scanning) return;
        if (video.readyState !== 4) return;

        const vw = video.videoWidth;
        const vh = video.videoHeight;
        if (!vw || !vh) return;

        // Scale down for faster jsQR processing
        const scale  = Math.min(1, 600 / vw);
        const width  = Math.floor(vw * scale);
        const height = Math.floor(vh * scale);

        canvas.width  = width;
        canvas.height = height;

        const ctx = canvas.getContext('2d', { willReadFrequently: true });
        ctx.drawImage(video, 0, 0, width, height);

        let imageData;
        try {
            imageData = ctx.getImageData(0, 0, width, height);
        } catch(e) { return; }

        // eslint-disable-next-line no-undef
        const code = jsQR(imageData.data, imageData.width, imageData.height, {
            inversionAttempts: 'attemptBoth'
        });

        if (code && code.data) {
            this.stopDesktopCamera();
            this.cardId = code.data;
            this.validateCard(code.data);
        }
    }

    // ─── DESKTOP: stop webcam ────────────────────────────────────────
    stopDesktopCamera() {
        this.scanning = false;

        if (this.scanInterval) {
            clearInterval(this.scanInterval);
            this.scanInterval = null;
        }
        if (this.stream) {
            this.stream.getTracks().forEach(t => t.stop());
            this.stream = null;
        }
    }

    // ─── Validate scanned card ───────────────────────────────────────
    async validateCard(scannedCardId) {
        this.validating  = true;
        this.cardValid   = false;
        this.cardInvalid = false;

        try {
            const result = await validateCardId({ cardId: scannedCardId });
            this.validating = false;

            if (result === 'VALID') {
                this.cardValid = true;
            } else if (result === 'ALREADY_ASSIGNED') {
                this.cardInvalid = true;
                this.validationMessage = 'This card is already assigned to another merchant. Please scan a different card.';
            } else if (result === 'NOT_FOUND') {
                this.cardInvalid = true;
                this.validationMessage = 'This card ID was not found in the system. Please check with your administrator.';
            }
        } catch (error) {
            this.validating = false;
            this.cardInvalid = true;
            this.validationMessage = 'Could not validate card. Please try again.';
        }
    }

    // ─── Save card ID to Salesforce ──────────────────────────────────
    async saveCardId() {
        if (!this.cardId || !this.recordId) return;

        try {
            await saveCardId({ recordId: this.recordId, cardId: this.cardId });
            await refreshApex(this.wiredAppResult);

            this.dispatchEvent(new ShowToastEvent({
                title: 'Card Assigned!',
                message: 'Card ID ' + this.cardId + ' saved successfully.',
                variant: 'success'
            }));

            this.cardId      = null;
            this.cardValid   = false;
            this.cardInvalid = false;

        } catch (error) {
            this.errorMessage = 'Failed to save Card ID. Please try again.';
        }
    }

    // ─── Reset ───────────────────────────────────────────────────────
    resetScanner() {
        this.stopDesktopCamera();
        this.cardId            = null;
        this.errorMessage      = null;
        this.validating        = false;
        this.cardValid         = false;
        this.cardInvalid       = false;
        this.validationMessage = null;
    }

    disconnectedCallback() {
        this.stopDesktopCamera();
    }
}