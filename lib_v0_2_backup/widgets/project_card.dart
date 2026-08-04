import 'package:flutter/material.dart';

import '../models/project.dart';

class ProjectCard extends StatelessWidget {
  final Project project;

  const ProjectCard({
    super.key,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercent = project.progress * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.name,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: project.progress,
            ),
            const SizedBox(height: 8),
            Text(
              '진행률 ${progressPercent.toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 14),
            _row(
              '현재 자산',
              '${project.currentBalance.toStringAsFixed(2)} USDT',
            ),
            _row(
              '목표 자산',
              '${project.targetBalance.toStringAsFixed(2)} USDT',
            ),
            _row(
              '누적 손익',
              '${project.profit >= 0 ? '+' : ''}'
              '${project.profit.toStringAsFixed(2)} USDT',
            ),
            _row(
              '다음 추천 증거금',
              '${project.recommendedMargin.toStringAsFixed(2)} USDT',
            ),
            _row(
              '기본 증거금',
              '${project.marginPercent.toStringAsFixed(1)}%',
            ),
            _row(
              '최대 레버리지',
              '${project.maxLeverage}x',
            ),
            if (project.lossStreak > 0)
              _row(
                '연속 손실',
                '${project.lossStreak}회',
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
