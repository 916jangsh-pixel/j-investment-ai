import 'package:flutter/material.dart';

import 'ai_coach_screen.dart';
import 'dashboard_screen.dart';
import 'project_screen.dart';
import 'statistics_screen.dart';
import 'trade_journal_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _refreshToken = 0;

  void _refreshAll() => setState(() => _refreshToken++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        key: ValueKey('dashboard_$_refreshToken'),
        onProjectChanged: _refreshAll,
      ),
      ProjectScreen(
        key: ValueKey('projects_$_refreshToken'),
        onProjectChanged: _refreshAll,
      ),
      TradeJournalScreen(
        key: ValueKey('journal_$_refreshToken'),
        onDataChanged: _refreshAll,
      ),
      const AiCoachScreen(),
      StatisticsScreen(
        key: ValueKey('stats_$_refreshToken'),
      ),
    ];

    const titles = [
      'J.Investment AI',
      '프로젝트',
      '매매일지',
      'AI 코치',
      '통계',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
            _refreshToken++;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: '프로젝트',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '매매일지',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'AI 코치',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '통계',
          ),
        ],
      ),
    );
  }
}
