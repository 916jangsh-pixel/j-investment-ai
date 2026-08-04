import 'package:flutter/material.dart';

class AiCoachScreen extends StatelessWidget {
  const AiCoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Placeholder(
      icon: Icons.smart_toy,
      title: 'AI 코치',
      subtitle: '현재 차트와 과거 성공·실패 차트를 비교하는 기능을 연결할 예정입니다.',
    );
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Placeholder({
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
