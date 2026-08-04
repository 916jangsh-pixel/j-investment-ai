import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/trade.dart';
import '../services/trade_database.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<Trade> _trades = const [];
  Project? _activeProject;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final active = await TradeDatabase.instance.getActiveProject();
    final trades = active?.id == null
        ? <Trade>[]
        : await TradeDatabase.instance.getTrades(projectId: active!.id);

    if (!mounted) return;

    setState(() {
      _activeProject = active;
      _trades = trades.where((trade) => trade.isClosed).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final project = _activeProject;

    if (project == null) {
      return const Center(child: Text('활성 프로젝트가 없습니다.'));
    }

    final total = _trades.length;
    final wins = _trades.where((t) => (t.netPnl ?? 0) > 0).length;
    final losses = _trades.where((t) => (t.netPnl ?? 0) < 0).length;
    final net = _trades.fold<double>(
      0,
      (sum, trade) => sum + (trade.netPnl ?? 0),
    );
    final winRate = total == 0 ? 0.0 : wins / total * 100;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '활성 프로젝트: ${project.name}',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _stat(
            '현재 자산',
            '${project.currentBalance.toStringAsFixed(2)} USDT',
          ),
          _stat(
            '목표까지 남은 금액',
            '${project.remainingToTarget.toStringAsFixed(2)} USDT',
          ),
          _stat('종료 거래', '$total회'),
          _stat('승리 / 패배', '$wins / $losses'),
          _stat('승률', '${winRate.toStringAsFixed(1)}%'),
          _stat('누적 순손익', '${net.toStringAsFixed(2)} USDT'),
        ],
      ),
    );
  }

  Widget _stat(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
