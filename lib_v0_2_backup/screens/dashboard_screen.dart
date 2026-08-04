import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/trade_database.dart';
import '../widgets/project_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Project> _projects = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final projects = await TradeDatabase.instance.getProjects();

    if (!mounted) return;

    setState(() {
      _projects = projects;
      _loading = false;
    });
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
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '오늘의 투자 현황',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '활성 프로젝트',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_projects.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  '아직 프로젝트가 없습니다.\n프로젝트 탭에서 첫 복리 프로젝트를 만들어주세요.',
                ),
              ),
            )
          else
            ..._projects.map(
              (project) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ProjectCard(project: project),
              ),
            ),
          const SizedBox(height: 20),
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
                    'AI 시장 분석은 다음 버전에서 연결합니다.',
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
}
