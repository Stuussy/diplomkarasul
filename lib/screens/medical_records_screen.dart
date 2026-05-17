import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/medical_record.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';
import '../widgets/dent_card.dart';
import '../widgets/dent_badge.dart';
import '../widgets/patient_ui.dart';
import '../widgets/tooth_chart.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({
    super.key,
    this.patientId,
    this.title,
    this.allowCreate = false,
    this.allowEdit = false,
  });

  final String? patientId;
  final String? title;
  final bool allowCreate;
  final bool allowEdit;

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  late Future<List<MedicalRecord>> _future;
  String? _resolvedPatientId;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionProvider>();
    _currentUser = session.user;
    _resolvedPatientId = widget.patientId ?? session.user?.id;
    _future = _load();
  }

  Future<List<MedicalRecord>> _load() {
    final api = context.read<SessionProvider>().apiService;
    if (widget.patientId == null || _currentUser?.role == 'patient') {
      return api.fetchMyMedicalRecords();
    }
    return api.fetchMedicalRecords(widget.patientId!);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() { _future = future; });
    await future;
  }

  bool get _canCreate =>
      widget.allowCreate && (_currentUser?.role == 'doctor' || _isAdmin);
  bool get _canEdit =>
      widget.allowEdit && (_currentUser?.role == 'doctor' || _isAdmin);
  bool get _isAdmin =>
      _currentUser?.role == 'admin' || _currentUser?.role == 'superadmin';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClinicTheme.mist,
      appBar: AppBar(title: Text(widget.title ?? 'Медицинская карта')),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: FutureBuilder<List<MedicalRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(
              child: PatientEmptyState(
                title: 'Нет записей',
                message: 'Ваш стоматолог добавит рекомендации после посещения.',
                icon: LucideIcons.clipboardList,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final record = records[index];
                return DentCard(
                  onTap: () => _openRecordDetail(record),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              record.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          DentBadge(
                            label: _formatDate(record.createdAt),
                            variant: DentBadgeVariant.info,
                          ),
                        ],
                      ),
                      if (record.doctor != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(LucideIcons.stethoscope, size: 14, color: ClinicTheme.slate),
                            const SizedBox(width: 6),
                            Text(
                              record.doctor!.fullName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                      if (record.description != null && record.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          record.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (record.toothMap.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ToothChart(toothMap: record.toothMap),
                      ],
                      if (record.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: record.tags.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: ClinicTheme.azureSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: ClinicTheme.azure,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                      if (_canEdit) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _showEditDialog(record),
                            icon: const Icon(LucideIcons.pencil, size: 14),
                            label: const Text('Редактировать'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openRecordDetail(MedicalRecord record) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClinicTheme.snow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ClinicTheme.mist,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        record.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    DentBadge(
                      label: _formatDate(record.createdAt),
                      variant: DentBadgeVariant.info,
                    ),
                  ],
                ),
                if (record.doctor != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Врач: ${record.doctor!.fullName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (record.description != null && record.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(record.description!, style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 16),
                ToothChart(toothMap: record.toothMap),
                if (record.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: record.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ClinicTheme.azureSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(tag, style: const TextStyle(color: ClinicTheme.azure, fontSize: 12, fontWeight: FontWeight.w600)),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportRecord(record),
                        icon: const Icon(LucideIcons.download, size: 16),
                        label: const Text('Экспорт PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _printRecord(record),
                        icon: const Icon(LucideIcons.printer, size: 16),
                        label: const Text('Печать'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List> _buildRecordPdf(MedicalRecord record) async {
    final doc = pw.Document();
    final toothRows = record.toothMap
        .map((item) =>
            '${item.arch == 'upper' ? 'Верхняя' : 'Нижняя'} '
            '${item.index}: ${item.status}')
        .toList();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Медицинская карта', style: pw.TextStyle(fontSize: 22)),
            pw.SizedBox(height: 8),
            pw.Text('Запись: ${record.title}'),
            pw.Text('Дата: ${_formatDate(record.createdAt)}'),
            if (record.doctor != null)
              pw.Text('Врач: ${record.doctor!.fullName}'),
            if (record.description != null && record.description!.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Описание:'),
              pw.Text(record.description!),
            ],
            if (record.tags.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Теги: ${record.tags.join(', ')}'),
            ],
            if (toothRows.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Отметки по зубам:'),
              pw.Bullet(text: toothRows.join(' · ')),
            ],
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<void> _exportRecord(MedicalRecord record) async {
    final data = await _buildRecordPdf(record);
    await Printing.sharePdf(bytes: data, filename: 'medical_record_${record.id}.pdf');
  }

  Future<void> _printRecord(MedicalRecord record) async {
    final data = await _buildRecordPdf(record);
    await Printing.layoutPdf(onLayout: (_) => data);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  Future<void> _showCreateDialog() async {
    await _showRecordEditor(record: null);
  }

  Future<void> _showEditDialog(MedicalRecord record) async {
    await _showRecordEditor(record: record);
  }

  Future<void> _showRecordEditor({MedicalRecord? record}) async {
    final isEdit = record != null;
    final titleController = TextEditingController(text: record?.title ?? '');
    final descController = TextEditingController(text: record?.description ?? '');
    final tags = <String>[...?record?.tags];
    final tagInputController = TextEditingController();
    final toothMap = <ToothMark>[...?record?.toothMap];
    final formKey = GlobalKey<FormState>();
    final api = context.read<SessionProvider>().apiService;
    final pageMessenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            bool isSaving = false;

            void addTag(String value) {
              final clean = value.trim();
              if (clean.isEmpty || tags.contains(clean)) return;
              tags.add(clean);
              tagInputController.clear();
              setSheetState(() {});
            }

            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              final pending = tagInputController.text.trim();
              if (pending.isNotEmpty && !tags.contains(pending)) {
                tags.add(pending);
              }
              setSheetState(() => isSaving = true);
              try {
                if (isEdit) {
                  await api.updateMedicalRecord(
                    recordId: record.id,
                    title: titleController.text.trim(),
                    description: descController.text.trim(),
                    tags: tags,
                    toothMap: toothMap,
                  );
                } else {
                  await api.createMedicalRecord(
                    patientId: _resolvedPatientId!,
                    title: titleController.text.trim(),
                    description: descController.text.trim().isEmpty
                        ? null
                        : descController.text.trim(),
                    tags: tags,
                    toothMap: toothMap,
                  );
                }
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                if (!mounted) return;
                pageMessenger.showSnackBar(
                  SnackBar(content: Text(isEdit ? 'Запись обновлена' : 'Запись добавлена')),
                );
                await _refresh();
              } catch (error) {
                if (!sheetContext.mounted) return;
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text('Ошибка: $error')),
                );
              } finally {
                if (innerContext.mounted) setSheetState(() => isSaving = false);
              }
            }

            final viewInsets = MediaQuery.of(innerContext).viewInsets.bottom;
            final maxHeight = MediaQuery.of(innerContext).size.height * 0.92;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(bottom: viewInsets),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Container(
                  decoration: const BoxDecoration(
                    color: ClinicTheme.snow,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ClinicTheme.mist,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: ClinicTheme.heroGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                LucideIcons.clipboardList,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEdit ? 'Редактировать запись' : 'Новая запись',
                                    style: Theme.of(innerContext).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isEdit
                                        ? 'Обновите данные осмотра'
                                        : 'Заполните данные осмотра пациента',
                                    style: Theme.of(innerContext).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Закрыть',
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(LucideIcons.x),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(
                                  icon: LucideIcons.fileText,
                                  label: 'Заголовок',
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: titleController,
                                  decoration: InputDecoration(
                                    hintText: 'Например: Профилактический осмотр',
                                    filled: true,
                                    fillColor: ClinicTheme.mist.withValues(alpha: 0.4),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
                                ),
                                const SizedBox(height: 18),
                                _FieldLabel(
                                  icon: LucideIcons.pencil,
                                  label: 'Описание / рекомендации',
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: descController,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Что было сделано, рекомендации, назначения…',
                                    filled: true,
                                    fillColor: ClinicTheme.mist.withValues(alpha: 0.4),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _FieldLabel(
                                  icon: LucideIcons.tags,
                                  label: 'Теги',
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...tags.map(
                                      (tag) => InputChip(
                                        label: Text(tag),
                                        onDeleted: () {
                                          tags.remove(tag);
                                          setSheetState(() {});
                                        },
                                        backgroundColor: ClinicTheme.azureSoft,
                                        labelStyle: const TextStyle(
                                          color: ClinicTheme.azure,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        deleteIconColor: ClinicTheme.azure,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: tagInputController,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: addTag,
                                  decoration: InputDecoration(
                                    hintText: 'Добавьте тег и нажмите Enter',
                                    prefixIcon: const Icon(LucideIcons.plus, size: 18),
                                    suffixIcon: IconButton(
                                      icon: const Icon(LucideIcons.cornerDownLeft, size: 18),
                                      onPressed: () => addTag(tagInputController.text),
                                    ),
                                    filled: true,
                                    fillColor: ClinicTheme.mist.withValues(alpha: 0.4),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _FieldLabel(
                                  icon: LucideIcons.scanLine,
                                  label: 'Зубная карта',
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: ClinicTheme.mist.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ToothChart(
                                    toothMap: toothMap,
                                    onChanged: (updated) {
                                      toothMap
                                        ..clear()
                                        ..addAll(updated);
                                      setSheetState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isSaving
                                      ? null
                                      : () => Navigator.of(sheetContext).pop(),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Отмена'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: isSaving ? null : submit,
                                  icon: isSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(LucideIcons.check, size: 18),
                                  label: Text(isEdit ? 'Сохранить' : 'Добавить запись'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    descController.dispose();
    tagInputController.dispose();
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ClinicTheme.azure),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: ClinicTheme.midnight,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
