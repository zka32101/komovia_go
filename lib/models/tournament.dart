// `Tournament`/`TournamentParticipant`/`TournamentMatch`/
// `TournamentStandingEntry` used to be declared here with their own
// Firestore-coupled shape (`fromFirestore`/`toFirestore`), but that shape
// has been ported field-for-field to `package:komovia_core` - re-exported
// here unchanged so every existing
// `import 'package:komovia_go/models/tournament.dart';` keeps working.
//
// Firestore conversion (`Timestamp`<->`DateTime`) now lives in
// `services/tournament_service.dart` as private adapters, the same way
// komovia_core's other extracted models keep storage out of the shared
// model and into each app's own service layer.
export 'package:komovia_core/komovia_core.dart'
    show
        Tournament,
        TournamentParticipant,
        TournamentMatch,
        TournamentStandingEntry;
