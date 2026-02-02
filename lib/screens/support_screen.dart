import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/support_message.dart';
import '../providers/session_provider.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _newThreadController = TextEditingController();
  final _replyController = TextEditingController();
  final List<String> _categories = const [
    'Запись',
    'Оплата',
    'Документы',
    'Жалоба',
    'Другое',
  ];
  String _selectedCategory = 'Запись';
  bool _isSending = false;
  bool _isReplying = false;
  bool _creatingNewThread = false;
  SupportMessage? _selectedThread;
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

  Future<void> _sendNewThread() async {
    if (_newThreadController.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      await api.sendSupportMessage(
        _newThreadController.text.trim(),
        category: _selectedCategory,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Сообщение отправлено администратору.')));
      _newThreadController.clear();
      setState(() {
        _creatingNewThread = false;
        _selectedThread = null;
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
    if (_selectedThread == null || _replyController.text.trim().isEmpty) return;
    setState(() => _isReplying = true);
    final api = context.read<SessionProvider>().apiService;
    try {
      final updated = await api.replySupportMessage(
        messageId: _selectedThread!.id,
        content: _replyController.text.trim(),
      );
      if (!mounted) return;
      _replyController.clear();
      setState(() {
        _selectedThread = updated;
        _threadsFuture = _loadThreads();
      });
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
      appBar: AppBar(title: const Text('Поддержка')),
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

          _selectedThread ??= threads.first;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButton<SupportMessage>(
                  value: _selectedThread,
                  isExpanded: true,
                  items: threads
                      .map(
                        (thread) => DropdownMenuItem(
                          value: thread,
                          child: Text(
                            'Обращение ${thread.id.substring(0, 6)} • ${thread.status}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedThread = value);
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _selectedThread == null
                      ? const SizedBox.shrink()
                      : _ChatHistory(thread: _selectedThread!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _replyController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Ваш ответ',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: _isReplying ? null : _sendReply,
                      icon: _isReplying
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _creatingNewThread = true;
                      });
                    },
                    child: const Text('Создать новое обращение'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewThreadForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Опишите вашу проблему — администратор свяжется с вами.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            items: _categories
                .map((category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedCategory = value);
            },
            decoration: const InputDecoration(
              labelText: 'Категория',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newThreadController,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Напишите сообщение...',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSending ? null : _sendNewThread,
            child: _isSending
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Отправить администратору'),
          ),
          if (!_creatingNewThread)
            const SizedBox.shrink()
          else
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
      return const Center(child: Text('Нет сообщений'));
    }
    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (context, index) {
        final entry = history[index];
        final isPatient = entry.sender?.role == 'patient';
        return Align(
          alignment: isPatient ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPatient ? Colors.blue.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment:
                  isPatient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  entry.sender?.fullName ?? 'Сотрудник',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(entry.content),
                const SizedBox(height: 4),
                Text(
                  '${entry.createdAt.day.toString().padLeft(2, '0')}.'
                  '${entry.createdAt.month.toString().padLeft(2, '0')} '
                  '${entry.createdAt.hour.toString().padLeft(2, '0')}:'
                  '${entry.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
