@isTest
private class PlacesSearchControllerTest {

    // ─────────────────────────────────────────────
    // Mock HTTP callout helpers
    // ─────────────────────────────────────────────

    private class PlacesMockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{' +
                '"places": [' +
                    '{' +
                        '"displayName": {"text": "Test Cafe"},' +
                        '"formattedAddress": "123 Main St, Springfield",' +
                        '"location": {"latitude": 37.7749, "longitude": -122.4194}' +
                    '},' +
                    '{' +
                        '"displayName": {"text": "No Address Cafe"},' +
                        '"location": {"latitude": 34.0522, "longitude": -118.2437}' +
                    '}' +
                ']' +
            '}');
            return res;
        }
    }

    private class PlacesMockNoPlaces implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{}');
            return res;
        }
    }

    private class PlacesMockEmptyPlaces implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"places": []}');
            return res;
        }
    }

    private class PlacesMockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private class PlacesMockNullDisplayName implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{' +
                '"places": [' +
                    '{"formattedAddress": "456 Elm St", "location": {"latitude": 1.0, "longitude": 2.0}}' +
                ']' +
            '}');
            return res;
        }
    }

    // ─────────────────────────────────────────────
    // searchPlaces tests
    // ─────────────────────────────────────────────

    @isTest
    static void testSearchPlaces_success() {
        System.Test.setMock(HttpCalloutMock.class, new PlacesMockSuccess());
        System.Test.startTest();
        List<Map<String, String>> results = PlacesSearchController.searchPlaces('cafe near me');
        System.Test.stopTest();

        System.assertEquals(2, results.size(), 'Expected two place results');
        Map<String, String> first = results[0];
        System.assertEquals('Test Cafe', first.get('name'));
        System.assertEquals('123 Main St, Springfield', first.get('address'));
        System.assert(first.get('lat').contains('37'), 'Latitude should contain 37');
        System.assert(first.get('lng').contains('-122'), 'Longitude should contain -122');
    }

    @isTest
    static void testSearchPlaces_missingFormattedAddress_defaultsToEmpty() {
        System.Test.setMock(HttpCalloutMock.class, new PlacesMockSuccess());
        System.Test.startTest();
        List<Map<String, String>> results = PlacesSearchController.searchPlaces('cafe');
        System.Test.stopTest();

        Map<String, String> second = results[1];
        System.assertEquals('No Address Cafe', second.get('name'));
        System.assertEquals('', second.get('address'), 'Missing address should default to empty string');
    }

    @isTest
    static void testSearchPlaces_noPlacesKey_returnsEmpty() {
        System.Test.setMock(HttpCalloutMock.class, new PlacesMockNoPlaces());
        System.Test.startTest();
        List<Map<String, String>> results = PlacesSearchController.searchPlaces('nowhere');
        System.Test.stopTest();

        System.assertEquals(0, results.size(), 'No places key should return empty list');
    }

    @isTest
    static void testSearchPlaces_emptyPlacesArray_returnsEmpty() {
        System.Test.setMock(HttpCalloutMock.class, new PlacesMockEmptyPlaces());
        System.Test.startTest();
        List<Map<String, String>> results = PlacesSearchController.searchPlaces('ghost town');
        System.Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty places array should return empty list');
    }

    @isTest
    static void testSearchPlaces_nonOkStatus_returnsEmpty() {
        System.Test.setMock(HttpCalloutMock.class, new PlacesMockError());
        System.Test.startTest();
        List<Map<String, String>> results = PlacesSearchController.searchPlaces('anything');
        System.Test.stopTest();

        System.assertEquals(0, results.size(), '500 response should return empty list');
    }

    @isTest
    static void testSearchPlaces_nullDisplayName_skipsRecord() {
        System.Test.setMock(HttpCalloutMock.class, new PlacesMockNullDisplayName());
        System.Test.startTest();
        List<Map<String, String>> results = PlacesSearchController.searchPlaces('broken data');
        System.Test.stopTest();

        System.assertEquals(0, results.size(), 'Record with null displayName should be skipped');
    }

    // ─────────────────────────────────────────────
    // saveLocationToContact tests
    // ─────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        Contact c = new Contact(LastName = 'TestContact');
        insert c;
    }

    @isTest
    static void testSaveLocationToContact_success() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        System.Test.startTest();
        PlacesSearchController.saveLocationToContact(
            c.Id, 'My Place', '789 Oak Ave, Shelbyville',
            '3rd Floor', 'Near the elevator', 37.7749, -122.4194
        );
        System.Test.stopTest();

        Contact updated = [
            SELECT Place_Name__c, Operating_Address__c, Floor__c,
                   Additional_Direction__c,
                   Place_Location__Latitude__s, Place_Location__Longitude__s
            FROM Contact WHERE Id = :c.Id
        ];

        System.assertEquals('My Place', updated.Place_Name__c);
        System.assertEquals('789 Oak Ave, Shelbyville', updated.Operating_Address__c);
        System.assertEquals('3rd Floor', updated.Floor__c);
        System.assertEquals('Near the elevator', updated.Additional_Direction__c);
        System.assertEquals(37.7749, updated.Place_Location__Latitude__s);
        System.assertEquals(-122.4194, updated.Place_Location__Longitude__s);
    }

    @isTest
    static void testSaveLocationToContact_invalidId_throwsAuraHandledException() {
        Boolean exceptionThrown = false;

        System.Test.startTest();
        try {
            PlacesSearchController.saveLocationToContact(
                'INVALID_ID', 'Bad Place', 'Bad Address', '', '', 0, 0
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
           
        }
        System.Test.stopTest();

        System.assert(exceptionThrown, 'Expected AuraHandledException for bad contact Id');
    }

    // ─────────────────────────────────────────────
    // saveFileToContact tests
    // ─────────────────────────────────────────────

    @isTest
    static void testSaveFileToContact_success() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Hello test file'));

        System.Test.startTest();
        PlacesSearchController.saveFileToContact(c.Id, 'test_file.txt', base64Data, 'text/plain');
        System.Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, links.size(), 'Expected one ContentDocumentLink on the Contact');

        ContentVersion cv = [
            SELECT Title, PathOnClient FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId LIMIT 1
        ];
        System.assertEquals('test_file.txt', cv.Title);
        System.assertEquals('test_file.txt', cv.PathOnClient);
    }

    @isTest
    static void testSaveFileToContact_invalidBase64_throwsAuraHandledException() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Boolean exceptionThrown = false;

        System.Test.startTest();
        try {
            PlacesSearchController.saveFileToContact(
                c.Id, 'bad.txt', '!!!NOT_VALID_BASE64!!!', 'text/plain'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
           
        }
        System.Test.stopTest();

        System.assert(exceptionThrown, 'Expected AuraHandledException for invalid base64');
    }
}