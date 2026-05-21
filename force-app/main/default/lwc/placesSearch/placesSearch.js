import { LightningElement, track } from 'lwc';
import searchPlaces from '@salesforce/apex/PlacesSearchController.searchPlaces';

export default class PlacesSearch extends LightningElement {

    @track searchQuery = '';
    @track searchResults = [];
    @track mapMarkers = null;
    @track selectedPlace = null;
    @track errorMessage = '';
    @track showResults = false;
    @track showDetailsScreen = false;

    @track operatingAddress = '';
    @track floor = '';
    @track additionalDirection = '';
    @track uploadedFileName = '';

    // Fixed 500px — reliable across all Salesforce page types
    mapStyle = 'height:100%;width:100%;display:block;';
    showFooter = false;
    zoomLevel = 14;

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
    handleFloorInput(event) { this.floor = event.target.value; }
    handleDirectionInput(event) { this.additionalDirection = event.target.value; }

    handleUploadClick() {
        this.template.querySelector('.file-input').click();
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) this.uploadedFileName = file.name;
    }

    handleSubmit() {
        console.log('Submitting:', {
            location: this.selectedPlace,
            operatingAddress: this.operatingAddress,
            floor: this.floor,
            additionalDirection: this.additionalDirection,
            file: this.uploadedFileName
        });
    }
}