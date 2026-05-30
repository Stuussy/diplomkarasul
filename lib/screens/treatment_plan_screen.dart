import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/treatment_plan.dart';
import '../providers/session_provider.dart';
import '../services/api_service.dart';
import '../services/treatment_plan_pdf.dart';
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
            return Stack(
              children: [
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _planCard(plans[i]),
                ),
                if (widget.isStaff && widget.patientId != null)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: ClinicTheme.azure,
                      foregroundColor: Colors.white,
                      onPressed: _openGenerator,
                      child: const Icon(LucideIcons.plus),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _error(String message) => ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(LucideIcons.alertCircle, size: 48, color: ClinicTheme.slate),
          const SizedBox(height: 12),
          Center(child: Text(message, textAlign: TextAlign.center)),
        ],
      );

  Widget _empty() {
    if (widget.isStaff && widget.patientId != null) {
      return _staffEmptyState();
    }
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(LucideIcons.clipboardList, size: 56, color: ClinicTheme.slate.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        const Center(
          child: Text('Планов лечения пока нет',
              style: TextStyle(fontSize: 16, color: ClinicTheme.slate)),
        ),
      ],
    );
  }

  Widget _staffEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 40),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A4DD3), Color(0xFF2E8BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(ClinicTheme.radiusXL),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.bot, size: 36, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'ИИ составит план лечения',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Опишите жалобы и состояние пациента — нейросеть автоматически предложит этапы лечения с ценами и сроками.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0A4DD3),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
                  ),
                ),
                onPressed: _openGenerator,
                icon: const Icon(LucideIcons.bot, size: 18),
                label: const Text(
                  'Создать план с ИИ',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planCard(TreatmentPlan plan) {
    final statusInfo = _statusInfo(plan.status);
    return DentCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
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
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ClinicTheme.violetSoft,
                      borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(LucideIcons.bot, size: 12, color: ClinicTheme.violet),
                        SizedBox(width: 4),
                        Text('Сгенерирован ИИ',
                            style: TextStyle(
                                fontSize: 11, color: ClinicTheme.violet, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plan.diagnosis.isNotEmpty) ...[
                  Row(children: [
                    const Text('Диагноз: ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ClinicTheme.slate)),
                    Expanded(
                      child: Text(plan.diagnosis,
                          style: const TextStyle(fontSize: 12, color: ClinicTheme.slate)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                ],
                // Progress
                Row(children: [
                  const Text('Прогресс',
                      style: TextStyle(fontSize: 12, color: ClinicTheme.slate, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: plan.progress / 100,
                        minHeight: 10,
                        backgroundColor: ClinicTheme.mist,
                        valueColor: const AlwaysStoppedAnimation(ClinicTheme.mint),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${plan.progress}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: ClinicTheme.mint, fontSize: 13)),
                ]),
                const SizedBox(height: 14),
                // Steps
                ...plan.steps.map((step) => _stepRow(plan, step)),
              ],
            ),
          ),
          // Footer
          Container(
            decoration: BoxDecoration(
              color: ClinicTheme.mist,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(ClinicTheme.radiusM),
                bottomRight: Radius.circular(ClinicTheme.radiusM),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(LucideIcons.wallet, size: 15, color: ClinicTheme.slate),
                const SizedBox(width: 4),
                Text(_money(plan.totalCost),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: ClinicTheme.midnight)),
                const SizedBox(width: 14),
                const Icon(LucideIcons.calendarDays, size: 15, color: ClinicTheme.slate),
                const SizedBox(width: 4),
                Text('~${plan.totalDurationDays} дн.',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: ClinicTheme.midnight)),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: ClinicTheme.azure),
                    foregroundColor: ClinicTheme.azure,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
                    ),
                  ),
                  onPressed: () => _exportPlan(plan),
                  icon: const Icon(LucideIcons.download, size: 14),
                  label: const Text('PDF', style: TextStyle(fontSize: 12)),
                ),
                if (widget.isStaff) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Удалить план',
                    onPressed: () => _deletePlan(plan),
                    icon: const Icon(LucideIcons.trash2, size: 18, color: ClinicTheme.coral),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(TreatmentPlan plan, TreatmentStep step) {
    final (color, iconData, bgColor) = switch (step.status) {
      'done' => (ClinicTheme.mint, LucideIcons.check, ClinicTheme.mintSoft),
      'in_progress' => (ClinicTheme.amber, LucideIcons.zap, ClinicTheme.amberSoft),
      _ => (ClinicTheme.slate, LucideIcons.clock, ClinicTheme.mist),
    };
    final isDone = step.status == 'done';

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
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(iconData, size: 14, color: color),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    _chip('~${step.durationDays} дн.', ClinicTheme.azureSoft, ClinicTheme.azure),
                    const SizedBox(width: 6),
                    _chip(_money(step.price), ClinicTheme.mintSoft, ClinicTheme.mint),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }

  (String, DentBadgeVariant) _statusInfo(String status) {
    return switch (status) {
      'completed' => ('Завершён', DentBadgeVariant.success),
      'cancelled' => ('Отменён', DentBadgeVariant.error),
      'draft' => ('Черновик', DentBadgeVariant.neutral),
      _ => ('Активен', DentBadgeVariant.info),
    };
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

  Future<void> _exportPlan(TreatmentPlan plan) async {
    try {
      final data = await TreatmentPlanPdfBuilder.build(plan);
      await Printing.sharePdf(bytes: data, filename: 'treatment_plan_${plan.id}.pdf');
    } catch (e) {
      _toast('Ошибка экспорта PDF: $e');
    }
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
  int get _totalDays => _steps.fold(0, (sum, s) => sum + s.durationDays);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: ClinicTheme.snow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sheet handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: ClinicTheme.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A4DD3), Color(0xFF2E8BFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.bot, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ИИ-генерация плана',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ClinicTheme.midnight)),
                    Text('Опишите состояние пациента',
                        style: TextStyle(fontSize: 12, color: ClinicTheme.slate)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Complaint input
                  TextField(
                    controller: _complaintController,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      labelText: 'Жалобы пациента',
                      hintText:
                          'Напр.: кариес 2 зубов, кровоточивость дёсен, нужна чистка...',
                      filled: true,
                      fillColor: ClinicTheme.mist,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
                          borderSide: BorderSide.none),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Generate button
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _generating
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF0A4DD3), Color(0xFF2E8BFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
                      ),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _generating
                              ? ClinicTheme.azure.withValues(alpha: 0.7)
                              : Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
                          ),
                        ),
                        onPressed: _generating ? null : _generate,
                        icon: _generating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.bot, size: 18),
                        label: Text(_generating
                            ? 'Составляю план...'
                            : (_draft == null ? 'Сгенерировать план' : 'Перегенерировать')),
                      ),
                    ),
                  ),
                  if (_draft != null) ...[
                    const SizedBox(height: 24),
                    // Result section header
                    Row(children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: ClinicTheme.mint,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Готово! Проверьте и скорректируйте',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ClinicTheme.midnight)),
                    ]),
                    const SizedBox(height: 14),
                    // Diagnosis chip
                    if (_draft!.diagnosis.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ClinicTheme.amberSoft,
                          borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
                        ),
                        child: Row(children: [
                          const Icon(LucideIcons.alertCircle,
                              size: 15, color: ClinicTheme.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Диагноз: ${_draft!.diagnosis}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: ClinicTheme.midnight,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Summary card
                    if (_draft!.summary.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ClinicTheme.azureSoft,
                          borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
                        ),
                        child: Text(
                          _draft!.summary,
                          style: const TextStyle(
                              fontSize: 13, color: ClinicTheme.midnight, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Plan title
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Название плана',
                        filled: true,
                        fillColor: ClinicTheme.mist,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Этапы лечения:',
                        style: TextStyle(fontWeight: FontWeight.w700, color: ClinicTheme.midnight)),
                    const SizedBox(height: 8),
                    ..._steps.asMap().entries.map((entry) => _editableStep(entry.key, entry.value)),
                    // Add step button
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _steps.add(TreatmentStep(
                            order: _steps.length + 1,
                            procedure: 'Новый этап',
                          ));
                        });
                      },
                      icon: const Icon(LucideIcons.plus, size: 16, color: ClinicTheme.azure),
                      label: const Text('Добавить этап',
                          style: TextStyle(color: ClinicTheme.azure)),
                    ),
                    const SizedBox(height: 12),
                    // Cost/duration summary
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ClinicTheme.mist,
                        borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(children: [
                              const Icon(LucideIcons.wallet, size: 16, color: ClinicTheme.mint),
                              const SizedBox(width: 6),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Стоимость',
                                    style: TextStyle(fontSize: 10, color: ClinicTheme.slate)),
                                Text(widget.money(_totalCost),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: ClinicTheme.midnight)),
                              ]),
                            ]),
                          ),
                          Expanded(
                            child: Row(children: [
                              const Icon(LucideIcons.calendarDays, size: 16, color: ClinicTheme.azure),
                              const SizedBox(width: 6),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Срок',
                                    style: TextStyle(fontSize: 10, color: ClinicTheme.slate)),
                                Text('~$_totalDays дней',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: ClinicTheme.midnight)),
                              ]),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: ClinicTheme.mint,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(ClinicTheme.radiusM),
                            )),
                        onPressed: _saving || _steps.isEmpty ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.save, size: 18),
                        label: Text(_saving ? 'Сохранение…' : 'Сохранить план'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableStep(int index, TreatmentStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClinicTheme.mist,
        borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
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
