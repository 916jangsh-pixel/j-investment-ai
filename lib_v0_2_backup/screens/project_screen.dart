import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/trade_database.dart';
import '../widgets/app_text_field.dart';
import '../widgets/project_card.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
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

  Future<void> _createProject() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateProjectSheet(),
    );

    if (created == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('새 복리 프로젝트 만들기'),
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_projects.isEmpty)
            const Text(
              '프로젝트를 만들면 현재 자산과 목표에 맞춰 다음 증거금을 자동 계산합니다.',
              style: TextStyle(color: Colors.white60),
            )
          else
            ..._projects.map(
              (project) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ProjectCard(project: project),
              ),
            ),
        ],
      ),
    );
  }
}

class _CreateProjectSheet extends StatefulWidget {
  const _CreateProjectSheet();

  @override
  State<_CreateProjectSheet> createState() =>
      _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<_CreateProjectSheet> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController(text: 'BTC 복리 프로젝트');
  final _start = TextEditingController(text: '1000');
  final _target = TextEditingController(text: '10000');
  final _marginPercent = TextEditingController(text: '20');
  final _maxMarginPercent = TextEditingController(text: '20');
  final _maxLeverage = TextEditingController(text: '10');
  final _maxLossPercent = TextEditingController(text: '2');

  bool _compound = true;
  bool _lossProtection = true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    _target.dispose();
    _marginPercent.dispose();
    _maxMarginPercent.dispose();
    _maxLeverage.dispose();
    _maxLossPercent.dispose();
    super.dispose();
  }

  double? _parseDouble(String value) =>
      double.tryParse(value.trim().replaceAll(',', ''));

  int? _parseInt(String value) =>
      int.tryParse(value.trim());

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final start = _parseDouble(_start.text)!;
    final target = _parseDouble(_target.text)!;
    final marginPercent = _parseDouble(_marginPercent.text)!;
    final maxMarginPercent = _parseDouble(_maxMarginPercent.text)!;
    final maxLeverage = _parseInt(_maxLeverage.text)!;
    final maxLossPercent = _parseDouble(_maxLossPercent.text)!;

    if (target <= start) {
      _message('목표 자산은 시작 자산보다 크게 설정해주세요.');
      return;
    }

    if (marginPercent > maxMarginPercent) {
      _message('기본 증거금 비율은 최대 증거금 비율을 넘을 수 없습니다.');
      return;
    }

    setState(() => _saving = true);

    final project = Project(
      name: _name.text.trim(),
      startBalance: start,
      currentBalance: start,
      targetBalance: target,
      compoundEnabled: _compound,
      marginPercent: marginPercent,
      maxMarginPercent: maxMarginPercent,
      maxLeverage: maxLeverage,
      maxLossPercent: maxLossPercent,
      lossStreak: 0,
      lossProtectionEnabled: _lossProtection,
      createdAt: DateTime.now(),
    );

    await TradeDatabase.instance.insertProject(project);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '새 복리 프로젝트',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _name,
                  label: '프로젝트 이름',
                  validator: requiredValidator,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _start,
                  label: '시작 자산 (USDT)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: numberValidator,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _target,
                  label: '목표 자산 (USDT)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: numberValidator,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _marginPercent,
                  label: '기본 증거금 비율 (%)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: percentValidator,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _maxMarginPercent,
                  label: '최대 증거금 비율 (%)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: percentValidator,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _maxLeverage,
                  label: '최대 레버리지',
                  keyboardType: TextInputType.number,
                  validator: integerValidator,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _maxLossPercent,
                  label: '1회 최대 허용 손실 (%)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: percentValidator,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _compound,
                  onChanged: (value) {
                    setState(() => _compound = value);
                  },
                  title: const Text('복리 사용'),
                  subtitle: const Text(
                    '현재 자산에 맞춰 다음 증거금을 자동 조정',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _lossProtection,
                  onChanged: (value) {
                    setState(() => _lossProtection = value);
                  },
                  title: const Text('연속 손실 보호'),
                  subtitle: const Text(
                    '2연패 75% · 3연패 50% · 4연패 이상 25%',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _saving ? '저장 중...' : '프로젝트 저장',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
