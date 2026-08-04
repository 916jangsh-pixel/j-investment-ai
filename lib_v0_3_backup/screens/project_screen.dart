import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/trade_database.dart';
import '../widgets/app_text_field.dart';
import '../widgets/project_card.dart';

class ProjectScreen extends StatefulWidget {
  final VoidCallback? onProjectChanged;

  const ProjectScreen({
    super.key,
    this.onProjectChanged,
  });

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

  Future<void> _openEditor([Project? project]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProjectEditorSheet(project: project),
    );

    if (changed == true) {
      await _load();
      widget.onProjectChanged?.call();
    }
  }

  Future<void> _setActive(Project project) async {
    final id = project.id;
    if (id == null) return;

    await TradeDatabase.instance.setActiveProject(id);
    await _load();
    widget.onProjectChanged?.call();
  }

  Future<void> _archive(Project project) async {
    final id = project.id;
    if (id == null) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('프로젝트 종료/보관'),
        content: Text(
          '${project.name} 프로젝트를 보관할까요?\n'
          '기존 매매기록은 삭제되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('보관'),
          ),
        ],
      ),
    );

    if (yes != true) return;

    await TradeDatabase.instance.archiveProject(id);
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
          FilledButton.icon(
            onPressed: () => _openEditor(),
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
              '프로젝트를 만들어주세요.',
              style: TextStyle(color: Colors.white60),
            )
          else
            ..._projects.map(
              (project) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    ProjectCard(
                      project: project,
                      showActiveBadge: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openEditor(project),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('수정'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: project.isActive
                                ? null
                                : () => _setActive(project),
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(
                              project.isActive ? '현재 활성' : '활성으로 설정',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '프로젝트 보관',
                          onPressed: () => _archive(project),
                          icon: const Icon(Icons.archive_outlined),
                        ),
                      ],
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

class _ProjectEditorSheet extends StatefulWidget {
  final Project? project;

  const _ProjectEditorSheet({
    this.project,
  });

  @override
  State<_ProjectEditorSheet> createState() =>
      _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends State<_ProjectEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _start;
  late final TextEditingController _target;
  late final TextEditingController _marginPercent;
  late final TextEditingController _maxMarginPercent;
  late final TextEditingController _maxLeverage;
  late final TextEditingController _maxLossPercent;

  late bool _compound;
  late bool _lossProtection;
  bool _saving = false;

  bool get _isEdit => widget.project != null;

  @override
  void initState() {
    super.initState();

    final project = widget.project;

    _name = TextEditingController(
      text: project?.name ?? 'BTC 복리 프로젝트',
    );
    _start = TextEditingController(
      text: project == null
          ? '1000'
          : project.startBalance.toStringAsFixed(2),
    );
    _target = TextEditingController(
      text: project == null
          ? '10000'
          : project.targetBalance.toStringAsFixed(2),
    );
    _marginPercent = TextEditingController(
      text: project == null
          ? '20'
          : project.marginPercent.toStringAsFixed(2),
    );
    _maxMarginPercent = TextEditingController(
      text: project == null
          ? '20'
          : project.maxMarginPercent.toStringAsFixed(2),
    );
    _maxLeverage = TextEditingController(
      text: project?.maxLeverage.toString() ?? '10',
    );
    _maxLossPercent = TextEditingController(
      text: project == null
          ? '2'
          : project.maxLossPercent.toStringAsFixed(2),
    );

    _compound = project?.compoundEnabled ?? true;
    _lossProtection = project?.lossProtectionEnabled ?? true;
  }

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

  double? _d(String value) =>
      double.tryParse(value.trim().replaceAll(',', ''));

  int? _i(String value) => int.tryParse(value.trim());

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final start = _d(_start.text)!;
    final target = _d(_target.text)!;
    final marginPercent = _d(_marginPercent.text)!;
    final maxMarginPercent = _d(_maxMarginPercent.text)!;
    final maxLeverage = _i(_maxLeverage.text)!;
    final maxLossPercent = _d(_maxLossPercent.text)!;

    if (target <= start) {
      _message('목표 자산은 시작 자산보다 크게 설정해주세요.');
      return;
    }

    if (marginPercent > maxMarginPercent) {
      _message('기본 증거금 비율은 최대 증거금 비율을 넘을 수 없습니다.');
      return;
    }

    setState(() => _saving = true);

    final old = widget.project;

    final project = Project(
      id: old?.id,
      name: _name.text.trim(),
      startBalance: start,
      currentBalance: old?.currentBalance ?? start,
      targetBalance: target,
      compoundEnabled: _compound,
      marginPercent: marginPercent,
      maxMarginPercent: maxMarginPercent,
      maxLeverage: maxLeverage,
      maxLossPercent: maxLossPercent,
      lossStreak: old?.lossStreak ?? 0,
      lossProtectionEnabled: _lossProtection,
      isActive: old?.isActive ?? false,
      createdAt: old?.createdAt ?? DateTime.now(),
      status: old?.status ?? 'ACTIVE',
    );

    if (_isEdit) {
      await TradeDatabase.instance.updateProject(project);
    } else {
      await TradeDatabase.instance.insertProject(project);
    }

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
                Text(
                  _isEdit ? '프로젝트 수정' : '새 복리 프로젝트',
                  style: const TextStyle(
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
                if (_isEdit)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '시작 자산 수정은 현재 자산을 자동 변경하지 않습니다.',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
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
                      _saving
                          ? '저장 중...'
                          : _isEdit
                              ? '수정 저장'
                              : '프로젝트 저장',
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
