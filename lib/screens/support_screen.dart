import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/support_message.dart';
import '../providers/session_provider.dart';
import '../theme/clinic_theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _newThreadController = TextEditingController();
  final _replyController = TextEditingController();
  final List<String> _categories = const ['Запись', 'Оплата', 'Документы', 'Жалоба', 'Другое'];
  String _selectedCategory = 'Запись';
  bool _isSending = false;
  bool _isReplying = false;
  bool _creatingNewThread = false;
  String? _selectedThreadId; // храним только id, не объект
  late Future<List<SupportMessage>> _threadsFuture;

  @override
  void initState() {
    super.initState();
    _threadsFuture = _loadThreads();
  }

  @override
  void dispose() {
    _newThreadController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<List<SupportMessage>> _loadThreads() {
    return context.read<SessionProvider>().apiService.fetchMySupportThreads();
  }

  /// Перезагрузить переписку, чтобы увидеть новые ответы менеджера.
  Future<void> _refreshThreads() async {
    setState(() => _threadsFuture = _loadThreads());
  }

  Future<void> _sendNewThread() async {
    if (_newThreadController.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    HapticFeedback.lightImpact();
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.sendSupportMessage(
        _newThreadController.text.trim(),
        category: _selectedCategory,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Сообщение отправлено ✓'),
          backgroundColor: ClinicTheme.mint,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _newThreadController.clear();
      setState(() {
        _creatingNewThread = false;
        _selectedThreadId = null; // при перезагрузке выберем первый
        _threadsFuture = _loadThreads();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendReply() async {
    if (_selectedThreadId == null || _replyController.text.trim().isEmpty) return;
    setState(() => _isReplying = true);
    HapticFeedback.lightImpact();
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.replySupportMessage(
        messageId: _selectedThreadId!,
        content: _replyController.text.trim(),
      );
      if (!mounted) return;
      _replyController.clear();
      setState(() => _threadsFuture = _loadThreads());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClinicTheme.mist,
      appBar: AppBar(
        title: const Text('Поддержка'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _refreshThreads,
            icon: const Icon(LucideIcons.refreshCcw, size: 20),
          ),
          IconButton(
            tooltip: 'Новое обращение',
            onPressed: () => setState(() => _creatingNewThread = true),
            icon: const Icon(LucideIcons.plusCircle, size: 22),
          ),
        ],
      ),
      body: FutureBuilder<List<SupportMessage>>(
        future: _threadsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final threads = snapshot.data ?? [];
          if (threads.isEmpty || _creatingNewThread) {
            return _buildNewThreadForm();
          }

          // Синхронизируем выбранный id: если нет — берём первый поток.
          // Используем String-id вместо объекта, чтобы избежать краша
          // DropdownButton из-за reference equality после перезагрузки списка.
          _selectedThreadId ??= threads.first.id;
          if (!threads.any((t) => t.id == _selectedThreadId)) {
            _selectedThreadId = threads.first.id;
          }
          final selectedThread = threads.firstWhere((t) => t.id == _selectedThreadId);

          return Column(
            children: [
              // Thread selector
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: ClinicTheme.snow,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: ClinicTheme.shadowSm,
                  ),
                  child: DropdownButton<String>(
                    value: _selectedThreadId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: threads
                        .map((thread) => DropdownMenuItem(
                              value: thread.id,
                              child: Text(
                                'Обращение ${thread.id.substring(0, 6)} • ${thread.status}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedThreadId = value);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Chat
              Expanded(
                child: _ChatHistory(thread: selectedThread),
              ),

              // Input bar
              Container(
                padding: EdgeInsets.fromLTRB(
                  20, 12, 12, 12 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: ClinicTheme.snow,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0C000000),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Ваш ответ…',
                          filled: true,
                          fillColor: ClinicTheme.mist,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: ClinicTheme.azure,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _isReplying ? null : _sendReply,
                        icon: _isReplying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNewThreadForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Опишите вашу проблему — администратор свяжется с вами.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          // Category chips
          Text('Категория', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final selected = cat == _selectedCategory;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = cat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? ClinicTheme.azure : ClinicTheme.snow,
                    borderRadius: BorderRadius.circular(20),
                    border: selected ? null : Border.all(color: ClinicTheme.mist),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: selected ? Colors.white : ClinicTheme.midnight,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          TextField(
            controller: _newThreadController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Напишите сообщение…',
              filled: true,
              fillColor: ClinicTheme.snow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isSending ? null : _sendNewThread,
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Отправить'),
            ),
          ),
          if (_creatingNewThread) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() => _creatingNewThread = false);
                  _threadsFuture = _loadThreads();
                },
                child: const Text('Вернуться к переписке'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatHistory extends StatelessWidget {
  const _ChatHistory({required this.thread});

  final SupportMessage thread;

  @override
  Widget build(BuildContext context) {
    final history = thread.history;
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.messageCircle, size: 40, color: ClinicTheme.slate),
            const SizedBox(height: 8),
            Text('Нет сообщений', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final entry = history[index];
        final isPatient = entry.sender?.role == 'patient';
        return Align(
          alignment: isPatient ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPatient ? ClinicTheme.azure : ClinicTheme.snow,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isPatient ? 18 : 4),
                bottomRight: Radius.circular(isPatient ? 4 : 18),
              ),
              boxShadow: ClinicTheme.shadowSm,
            ),
            child: Column(
              crossAxisAlignment:
                  isPatient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  entry.sender?.fullName ?? 'Сотрудник',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isPatient ? Colors.white70 : ClinicTheme.slate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.content,
                  style: TextStyle(
                    color: isPatient ? Colors.white : ClinicTheme.midnight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.createdAt.day.toString().padLeft(2, '0')}.${entry.createdAt.month.toString().padLeft(2, '0')} '
                  '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isPatient ? Colors.white54 : ClinicTheme.slate,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
