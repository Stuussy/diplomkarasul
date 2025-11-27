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
        ElevatedButton.icon(
          onPressed: () => context.read<SessionProvider>().logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Выйти из аккаунта'),
        ),
      ],
    );
  }
}
