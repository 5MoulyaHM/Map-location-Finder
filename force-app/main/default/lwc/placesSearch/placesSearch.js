<<<<<<< HEAD
import { LightningElement, track, api } from 'lwc';
import searchPlaces       from '@salesforce/apex/PlacesSearchController.searchPlaces';
import saveLocationToContact from '@salesforce/apex/PlacesSearchController.saveLocationToContact';
import saveFileToContact  from '@salesforce/apex/PlacesSearchController.saveFileToContact';

export default class PlacesSearch extends LightningElement {

    @api recordId; // Contact Id — auto-populated on Contact record page

=======
import { LightningElement, track } from 'lwc';
import searchPlaces from '@salesforce/apex/PlacesSearchController.searchPlaces';

export default class PlacesSearch extends LightningElement {

>>>>>>> c46ce70c2770fb0e2fe5ba3d083b78b242634dbb
    @track searchQuery = '';
    @track searchResults = [];
    @track mapMarkers = null;
    @track selectedPlace = null;
    @track errorMessage = '';
    @track showResults = false;
    @track showDetailsScreen = false;
<<<<<<< HEAD
    @track isSaving = false;
    @track saveSuccess = false;
=======
>>>>>>> c46ce70c2770fb0e2fe5ba3d083b78b242634dbb

    @track operatingAddress = '';
    @track floor = '';
    @track additionalDirection = '';
    @track uploadedFileName = '';

<<<<<<< HEAD
    // File data
    fileBase64 = null;
    fileType = null;
    fileName = null;

    mapStyle = 'height:500px;width:100%;display:block;';
    showFooter = false;
    zoomLevel = 14;

    // Store lat/lng from selected place
    selectedLat = null;
    selectedLng = null;

=======
    // Fixed 500px — reliable across all Salesforce page types
    mapStyle = 'height:100%;width:100%;display:block;';
    showFooter = false;
    zoomLevel = 14;

>>>>>>> c46ce70c2770fb0e2fe5ba3d083b78b242634dbb
    defaultMarkers = [
        { location: { Latitude: 25.2048, Longitude: 55.2708 } }
    ];

    get activeMarkers() {
        return this.mapMarkers || this.defaultMarkers;
    }

    handleInput(event) {
        this.searchQuery = event.target.value;
        this.errorMessage = '';

        if (!this.searchQuery || this.searchQuery.trim().length < 3) {
            this.showResults = false;
            this.searchResults = [];
            return;
        }

        searchPlaces({ query: this.searchQuery })
            .then(results => {
                if (results && results.length > 0) {
                    this.searchResults = results;
                    this.showResults = true;
                } else {
                    this.searchResults = [];
                    this.showResults = false;
                }
            })
            .catch(error => {
                this.errorMessage = 'Error: ' + (error.body ? error.body.message : error.message);
                this.showResults = false;
            });
    }

    handleSelectPlace(event) {
        const name    = event.currentTarget.dataset.name;
        const address = event.currentTarget.dataset.address;
        const lat     = parseFloat(event.currentTarget.dataset.lat);
        const lng     = parseFloat(event.currentTarget.dataset.lng);

        this.selectedPlace = { name, address };
<<<<<<< HEAD
        this.selectedLat = lat;
        this.selectedLng = lng;

=======
>>>>>>> c46ce70c2770fb0e2fe5ba3d083b78b242634dbb
        this.mapMarkers = [
            {
                location: { Latitude: lat, Longitude: lng },
                title: name,
                description: address
            }
        ];
        this.showResults = false;
        this.searchQuery = address;
    }

    handleCurrentLocation() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    const lat = position.coords.latitude;
                    const lng = position.coords.longitude;
<<<<<<< HEAD
                    this.selectedLat = lat;
                    this.selectedLng = lng;
=======
>>>>>>> c46ce70c2770fb0e2fe5ba3d083b78b242634dbb
                    this.mapMarkers = [
                        { location: { Latitude: lat, Longitude: lng }, title: 'Current Location' }
                    ];
                    this.selectedPlace = {
                        name: 'Current Location',
                        address: `${lat.toFixed(4)}, ${lng.toFixed(4)}`
                    };
                },
                () => {
                    this.errorMessage = 'Unable to retrieve your location.';
                }
            );
        }
    }

    handleConfirm() {
        if (!this.selectedPlace) {
            this.errorMessage = 'Please select a location first.';
            return;
        }
        this.errorMessage = '';
        this.showDetailsScreen = true;
    }

    handleBack() {
        this.showDetailsScreen = false;
    }

    handleAddressInput(event) { this.operatingAddress = event.target.value; }
<<<<<<< HEAD
    handleFloorInput(event)   { this.floor = event.target.value; }
=======
    handleFloorInput(event) { this.floor = event.target.value; }
>>>>>>> c46ce70c2770fb0e2fe5ba3d083b78b242634dbb
    handleDirectionInput(event) { this.additionalDirection = event.target.value; }

    handleUploadClick() {
        this.template.querySelector('.file-input').click();
    }

    handleFileChange(event) {
        const file = event.target.files[0];
<<<<<<< HEAD
        if (!file) return;

        this.uploadedFileName = file.name;
        this.fileType = file.type;
        this.fileName = file.name;

        // Read file as base64
        const reader = new FileReader();
        reader.onload = () => {
            // Strip data URL prefix e.g. "data:application/pdf;base64,"
            this.fileBase64 = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    handleSubmit() {
        if (!this.recordId) {
            this.errorMessage = 'No Contact record found. Please open this from a Contact page.';
            return;
        }

        this.isSaving = true;
        this.errorMessage = '';

        // Step 1: Save location fields to Contact
        saveLocationToContact({
            contactId:           this.recordId,
            placeName:           this.selectedPlace.name,
            address:             this.selectedPlace.address,
            floor:               this.floor,
            additionalDirection: this.additionalDirection,
            latitude:            this.selectedLat,
            longitude:           this.selectedLng
        })
        .then(() => {
            // Step 2: Upload file if one was selected
            if (this.fileBase64) {
                return saveFileToContact({
                    contactId:   this.recordId,
                    fileName:    this.fileName,
                    base64Data:  this.fileBase64,
                    contentType: this.fileType
                });
            }
        })
        .then(() => {
            this.isSaving = false;
            this.saveSuccess = true;
        })
        .catch(error => {
            this.isSaving = false;
            this.errorMessage = 'Error saving: ' + (error.body ? error.body.message : error.message);
=======
        if (file) this.uploadedFileName = file.name;
    }

    handleSubmit() {
        console.log('Submitting:', {
            location: this.selectedPlace,
            operatingAddress: this.operatingAddress,
            floor: this.floor,
            additionalDirection: this.additionalDirection,
            file: this.uploadedFileName
>>>>>>> c46ce70c2770fb0e2fe5ba3d083b78b242634dbb
        });
    }
}