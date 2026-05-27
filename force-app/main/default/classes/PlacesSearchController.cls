public with sharing class PlacesSearchController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchPlaces(String query) {

        String endpoint = 'callout:Google_Places_API/v1/places:searchText';

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-Goog-FieldMask', 'places.displayName,places.formattedAddress,places.location');
        req.setBody('{"textQuery": "' + query + '"}');
        req.setTimeout(10000);

        HttpResponse res = http.send(req);
        List<Map<String, String>> results = new List<Map<String, String>>();

        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> places = (List<Object>) body.get('places');

            if (places != null) {
                for (Object place : places) {
                    try {
                        Map<String, Object> p = (Map<String, Object>) place;
                        Map<String, Object> displayName = (Map<String, Object>) p.get('displayName');
                        Map<String, Object> location = (Map<String, Object>) p.get('location');

                        if (displayName == null || location == null) continue;

                        Map<String, String> placeData = new Map<String, String>();
                        placeData.put('name', (String) displayName.get('text'));
                        placeData.put('address', p.get('formattedAddress') != null ? (String) p.get('formattedAddress') : '');
                        placeData.put('lat', String.valueOf(location.get('latitude')));
                        placeData.put('lng', String.valueOf(location.get('longitude')));
                        results.add(placeData);

                    } catch (Exception e) {
                        System.debug('Skipping place record: ' + e.getMessage());
                    }
                }
            }
        }

        return results;
    }

    @AuraEnabled
    public static void saveLocationToContact(
        String contactId,
        String placeName,
        String address,
        String floor,
        String additionalDirection,
        Decimal latitude,
        Decimal longitude
    ) {
        try {
            Contact c = new Contact(Id = contactId);
            c.Place_Name__c             = placeName;
            c.Operating_Address__c      = address;
            c.Floor__c                  = floor;
            c.Additional_Direction__c   = additionalDirection;
            // Geolocation field — single field, two sub-fields
            c.Place_Location__Latitude__s  = latitude;
            c.Place_Location__Longitude__s = longitude;
            update c;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving location: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveFileToContact(
        String contactId,
        String fileName,
        String base64Data,
        String contentType
    ) {
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title          = fileName;
            cv.PathOnClient   = fileName;
            cv.VersionData    = EncodingUtil.base64Decode(base64Data);
            cv.IsMajorVersion = true;
            insert cv;

            ContentVersion inserted = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = inserted.ContentDocumentId;
            cdl.LinkedEntityId    = contactId;
            cdl.ShareType         = 'V';
            cdl.Visibility        = 'AllUsers';
            insert cdl;

        } catch (Exception e) {
            throw new AuraHandledException('Error uploading file: ' + e.getMessage());
        }
    }
}