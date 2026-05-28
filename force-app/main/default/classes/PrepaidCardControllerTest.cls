@isTest
private class PrepaidCardControllerTest {

    // ══════════════════════════════════════════════
    //  Test Data Factory
    // ══════════════════════════════════════════════

    private static Merchant_Application__c createApplication() {
        Merchant_Application__c app = new Merchant_Application__c(
            Merchant_Name__c  = 'Test Merchant',
            Mobile_Number__c  = '0500000000',
            Email__c          = 'test@merchant.com',
            Business_Name__c  = 'Test Business',
            Status__c         = 'Pending'
        );
        insert app;
        return app;
    }

    private static Prepaid_Card__c createCard(String cardId, String status) {
        Prepaid_Card__c card = new Prepaid_Card__c(
            Card_ID__c     = cardId,
            Card_Status__c = status
        );
        insert card;
        return card;
    }


    // ══════════════════════════════════════════════
    //  saveCardId tests
    // ══════════════════════════════════════════════

    @isTest
    static void saveCardId_withMatchingPrepaidCard_updatesAppAndCard() {
        Merchant_Application__c app = createApplication();
        Prepaid_Card__c card        = createCard('CARD-001', 'Available');

        System.Test.startTest();
        PrepaidCardController.saveCardId(app.Id, 'CARD-001');
        System.Test.stopTest();

        Merchant_Application__c updatedApp = [
            SELECT Card_ID__c, Card_Assigned__c
            FROM Merchant_Application__c
            WHERE Id = :app.Id
        ];
        System.assertEquals('CARD-001', updatedApp.Card_ID__c,     'Card ID should be set on the application');
        System.assertEquals(true,       updatedApp.Card_Assigned__c, 'Card_Assigned__c should be true');

        Prepaid_Card__c updatedCard = [
            SELECT Card_Status__c, Merchant_Application__c, Assigned_Date__c
            FROM Prepaid_Card__c
            WHERE Id = :card.Id
        ];
        System.assertEquals('Assigned', updatedCard.Card_Status__c,            'Card status should be Assigned');
        System.assertEquals(app.Id,     updatedCard.Merchant_Application__c,   'Card should be linked to the application');
        System.assertEquals(Date.today(), updatedCard.Assigned_Date__c,        'Assigned date should be today');
    }

    @isTest
    static void saveCardId_withNoPrepaidCardMatch_updatesAppOnly() {
        Merchant_Application__c app = createApplication();

        System.Test.startTest();
        PrepaidCardController.saveCardId(app.Id, 'CARD-NONEXISTENT');
        System.Test.stopTest();

        Merchant_Application__c updatedApp = [
            SELECT Card_ID__c, Card_Assigned__c
            FROM Merchant_Application__c
            WHERE Id = :app.Id
        ];
        System.assertEquals('CARD-NONEXISTENT', updatedApp.Card_ID__c, 'Card ID should still be saved on app');
        System.assertEquals(true, updatedApp.Card_Assigned__c);

        // No Prepaid_Card__c records should exist (nothing to assert on card side)
        Integer cardCount = [SELECT COUNT() FROM Prepaid_Card__c WHERE Card_ID__c = 'CARD-NONEXISTENT'];
        System.assertEquals(0, cardCount, 'No card record should exist for this Card ID');
    }

    @isTest
    static void saveCardId_invalidApplicationId_throwsAuraHandledException() {
        System.Test.startTest();
        try {
            PrepaidCardController.saveCardId('INVALID_ID', 'CARD-001');
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Error saving Card ID'),
                'Exception message should contain "Error saving Card ID"'
            );
        }
        System.Test.stopTest();
    }


    // ══════════════════════════════════════════════
    //  getApplicationDetails tests
    // ══════════════════════════════════════════════

    @isTest
    static void getApplicationDetails_validId_returnsCorrectRecord() {
        Merchant_Application__c app = createApplication();

        System.Test.startTest();
        Merchant_Application__c result = PrepaidCardController.getApplicationDetails(app.Id);
        System.Test.stopTest();

        System.assertEquals(app.Id,           result.Id);
        System.assertEquals('Test Merchant',  result.Merchant_Name__c);
        System.assertEquals('0500000000',     result.Mobile_Number__c);
        System.assertEquals('test@merchant.com', result.Email__c);
        System.assertEquals('Test Business',  result.Business_Name__c);
        System.assertEquals('Pending',        result.Status__c);
    }

    @isTest
    static void getApplicationDetails_invalidId_throwsAuraHandledException() {
        System.Test.startTest();
        try {
            PrepaidCardController.getApplicationDetails('INVALID_ID');
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Error fetching application'),
                'Exception message should contain "Error fetching application"'
            );
        }
        System.Test.stopTest();
    }

    @isTest
    static void getApplicationDetails_cardAssignedFields_returnCorrectly() {
        Merchant_Application__c app = createApplication();
        app.Card_ID__c       = 'CARD-XYZ';
        app.Card_Assigned__c = true;
        update app;

        System.Test.startTest();
        Merchant_Application__c result = PrepaidCardController.getApplicationDetails(app.Id);
        System.Test.stopTest();

        System.assertEquals('CARD-XYZ', result.Card_ID__c);
        System.assertEquals(true,       result.Card_Assigned__c);
    }


    // ══════════════════════════════════════════════
    //  validateCardId tests
    // ══════════════════════════════════════════════

    @isTest
    static void validateCardId_cardNotInSystem_returnsNotFound() {
        System.Test.startTest();
        String result = PrepaidCardController.validateCardId('CARD-GHOST');
        System.Test.stopTest();

        System.assertEquals('NOT_FOUND', result, 'Should return NOT_FOUND for unknown card');
    }

    @isTest
    static void validateCardId_cardAvailable_returnsValid() {
        createCard('CARD-NEW', 'Available');

        System.Test.startTest();
        String result = PrepaidCardController.validateCardId('CARD-NEW');
        System.Test.stopTest();

        System.assertEquals('VALID', result, 'Should return VALID for an unassigned card');
    }

    @isTest
    static void validateCardId_cardAlreadyAssigned_returnsAlreadyAssigned() {
        createCard('CARD-USED', 'Assigned');

        System.Test.startTest();
        String result = PrepaidCardController.validateCardId('CARD-USED');
        System.Test.stopTest();

        System.assertEquals('ALREADY_ASSIGNED', result, 'Should return ALREADY_ASSIGNED for an assigned card');
    }

    @isTest
    static void validateCardId_cardInOtherStatus_returnsValid() {
        // Any status that is NOT 'Assigned' should pass as VALID
        // e.g. 'Inactive', 'Blocked', 'Pending' — confirm with business logic if needed
        createCard('CARD-OTHER', 'Inactive');

        System.Test.startTest();
        String result = PrepaidCardController.validateCardId('CARD-OTHER');
        System.Test.stopTest();

        System.assertEquals('VALID', result,
            'Non-Assigned status should return VALID — revisit if other statuses should be blocked');
    }
}