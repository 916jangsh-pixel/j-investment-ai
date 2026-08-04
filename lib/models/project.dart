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
  final bool isActive;
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
    required this.isActive,
    required this.createdAt,
    this.status = 'ACTIVE',
  });

  double get profit => currentBalance - startBalance;
  double get remainingToTarget =>
      (targetBalance - currentBalance).clamp(0, double.infinity);

  double get progress {
    if (targetBalance <= startBalance) {
      return currentBalance >= targetBalance ? 1 : 0;
    }
    return ((currentBalance - startBalance) /
            (targetBalance - startBalance))
        .clamp(0.0, 1.0);
  }

  double get baseRecommendedMargin {
    final base = compoundEnabled ? currentBalance : startBalance;
    return base * marginPercent / 100;
  }

  double get lossProtectionMultiplier {
    if (!lossProtectionEnabled) return 1;
    if (lossStreak >= 4) return 0.25;
    if (lossStreak == 3) return 0.50;
    if (lossStreak == 2) return 0.75;
    return 1;
  }

  double get recommendedMargin {
    final raw = baseRecommendedMargin * lossProtectionMultiplier;
    final cap = currentBalance * maxMarginPercent / 100;
    return cap <= 0 ? 0 : (raw > cap ? cap : raw);
  }

  Project copyWith({
    String? name,
    double? startBalance,
    double? currentBalance,
    double? targetBalance,
    bool? compoundEnabled,
    double? marginPercent,
    double? maxMarginPercent,
    int? maxLeverage,
    double? maxLossPercent,
    int? lossStreak,
    bool? lossProtectionEnabled,
    bool? isActive,
    String? status,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      startBalance: startBalance ?? this.startBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      targetBalance: targetBalance ?? this.targetBalance,
      compoundEnabled: compoundEnabled ?? this.compoundEnabled,
      marginPercent: marginPercent ?? this.marginPercent,
      maxMarginPercent: maxMarginPercent ?? this.maxMarginPercent,
      maxLeverage: maxLeverage ?? this.maxLeverage,
      maxLossPercent: maxLossPercent ?? this.maxLossPercent,
      lossStreak: lossStreak ?? this.lossStreak,
      lossProtectionEnabled:
          lossProtectionEnabled ?? this.lossProtectionEnabled,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      status: status ?? this.status,
    );
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
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'status': status,
      };

  factory Project.fromMap(Map<String, Object?> map) {
    double d(Object? value) => (value as num).toDouble();
    return Project(
      id: map['id'] as int?,
      name: map['name'] as String,
      startBalance: d(map['start_balance']),
      currentBalance: d(map['current_balance']),
      targetBalance: d(map['target_balance']),
      compoundEnabled: (map['compound_enabled'] as int) == 1,
      marginPercent: d(map['margin_percent']),
      maxMarginPercent: d(map['max_margin_percent']),
      maxLeverage: map['max_leverage'] as int,
      maxLossPercent: d(map['max_loss_percent']),
      lossStreak: map['loss_streak'] as int,
      lossProtectionEnabled:
          (map['loss_protection_enabled'] as int) == 1,
      isActive: (map['is_active'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      status: map['status'] as String? ?? 'ACTIVE',
    );
  }
}
