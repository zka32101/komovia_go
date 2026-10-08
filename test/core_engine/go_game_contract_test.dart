import 'package:komovia_core/testkit.dart';
import 'package:komovia_go/komovia_go_engine.dart';

void main() {
  runGameContractTests(
    GoGame(),
    samplePosition: () => GoGame().initialPosition(),
  );
}
