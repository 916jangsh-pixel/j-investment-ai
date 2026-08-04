import 'package:flutter/material.dart';

void main() {
  runApp(const JInvestmentApp());
}

class JInvestmentApp extends StatelessWidget {
  const JInvestmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'J.Investment AI',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F7CFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    TradeJournalScreen(),
    AiCoachScreen(),
    StatisticsScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = const [
    'J.Investment AI',
    '매매일지',
    'AI 코치',
    '통계',
    '설정',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
      ),
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
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
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text(
          '안녕하세요 👋',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '오늘의 투자 현황',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 24),
        SectionTitle('오늘의 시장'),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MarketCard(
                title: 'BTC',
                value: '-',
                subtitle: '데이터 연결 예정',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: MarketCard(
                title: 'NASDAQ',
                value: '-',
                subtitle: '데이터 연결 예정',
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        MarketCard(
          title: 'USD / KRW',
          value: '-',
          subtitle: '데이터 연결 예정',
        ),
        SizedBox(height: 28),
        SectionTitle('AI 투자 판단'),
        SizedBox(height: 12),
        AiSummaryCard(),
        SizedBox(height: 28),
        SectionTitle('오늘의 경제 일정'),
        SizedBox(height: 12),
        InfoCard(
          icon: Icons.calendar_month,
          title: '주요 경제지표',
          subtitle: 'CPI · PPI · FOMC · 고용지표 일정 연결 예정',
        ),
        SizedBox(height: 12),
        InfoCard(
          icon: Icons.notifications_active_outlined,
          title: 'AI 패턴 알림',
          subtitle: '과거 고승률 패턴 감지 기능 연결 예정',
        ),
        SizedBox(height: 30),
      ],
    );
  }
}

class TradeJournalScreen extends StatefulWidget {
  const TradeJournalScreen({super.key});

  @override
  State<TradeJournalScreen> createState() => _TradeJournalScreenState();
}

class _TradeJournalScreenState extends State<TradeJournalScreen> {
  final _symbolController = TextEditingController(text: 'BTCUSDT');
  final _entryController = TextEditingController();
  final _stopController = TextEditingController();
  final _targetController = TextEditingController();
  final _leverageController = TextEditingController(text: '10');
  final _marginController = TextEditingController();
  final _reasonController = TextEditingController();
  final _memoController = TextEditingController();

  String _direction = 'LONG';
  String _timeframe = '15m';

  @override
  void dispose() {
    _symbolController.dispose();
    _entryController.dispose();
    _stopController.dispose();
    _targetController.dispose();
    _leverageController.dispose();
    _marginController.dispose();
    _reasonController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '새 매매 기록',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '진입 전 매매 계획을 기록하세요.',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 24),

        AppTextField(
          controller: _symbolController,
          label: '종목',
          hint: '예: BTCUSDT',
        ),
        const SizedBox(height: 16),

        const Text(
          '방향',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'LONG',
              label: Text('LONG'),
              icon: Icon(Icons.trending_up),
            ),
            ButtonSegment(
              value: 'SHORT',
              label: Text('SHORT'),
              icon: Icon(Icons.trending_down),
            ),
          ],
          selected: {_direction},
          onSelectionChanged: (selection) {
            setState(() {
              _direction = selection.first;
            });
          },
        ),
        const SizedBox(height: 20),

        DropdownButtonFormField<String>(
          initialValue: _timeframe,
          decoration: inputDecoration('시간봉'),
          items: const [
            DropdownMenuItem(value: '1m', child: Text('1분')),
            DropdownMenuItem(value: '5m', child: Text('5분')),
            DropdownMenuItem(value: '15m', child: Text('15분')),
            DropdownMenuItem(value: '1h', child: Text('1시간')),
            DropdownMenuItem(value: '4h', child: Text('4시간')),
            DropdownMenuItem(value: '1d', child: Text('1일')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _timeframe = value;
            });
          },
        ),
        const SizedBox(height: 16),

        AppTextField(
          controller: _entryController,
          label: '진입가',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),

        AppTextField(
          controller: _stopController,
          label: '손절가',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),

        AppTextField(
          controller: _targetController,
          label: '목표가',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _leverageController,
                label: '레버리지',
                hint: '예: 10',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _marginController,
                label: '증거금',
                hint: 'USDT',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        AppTextField(
          controller: _reasonController,
          label: '진입 이유',
          hint: '예: 상승채널 하단 지지',
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        AppTextField(
          controller: _memoController,
          label: '메모',
          hint: '현재 시장 상태나 주의할 점',
          maxLines: 4,
        ),
        const SizedBox(height: 24),

        FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('입력 화면 정상 작동. 다음 단계에서 실제 저장 기능을 연결합니다.'),
              ),
            );
          },
          icon: const Icon(Icons.save),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('매매 기록 저장'),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class AiCoachScreen extends StatelessWidget {
  const AiCoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.smart_toy,
      title: 'AI 코치',
      subtitle: '현재 차트와 과거 성공·실패 차트를 비교합니다.',
    );
  }
}

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.bar_chart,
      title: '통계',
      subtitle: '승률 · 손익 · 복리 · 패턴별 성과를 분석합니다.',
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.settings,
      title: '설정',
      subtitle: '알림 · 저장공간 · 백업 · API 설정을 관리합니다.',
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const PlaceholderScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class MarketCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const MarketCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined),
              SizedBox(width: 8),
              Text(
                'J.Investment AI',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 18),
          Text(
            'WAIT',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '시장 데이터와 매매 기록을 분석하여\nAI가 투자 판단을 제공합니다.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: inputDecoration(label, hint: hint),
    );
  }
}

InputDecoration inputDecoration(
  String label, {
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFF161B22),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}
