import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/session_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() {
    return context.read<SessionProvider>().apiService.fetchNotifications();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _markAllRead() async {
    final api = context.read<SessionProvider>().apiService;
    await api.markAllNotificationsRead();
    await _refresh();
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    final api = context.read<SessionProvider>().apiService;
    await api.markNotificationRead(notification.id);
    await _refresh();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$day.$month • $time';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'appointment':
        return Icons.event_available_outlined;
      case 'support':
        return Icons.support_agent_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Прочитать все'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('Ошибка: ${snapshot.error}')),
                ],
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 140),
                  Center(child: Text('Пока нет уведомлений.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notification = items[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: notification.isRead
                          ? Colors.transparent
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  tileColor: notification.isRead
                      ? Colors.grey.shade100
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  leading: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(_iconForType(notification.type)),
                  ),
                  title: Text(notification.title),
                  subtitle: Text('${notification.body}\n${_formatDate(notification.createdAt)}'),
                  isThreeLine: true,
                  onTap: () => _markRead(notification),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
