import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/medical_record.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import '../widgets/patient_ui.dart';
import '../widgets/clinic_card.dart';
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
    setState(() => _future = _load());
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
      appBar: AppBar(title: Text(widget.title ?? 'Медицинская карта')),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(color: PatientPalette.background),
        child: FutureBuilder<List<MedicalRecord>>(
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
                  message:
                      'Ваш стоматолог добавит рекомендации и осмотры после посещения.',
                  icon: Icons.library_books_outlined,
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final record = records[index];
                  return ClinicCard(
                    onTap: () => _openRecordDetail(record),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                record.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            PatientBadge(
                              label: _formatDate(record.createdAt),
                              variant: PatientBadgeVariant.info,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (record.doctor != null)
                          Text(
                            'Врач: ${record.doctor!.fullName}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        if (record.description != null &&
                            record.description!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            record.description!,
                            style: const TextStyle(height: 1.4),
                          ),
                        ],
                        if (record.toothMap.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ToothChart(toothMap: record.toothMap),
                        ],
                        if (record.tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: record.tags
                                .map(
                                  (tag) => Chip(
                                    label: Text(tag),
                                    backgroundColor: PatientPalette.primary
                                        .withValues(alpha: 0.08),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (_canEdit) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _showEditDialog(record),
                              child: const Text('Редактировать'),
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
      ),
    );
  }

  Future<void> _openRecordDetail(MedicalRecord record) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        record.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    PatientBadge(
                      label: _formatDate(record.createdAt),
                      variant: PatientBadgeVariant.info,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (record.doctor != null)
                  Text(
                    'Врач: ${record.doctor!.fullName}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                if (record.description != null &&
                    record.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(record.description!),
                ],
                const SizedBox(height: 16),
                ToothChart(toothMap: record.toothMap),
                if (record.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: record.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            backgroundColor: PatientPalette.primary.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportRecord(record),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Экспорт PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _printRecord(record),
                        icon: const Icon(Icons.print_outlined),
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
        .map(
          (item) =>
              '${item.arch == 'upper' ? 'Верхняя' : 'Нижняя'} '
              '${item.index}: ${item.status}',
        )
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
            if (record.description != null &&
                record.description!.isNotEmpty) ...[
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
    await Printing.sharePdf(
      bytes: data,
      filename: 'medical_record_${record.id}.pdf',
    );
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
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final tagsController = TextEditingController();
    List<ToothMark> toothMap = [];
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setState(() => isSaving = true);
              try {
                await innerContext
                    .read<SessionProvider>()
                    .apiService
                    .createMedicalRecord(
                      patientId: _resolvedPatientId!,
                      title: titleController.text.trim(),
                      description: descController.text.trim().isEmpty
                          ? null
                          : descController.text.trim(),
                      tags: tagsController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      toothMap: toothMap,
                    );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                _refresh();
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text('Ошибка: $error')));
              } finally {
                if (innerContext.mounted) setState(() => isSaving = false);
              }
            }

            return AlertDialog(
              title: const Text('Новая запись'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Заголовок',
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Обязательное поле'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Теги (через запятую)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ToothChart(
                        toothMap: toothMap,
                        onChanged: (updated) {
                          toothMap = updated;
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : submit,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditDialog(MedicalRecord record) async {
    final titleController = TextEditingController(text: record.title);
    final descController = TextEditingController(
      text: record.description ?? '',
    );
    final tagsController = TextEditingController(text: record.tags.join(', '));
    List<ToothMark> toothMap = List.from(record.toothMap);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setState(() => isSaving = true);
              try {
                await innerContext
                    .read<SessionProvider>()
                    .apiService
                    .updateMedicalRecord(
                      recordId: record.id,
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      tags: tagsController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      toothMap: toothMap,
                    );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                _refresh();
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text('Ошибка: $error')));
              } finally {
                if (innerContext.mounted) setState(() => isSaving = false);
              }
            }

            return AlertDialog(
              title: const Text('Редактировать запись'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Заголовок',
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Обязательное поле'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Теги (через запятую)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ToothChart(
                        toothMap: toothMap,
                        onChanged: (updated) {
                          toothMap = updated;
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : submit,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
