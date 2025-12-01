import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medical_record.dart';
import '../models/user.dart';
import '../providers/session_provider.dart';
import '../widgets/patient_ui.dart';

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
      _currentUser?.role == 'admin' || _currentUser?.role == 'director';

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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F9FC), Color(0xFFEFF3FA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
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
                  return PatientCard(
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  Future<void> _showCreateDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final tagsController = TextEditingController();
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Заголовок'),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Обязательное поле'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Описание'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Теги (через запятую)',
                      ),
                    ),
                  ],
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Заголовок'),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Обязательное поле'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Описание'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Теги (через запятую)',
                      ),
                    ),
                  ],
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
