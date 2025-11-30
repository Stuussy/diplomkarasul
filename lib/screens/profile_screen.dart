import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fine.dart';
import '../providers/session_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<Fine>> _finesFuture;

  @override
  void initState() {
    super.initState();
    _finesFuture = context.read<SessionProvider>().apiService.fetchFines();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blueAccent,
                  child: Text(
                    user?.firstName.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(fontSize: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(user?.email ?? ''),
                const SizedBox(height: 12),
                Text('Роль: ${user?.role ?? '-'}'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showChangePasswordDialog,
                        child: const Text('Сменить пароль'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.read<SessionProvider>().logout(),
                        child: const Text('Выйти'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Штрафы за позднюю отмену',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Fine>>(
          future: _finesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Text('Ошибка: ${snapshot.error}');
            }

            final fines = snapshot.data ?? [];
            if (fines.isEmpty) {
              return const Text('Штрафов нет — вы молодец!');
            }
            return Column(
              children: fines
                  .map(
                    (fine) => ListTile(
                      leading: const Icon(Icons.warning, color: Colors.redAccent),
                      title: Text('${fine.amount.toStringAsFixed(0)} тг'),
                      subtitle: Text(fine.reason),
                      trailing: Text(
                        fine.isPaid ? 'Оплачен' : 'Не оплачен',
                        style: TextStyle(color: fine.isPaid ? Colors.green : Colors.red),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          Future<void> submit() async {
            if (isSubmitting) return;
            if (!formKey.currentState!.validate()) return;
            setState(() => isSubmitting = true);
            final api = context.read<SessionProvider>().apiService;
            try {
              await api.changePassword(
                currentPassword: currentController.text,
                newPassword: newController.text,
              );
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пароль успешно обновлен')),
                );
              }
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Ошибка: $error')));
              }
            } finally {
              if (context.mounted) setState(() => isSubmitting = false);
            }
          }

          return AlertDialog(
            title: const Text('Сменить пароль'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Текущий пароль'),
                    validator: (value) => value == null || value.isEmpty ? 'Введите пароль' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Новый пароль'),
                    validator: (value) =>
                        value != null && value.length >= 6 ? null : 'Мин. 6 символов',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Сохранить'),
              ),
            ],
          );
        });
      },
    );

    currentController.dispose();
    newController.dispose();
  }
}
