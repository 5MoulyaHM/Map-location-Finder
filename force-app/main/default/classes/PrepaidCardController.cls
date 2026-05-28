public with sharing class PrepaidCardController {

    // ─── Save scanned Card ID to Merchant Application ───────────────
    @AuraEnabled
    public static void saveCardId(String recordId, String cardId) {
        try {
            // 1. Update the Merchant Application with the scanned Card ID
            Merchant_Application__c app = new Merchant_Application__c(
                Id = recordId,
                Card_ID__c = cardId,
                Card_Assigned__c = true
            );
            update app;

            // 2. Find the Prepaid Card record with this Card ID
            //    and link it to the Merchant Application
            List<Prepaid_Card__c> cards = [
                SELECT Id, Card_Status__c
                FROM Prepaid_Card__c
                WHERE Card_ID__c = :cardId
                LIMIT 1
            ];

            if (!cards.isEmpty()) {
                Prepaid_Card__c card = cards[0];
                card.Card_Status__c = 'Assigned';
                card.Merchant_Application__c = recordId;
                card.Assigned_Date__c = Date.today();
                update card;
            }

        } catch (Exception e) {
            throw new AuraHandledException('Error saving Card ID: ' + e.getMessage());
        }
    }


    // ─── Get Merchant Application details ───────────────────────────
    @AuraEnabled(cacheable=true)
    public static Merchant_Application__c getApplicationDetails(String recordId) {
        try {
            return [
                SELECT Id, Name, Merchant_Name__c, Mobile_Number__c,
                       Email__c, Business_Name__c, Status__c,
                       Card_ID__c, Card_Assigned__c
                FROM Merchant_Application__c
                WHERE Id = :recordId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching application: ' + e.getMessage());
        }
    }


    // ─── Check if Card ID already exists / already assigned ─────────
    @AuraEnabled
    public static String validateCardId(String cardId) {
        try {
            List<Prepaid_Card__c> cards = [
                SELECT Id, Card_Status__c
                FROM Prepaid_Card__c
                WHERE Card_ID__c = :cardId
                LIMIT 1
            ];

            if (cards.isEmpty()) {
                return 'NOT_FOUND'; // Card ID doesnt exist in system
            }

            if (cards[0].Card_Status__c == 'Assigned') {
                return 'ALREADY_ASSIGNED'; // Card already used
            }

            return 'VALID'; // Good to go

        } catch (Exception e) {
            throw new AuraHandledException('Error validating Card ID: ' + e.getMessage());
        }
    }
}