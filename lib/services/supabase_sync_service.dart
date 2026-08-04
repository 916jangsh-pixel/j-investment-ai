import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/project.dart';
import '../models/trade.dart';
import '../models/trade_image.dart';
import 'trade_database.dart';

class SupabaseSyncService {
  SupabaseSyncService._();

  static final SupabaseSyncService instance = SupabaseSyncService._();

  bool get isConfigured => SupabaseConfig.isConfigured;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> initialize() async {
    if (!isConfigured) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  String _requireUserId() {
    final current = _client.auth.currentUser;

    if (current == null) {
      throw StateError(
        '로그인이 필요합니다. 앱에서 이메일 계정으로 로그인해주세요.',
      );
    }

    return current.id;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> syncAll() async {
    if (!isConfigured) {
      throw StateError('Supabase URL과 anon key를 먼저 설정해주세요.');
    }

    // 더 이상 익명 사용자를 자동 생성하지 않습니다.
    final userId = _requireUserId();

    final projects = await TradeDatabase.instance.getProjects(
      includeArchived: true,
    );

    for (final project in projects) {
      await _syncProject(project, userId);
    }

    final trades = await TradeDatabase.instance.getTrades();

    for (final trade in trades) {
      await _syncTrade(trade, userId);

      if (trade.id == null) continue;

      final images =
          await TradeDatabase.instance.getTradeImages(trade.id!);

      for (final image in images) {
        await _syncImage(image, trade, userId);
      }
    }
  }

  Future<void> _syncProject(Project project, String userId) async {
    if (project.id == null) return;

    await _client.from('projects').upsert({
      'user_id': userId,
      'local_id': project.id,
      'name': project.name,
      'start_balance': project.startBalance,
      'current_balance': project.currentBalance,
      'target_balance': project.targetBalance,
      'compound_enabled': project.compoundEnabled,
      'margin_percent': project.marginPercent,
      'max_margin_percent': project.maxMarginPercent,
      'max_leverage': project.maxLeverage,
      'max_loss_percent': project.maxLossPercent,
      'loss_streak': project.lossStreak,
      'loss_protection_enabled': project.lossProtectionEnabled,
      'is_active': project.isActive,
      'status': project.status,
      'created_at': project.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,local_id');
  }

  Future<void> _syncTrade(Trade trade, String userId) async {
    if (trade.id == null) return;

    await _client.from('trades').upsert({
      'user_id': userId,
      'local_id': trade.id,
      'project_local_id': trade.projectId,
      'symbol': trade.symbol,
      'exchange': trade.exchange,
      'timeframe': trade.timeframe,
      'direction': trade.direction,
      'entry': trade.entry,
      'stop': trade.stop,
      'target': trade.target,
      'exit': trade.exit,
      'leverage': trade.leverage,
      'margin_mode': trade.marginMode,
      'margin': trade.margin,
      'fee': trade.fee,
      'funding_fee': trade.fundingFee,
      'price_return_percent': trade.priceReturnPercent,
      'leveraged_return_percent': trade.leveragedReturnPercent,
      'gross_pnl': trade.grossPnl,
      'net_pnl': trade.netPnl,
      'entry_note': trade.entryNote,
      'exit_note': trade.exitNote,
      'review_note': trade.reviewNote,
      'status': trade.status,
      'created_at': trade.createdAt.toIso8601String(),
      'closed_at': trade.closedAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,local_id');
  }

  Future<void> _syncImage(
    TradeImage image,
    Trade trade,
    String userId,
  ) async {
    if (image.id == null || trade.id == null) return;

    final file = File(image.localPath);
    if (!await file.exists()) return;

    final extension = p.extension(image.localPath);
    final storagePath =
        '$userId/${trade.id}/${image.stage.toLowerCase()}_${image.id}$extension';

    await _client.storage.from('trade-images').upload(
          storagePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    await _client.from('trade_images').upsert({
      'user_id': userId,
      'local_id': image.id,
      'trade_local_id': trade.id,
      'stage': image.stage,
      'storage_path': storagePath,
      'created_at': image.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,local_id');
  }
}
