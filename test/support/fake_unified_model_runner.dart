import 'dart:typed_data';

import 'package:ai_career_advisor/services/unified_model.dart';

class FakeUnifiedModelRunner implements UnifiedModelRunner {
  const FakeUnifiedModelRunner({
    this.probabilities,
    this.throwOnRun = false,
    this.isLoaded = true,
  });

  final List<double>? probabilities;
  final bool throwOnRun;

  @override
  final bool isLoaded;

  @override
  Future<List<double>?> run(Float32List input) async {
    if (throwOnRun) throw StateError('Fake model inference failed.');
    return probabilities;
  }
}
