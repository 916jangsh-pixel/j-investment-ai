import 'package:flutter/material.dart';

import '../widgets/info_card.dart';
import '../widgets/market_card.dart';
import '../widgets/section_title.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text(
          '안녕하세요 👋',
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        SizedBox(height: 6),
        Text(
          '오늘의 투자 현황',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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
        _AiSummaryCard(),
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

class _AiSummaryCard extends StatelessWidget {
  const _AiSummaryCard();

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
            style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            '시장 데이터와 매매 기록을 분석하여\nAI가 투자 판단을 제공합니다.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}
