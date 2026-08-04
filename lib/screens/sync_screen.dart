import 'package:flutter/material.dart';

import '../services/supabase_sync_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _syncing = false;
  String _status = '대기 중';

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _status = '동기화 중...';
    });

    try {
      await SupabaseSyncService.instance.syncAll();

      if (!mounted) return;

      setState(() {
        _status = '동기화 완료';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = '동기화 실패: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseSyncService.instance.isConfigured;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '클라우드 백업 / 동기화',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  configured ? 'Supabase 설정 완료' : 'Supabase 설정 필요',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: configured
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '프로젝트, 매매기록, 차트 이미지를 클라우드에 백업합니다.',
                ),
                const SizedBox(height: 10),
                Text(
                  _status,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: configured && !_syncing ? _sync : null,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(_syncing ? '동기화 중...' : '지금 백업/동기화'),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '설정 파일: lib/config/supabase_config.dart',
          style: TextStyle(color: Colors.white60),
        ),
      ],
    );
  }
}
