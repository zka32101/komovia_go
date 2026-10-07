/// Configuration for AI opponent difficulty and behavior
class AIOpponentConfig {
  /// Highest AI level available without Premium.
  static const int freeMaxLevel = 5;

  /// Highest AI level.
  static const int maxLevel = 10;

  final int level; // 1-10: 1=beginner, 10=professional
  final String engineName; // e.g., "GNU Go"
  final String engineVersion;
  final Map<String, String> engineParams;
  final Duration responseTimeout;
  final int maxRetries;

  AIOpponentConfig({
    required this.level,
    this.engineName = 'GNU Go',
    this.engineVersion = '3.8.8',
    this.engineParams = const {},
    this.responseTimeout = const Duration(seconds: 15),
    this.maxRetries = 2,
  });

  /// Recommended config for beginner (9x9 board)
  factory AIOpponentConfig.beginner() {
    return AIOpponentConfig(
      level: 2,
      engineParams: {
        'level': '2',
        'thinking_time': '2000',
      },
    );
  }

  /// Recommended config for intermediate (13x13 board)
  factory AIOpponentConfig.intermediate() {
    return AIOpponentConfig(
      level: 5,
      engineParams: {
        'level': '5',
        'thinking_time': '5000',
      },
    );
  }

  /// Recommended config for advanced (19x19 board)
  factory AIOpponentConfig.advanced() {
    return AIOpponentConfig(
      level: 8,
      engineParams: {
        'level': '8',
        'thinking_time': '10000',
      },
    );
  }

  /// Get human-readable difficulty name
  String getDifficultyName() {
    if (level <= 2) return '初心者';
    if (level <= 4) return '初級';
    if (level <= 6) return '中級';
    if (level <= 8) return '上級';
    return 'プロ級';
  }

  /// Copy with modifications
  AIOpponentConfig copyWith({
    int? level,
    String? engineName,
    String? engineVersion,
    Map<String, String>? engineParams,
    Duration? responseTimeout,
    int? maxRetries,
  }) {
    return AIOpponentConfig(
      level: level ?? this.level,
      engineName: engineName ?? this.engineName,
      engineVersion: engineVersion ?? this.engineVersion,
      engineParams: engineParams ?? this.engineParams,
      responseTimeout: responseTimeout ?? this.responseTimeout,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }

  @override
  String toString() =>
      'AIOpponentConfig(level: $level, difficulty: ${getDifficultyName()}, engine: $engineName $engineVersion)';
}
