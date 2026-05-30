import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/treatment_plan.dart';
import '../providers/session_provider.dart';
import '../services/api_service.dart';
import '../theme/clinic_theme.dart';
import '../widgets/dent_badge.dart';
import '../widgets/dent_card.dart';

/// Экран планов лечения.
/// Пациент видит свои планы (read-only). Врач/админ — планы пациента
/// с возможностью сгенерировать план через ИИ и отмечать прогресс.
class TreatmentPlanScreen extends StatefulWidget {
  const TreatmentPlanScreen({
    super.key,
    this.patientId,
    this.patientName,
    this.isStaff = false,
  });

  /// null = пациент смотрит свои планы.
  final String? patientId;
  final String? patientName;
  final bool isStaff;

  @override
  State<TreatmentPlanScreen> createState() => _TreatmentPlanScreenState();
}

class _TreatmentPlanScreenState extends State<TreatmentPlanScreen> {
  late Future<List<TreatmentPlan>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TreatmentPlan>> _load() {
    final api = context.read<SessionProvider>().apiService;
    if (widget.isStaff && widget.patientId != null) {
      return api.fetchTreatmentPlans(widget.patientId!);
    }
    return api.fetchMyTreatmentPlans();
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  String _money(num value) {
    final s = value.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf ₸';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClinicTheme.mist,
      appBar: AppBar(
        backgroundColor: ClinicTheme.snow,
        foregroundColor: ClinicTheme.midnight,
        elevation: 0,
        title: Text(
          widget.isStaff && widget.patientName != null
              ? 'Планы: ${widget.patientName}'
              : 'Мои планы лечения',
        ),
      ),
      floatingActionButton: widget.isStaff && widget.patientId != null
          ? FloatingActionButton.extended(
              backgroundColor: ClinicTheme.azure,
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.bot, size: 18),
              label: const Text('План с ИИ'),
              onPressed: _openGenerator,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<TreatmentPlan>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _error(snapshot.error.toString());
            }
            final plans = snapshot.data ?? [];
            if (plans.isEmpty) return _empty();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) => _planCard(plans[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _error(String message) => ListView(
        children: [
          const SizedBox(height: 120),
          Icon(LucideIcons.alertCircle, size: 48, color: ClinicTheme.slate),
          const SizedBox(height: 12),
          Center(child: Text(message, textAlign: TextAlign.center)),
        ],
      );

  Widget _empty() => ListView(
        children: [
          const SizedBox(height: 100),
          Icon(LucideIcons.clipboardList, size: 56, color: ClinicTheme.slate.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Center(
            child: Text('Планов лечения пока нет',
                style: TextStyle(fontSize: 16, color: ClinicTheme.slate)),
          ),
          if (widget.isStaff) ...[
            const SizedBox(height: 8),
            const Center(
              child: Text('Нажмите «План с ИИ», чтобы создать',
                  style: TextStyle(fontSize: 13, color: ClinicTheme.slate)),
            ),
          ],
        ],
      );

  Widget _planCard(TreatmentPlan plan) {
    final statusInfo = _statusInfo(plan.status);
    return DentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: ClinicTheme.midnight),
                ),
              ),
              DentBadge(label: statusInfo.$1, variant: statusInfo.$2),
            ],
          ),
          if (plan.aiGenerated) ...[
            const SizedBox(height: 6),
            Row(children: const [
              Icon(LucideIcons.bot, size: 13, color: ClinicTheme.violet),
              SizedBox(width: 4),
              Text('Составлен с помощью ИИ',
                  style: TextStyle(fontSize: 11, color: ClinicTheme.violet, fontWeight: FontWeight.w600)),
            ]),
          ],
          if (plan.diagnosis.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Диагноз: ${plan.diagnosis}',
                style: const TextStyle(fontSize: 13, color: ClinicTheme.slate)),
          ],
          const SizedBox(height: 12),
          // Прогресс
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: plan.progress / 100,
                  minHeight: 8,
                  backgroundColor: ClinicTheme.mist,
                  valueColor: const AlwaysStoppedAnimation(ClinicTheme.mint),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${plan.progress}%',
                style: const TextStyle(fontWeight: FontWeight.w700, color: ClinicTheme.mint)),
          ]),
          const SizedBox(height: 14),
          // Этапы
          ...plan.steps.map((step) => _stepRow(plan, step)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metric(LucideIcons.wallet, 'Стоимость', _money(plan.totalCost)),
              _metric(LucideIcons.calendarDays, 'Срок', '~${plan.totalDurationDays} дн.'),
              if (widget.isStaff)
                IconButton(
                  tooltip: 'Удалить план',
                  onPressed: () => _deletePlan(plan),
                  icon: const Icon(LucideIcons.trash2, size: 18, color: ClinicTheme.coral),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ClinicTheme.slate),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: ClinicTheme.slate)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: ClinicTheme.midnight)),
            ],
          ),
        ],
      );

  Widget _stepRow(TreatmentPlan plan, TreatmentStep step) {
    final isDone = step.status == 'done';
    final isProgress = step.status == 'in_progress';
    final color = isDone
        ? ClinicTheme.mint
        : isProgress
            ? ClinicTheme.amber
            : ClinicTheme.slate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.isStaff ? () => _cycleStep(plan, step) : null,
            child: Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(
                isDone
                    ? LucideIcons.check
                    : isProgress
                        ? LucideIcons.clock
                        : LucideIcons.circle,
                size: 14,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${step.order}. ${step.procedure}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ClinicTheme.midnight,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (step.description.isNotEmpty)
                  Text(step.description,
                      style: const TextStyle(fontSize: 12, color: ClinicTheme.slate)),
                const SizedBox(height: 2),
                Text('~${step.durationDays} дн. · ${_money(step.price)}',
                    style: const TextStyle(fontSize: 11, color: ClinicTheme.slate)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, DentBadgeVariant) _statusInfo(String status) {
    switch (status) {
      case 'completed':
        return ('Завершён', DentBadgeVariant.success);
      case 'cancelled':
        return ('Отменён', DentBadgeVariant.error);
      case 'draft':
        return ('Черновик', DentBadgeVariant.neutral);
      default:
        return ('Активен', DentBadgeVariant.info);
    }
  }

  Future<void> _cycleStep(TreatmentPlan plan, TreatmentStep step) async {
    final next = switch (step.status) {
      'pending' => 'in_progress',
      'in_progress' => 'done',
      _ => 'pending',
    };
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.updateTreatmentStepStatus(planId: plan.id, stepId: step.id!, status: next);
      _refresh();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _deletePlan(TreatmentPlan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить план?'),
        content: Text('План «${plan.title}» будет удалён безвозвратно.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: ClinicTheme.coral)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.deleteTreatmentPlan(plan.id);
      _refresh();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openGenerator() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GeneratorSheet(
        patientId: widget.patientId!,
        money: _money,
      ),
    );
    if (saved == true) _refresh();
  }
}

/// Нижний лист: ввод жалоб → генерация ИИ → редактирование → сохранение.
class _GeneratorSheet extends StatefulWidget {
  const _GeneratorSheet({required this.patientId, required this.money});

  final String patientId;
  final String Function(num) money;

  @override
  State<_GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends State<_GeneratorSheet> {
  final _complaintController = TextEditingController();
  final _titleController = TextEditingController();

  bool _generating = false;
  bool _saving = false;
  TreatmentPlan? _draft;
  List<TreatmentStep> _steps = [];

  @override
  void dispose() {
    _complaintController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final complaint = _complaintController.text.trim();
    if (complaint.length < 5) {
      _toast('Опишите жалобы подробнее');
      return;
    }
    setState(() => _generating = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      final draft = await api.generateTreatmentPlan(
        complaint: complaint,
        patientId: widget.patientId,
      );
      setState(() {
        _draft = draft;
        _titleController.text = draft.title;
        _steps = draft.steps;
      });
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    if (_steps.isEmpty) return;
    setState(() => _saving = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.createTreatmentPlan(
        patientId: widget.patientId,
        title: _titleController.text.trim().isEmpty
            ? 'План лечения'
            : _titleController.text.trim(),
        diagnosis: _draft?.diagnosis,
        summary: _draft?.summary,
        steps: _steps,
        aiGenerated: _draft?.aiGenerated ?? true,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  double get _totalCost => _steps.fold(0, (sum, s) => sum + s.price);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: ClinicTheme.snow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: ClinicTheme.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: const [
              Icon(LucideIcons.bot, color: ClinicTheme.azure),
              SizedBox(width: 8),
              Text('Генерация плана лечения',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: ClinicTheme.midnight)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _complaintController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Жалобы / диагноз пациента',
                hintText: 'Напр.: кариес 2 зубов, кровоточивость дёсен, нужна чистка',
                filled: true,
                fillColor: ClinicTheme.mist,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: ClinicTheme.azure, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.bot, size: 18),
                label: Text(_generating
                    ? 'ИИ составляет план…'
                    : (_draft == null ? 'Сгенерировать план' : 'Перегенерировать')),
              ),
            ),
            if (_draft != null) ...[
              const Divider(height: 28),
              if (_draft!.diagnosis.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('Диагноз: ${_draft!.diagnosis}',
                      style: const TextStyle(fontSize: 13, color: ClinicTheme.slate)),
                ),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Название плана',
                  filled: true,
                  fillColor: ClinicTheme.mist,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Этапы (можно редактировать и удалять):',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ClinicTheme.midnight)),
              const SizedBox(height: 8),
              ..._steps.asMap().entries.map((entry) => _editableStep(entry.key, entry.value)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Итого: ${widget.money(_totalCost)}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: ClinicTheme.midnight)),
                  Text('${_steps.length} этап(ов)',
                      style: const TextStyle(color: ClinicTheme.slate)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: ClinicTheme.mint, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _saving || _steps.isEmpty ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.save, size: 18),
                  label: Text(_saving ? 'Сохранение…' : 'Сохранить план'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _editableStep(int index, TreatmentStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClinicTheme.mist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: ClinicTheme.azureSoft, shape: BoxShape.circle),
              child: Text('${index + 1}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: ClinicTheme.azure)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: step.procedure,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                    isDense: true, border: InputBorder.none, hintText: 'Процедура'),
                onChanged: (v) => step.procedure = v,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => setState(() => _steps.removeAt(index)),
              icon: const Icon(LucideIcons.x, size: 16, color: ClinicTheme.coral),
            ),
          ]),
          if (step.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 32),
              child: Text(step.description,
                  style: const TextStyle(fontSize: 12, color: ClinicTheme.slate)),
            ),
          const SizedBox(height: 8),
          Row(children: [
            const SizedBox(width: 32),
            Expanded(
              child: _miniField(
                label: 'Дней',
                initial: step.durationDays.toString(),
                onChanged: (v) => step.durationDays = int.tryParse(v) ?? step.durationDays,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniField(
                label: 'Цена, ₸',
                initial: step.price.round().toString(),
                onChanged: (v) => setState(() => step.price = double.tryParse(v) ?? step.price),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _miniField({
    required String label,
    required String initial,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: initial,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: ClinicTheme.snow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      onChanged: onChanged,
    );
  }
}
