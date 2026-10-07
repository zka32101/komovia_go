# Firestore rules tests

    npm i @firebase/rules-unit-testing firebase
    npx -y firebase-tools@13 emulators:exec --only firestore --project demo-goen "node test_rules/account_deletion.rules.test.mjs firestore.rules"
    # list queries on two-participant collections:
    npx -y firebase-tools@13 emulators:exec --only firestore --project demo-goen "node test_rules/participant_list_queries.rules.test.mjs firestore.rules"

(firebase-tools 14+ needs JDK 21; 13.x works with JDK 11.)
