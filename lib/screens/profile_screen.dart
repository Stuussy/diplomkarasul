import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fine.dart';
import '../models/user.dart';
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

  Future<void> _refresh() async {
    await context.read<SessionProvider>().refreshProfile();
    setState(() {
      _finesFuture = context.read<SessionProvider>().apiService.fetchFines();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(
            userName: user.fullName,
            email: user.email,
            onEdit: () => _showEditProfileSheet(user),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.alternate_email,
                  title: 'Email',
                  value: user.email,
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.phone_outlined,
                  title: 'Телефон',
                  value: user.phone?.isNotEmpty == true ? user.phone! : 'Не указан',
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.badge_outlined,
                  title: 'Роль',
                  value: user.role,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Сменить пароль'),
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Выйти из аккаунта'),
                  onTap: () => context.read<SessionProvider>().logout(),
                ),
              ],
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
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Штрафов нет — вы молодец!'),
                  ),
                );
              }
              return Card(
                child: Column(
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
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileSheet(AppUser user) async {
    final firstNameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);
    final phoneController = TextEditingController(text: user.phone ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final session = this.context.read<SessionProvider>();
        final messenger = ScaffoldMessenger.of(this.context);
        final navigator = Navigator.of(this.context);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 24,
          ),
          child: StatefulBuilder(builder: (context, setState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setState(() => isSaving = true);
              final error = await session.updateProfile(
                firstName: firstNameController.text.trim(),
                lastName: lastNameController.text.trim(),
                phone: phoneController.text.trim(),
              );
              setState(() => isSaving = false);
              if (error != null) {
                messenger.showSnackBar(SnackBar(content: Text(error)));
                return;
              }
              navigator.pop();
              messenger.showSnackBar(const SnackBar(content: Text('Профиль обновлен')));
            }

            return Form(
              key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                  TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(labelText: 'Имя'),
                    validator: (value) => value == null || value.isEmpty ? 'Введите имя' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(labelText: 'Фамилия'),
                    validator: (value) => value == null || value.isEmpty ? 'Введите фамилию' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Телефон'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : submit,
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Сохранить изменения'),
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );

    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.userName,
    required this.email,
    required this.onEdit,
  });

  final String userName;
  final String email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        gradient: LinearGradient(
          colors: [Color(0xFF4F8EF7), Color(0xFF6FB2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 32, color: Colors.white),
                  ),
                ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(color: Colors.black54)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
