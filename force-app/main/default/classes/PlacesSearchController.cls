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

                        // Skip if critical fields missing
                        if (displayName == null || location == null) continue;

                        Map<String, String> placeData = new Map<String, String>();
                        placeData.put('name', (String) displayName.get('text'));
                        placeData.put('address', p.get('formattedAddress') != null
                            ? (String) p.get('formattedAddress') : '');
                        placeData.put('lat', String.valueOf(location.get('latitude')));
                        placeData.put('lng', String.valueOf(location.get('longitude')));
                        results.add(placeData);

                    } catch (Exception e) {
                        // Skip any individual record that fails to parse
                        System.debug('Skipping place record: ' + e.getMessage());
                    }
                }
            }
        }

        return results;
    }
}