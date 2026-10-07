// `MessageThread`/`DirectMessage` used to be declared here with their own
// Firestore-coupled shape, but that shape has been ported field-for-field
// to `package:komovia_core` - re-exported below unchanged so every
// existing `import 'package:komovia_go/models/direct_message.dart';` keeps
// working.
//
// Firestore conversion (`Timestamp`<->`DateTime`) now lives in
// `services/direct_message_service.dart` as private adapters.
export 'package:komovia_core/komovia_core.dart'
    show MessageThread, DirectMessage;
