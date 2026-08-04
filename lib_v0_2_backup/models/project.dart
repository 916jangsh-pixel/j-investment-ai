class Project {
  final int? id;
  final String name;
  final double startBalance;
  final double currentBalance;
  final double targetBalance;
  final bool compoundEnabled;
  final double marginPercent;
  final double maxMarginPercent;
  final int maxLeverage;
  final double maxLossPercent;
  final int lossStreak;
  final bool lossProtectionEnabled;
  final DateTime createdAt;
  final String status;

  const Project({
    this.id,
    required this.name,
    required this.startBalance,
    required this.currentBalance,
    required this.targetBalance,
    required this.compoundEnabled,
    required this.marginPercent,
    required this.maxMarginPercent,
    required this.maxLeverage,
    required this.maxLossPercent,
    required this.lossStreak,
    required this.lossProtectionEnabled,
    required this.createdAt,
    this.status = 'ACTIVE',
  });

  double get progress {
    if (targetBalance <= 0) return 0;
    return (currentBalance / targetBalance).clamp(0.0, 1.0);
  }

  double get profit => currentBalance - startBalance;

  double get baseRecommendedMargin {
    final base = compoundEnabled ? currentBalance : startBalance;
    return base * marginPercent / 100;
  }

  double get lossProtectionMultiplier {
    if (!lossProtectionEnabled) return 1.0;
    if (lossStreak >= 4) return 0.25;
    if (lossStreak == 3) return 0.50;
    if (lossStreak == 2) return 0.75;
    return 1.0;
  }

  double get recommendedMargin {
    final recommended = baseRecommendedMargin * lossProtectionMultiplier;
    final maxAllowed = currentBalance * maxMarginPercent / 100;
    if (maxAllowed <= 0) return 0;
    return recommended > maxAllowed ? maxAllowed : recommended;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'start_balance': startBalance,
        'current_balance': currentBalance,
        'target_balance': targetBalance,
        'compound_enabled': compoundEnabled ? 1 : 0,
        'margin_percent': marginPercent,
        'max_margin_percent': maxMarginPercent,
        'max_leverage': maxLeverage,
        'max_loss_percent': maxLossPercent,
        'loss_streak': lossStreak,
        'loss_protection_enabled': lossProtectionEnabled ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'status': status,
      };

  factory Project.fromMap(Map<String, Object?> map) {
    double asDouble(Object? value) => (value as num).toDouble();

    return Project(
      id: map['id'] as int?,
      name: map['name'] as String,
      startBalance: asDouble(map['start_balance']),
      currentBalance: asDouble(map['current_balance']),
      targetBalance: asDouble(map['target_balance']),
      compoundEnabled: (map['compound_enabled'] as int) == 1,
      marginPercent: asDouble(map['margin_percent']),
      maxMarginPercent: asDouble(map['max_margin_percent']),
      maxLeverage: map['max_leverage'] as int,
      maxLossPercent: asDouble(map['max_loss_percent']),
      lossStreak: map['loss_streak'] as int,
      lossProtectionEnabled:
          (map['loss_protection_enabled'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      status: map['status'] as String,
    );
  }
}
