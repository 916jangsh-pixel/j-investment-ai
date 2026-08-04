import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/trade_database.dart';
import '../widgets/project_card.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onProjectChanged;

  const DashboardScreen({
    super.key,
    this.onProjectChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Project> _projects = const [];
  Project? _activeProject;
  double _closedNetPnl = 0;
  int _openTrades = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final projects = await TradeDatabase.instance.getProjects();
    final active = await TradeDatabase.instance.getActiveProject();

    double pnl = 0;
    int open = 0;

    if (active?.id != null) {
      pnl = await TradeDatabase.instance
          .getProjectClosedNetPnl(active!.id!);
      open = await TradeDatabase.instance
          .getProjectOpenTradeCount(active.id!);
    }

    if (!mounted) return;

    setState(() {
      _projects = projects;
      _activeProject = active;
      _closedNetPnl = pnl;
      _openTrades = open;
      _loading = false;
    });
  }

  Future<void> _changeActiveProject(int? projectId) async {
    if (projectId == null) return;

    await TradeDatabase.instance.setActiveProject(projectId);
    await _load();
    widget.onProjectChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '안녕하세요 👋',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          const Text(
            '오늘의 투자 현황',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 22),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_projects.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('프로젝트 탭에서 첫 프로젝트를 만들어주세요.'),
              ),
            )
          else ...[
            DropdownButtonFormField<int>(
              initialValue: _activeProject?.id,
              decoration: const InputDecoration(
                labelText: '활성 프로젝트',
                filled: true,
                border: OutlineInputBorder(),
              ),
              items: _projects
                  .map(
                    (project) => DropdownMenuItem(
                      value: project.id,
                      child: Text(project.name),
                    ),
                  )
                  .toList(),
              onChanged: _changeActiveProject,
            ),
            const SizedBox(height: 14),
            if (_activeProject != null)
              ProjectCard(
                project: _activeProject!,
                showActiveBadge: true,
              ),
            const SizedBox(height: 14),
            if (_activeProject != null) _summaryCard(_activeProject!),
          ],
          const SizedBox(height: 22),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 투자 판단',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'WAIT',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'AI 시장 분석은 다음 단계에서 연결합니다.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(Project project) {
    final actualProfit = project.currentBalance - project.startBalance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '매매일지 연동 현황',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _row('종료 거래 누적 손익', '${signed(_closedNetPnl)} USDT'),
            _row('프로젝트 자산 변화', '${signed(actualProfit)} USDT'),
            _row('현재 자산', '${money(project.currentBalance)} USDT'),
            _row(
              '목표까지 남은 금액',
              '${money(project.remainingToTarget)} USDT',
            ),
            _row(
              '진행률',
              '${(project.progress * 100).toStringAsFixed(1)}%',
            ),
            _row('현재 OPEN 거래', '$_openTrades건'),
            _row(
              '다음 추천 증거금',
              '${money(project.recommendedMargin)} USDT',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

String money(double value) => value.toStringAsFixed(2);

String signed(double value) {
  final text = value.toStringAsFixed(2);
  return value > 0 ? '+$text' : text;
}
