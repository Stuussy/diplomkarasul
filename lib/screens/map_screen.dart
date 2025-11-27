import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/clinic.dart';
import '../providers/session_provider.dart';
import 'support_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<List<Clinic>> _futureClinics;

  @override
  void initState() {
    super.initState();
    _futureClinics = context.read<SessionProvider>().apiService.fetchClinics();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 260,
          color: Colors.grey[300],
          child: const Center(
            child: Text(
              'Карта клиник появится после подключения API ключей',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Все стоматологии сети:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Clinic>>(
            future: _futureClinics,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Ошибка: ${snapshot.error}'));
              }
              final clinics = snapshot.data ?? [];
              if (clinics.isEmpty) {
                return const Center(child: Text('Клиники пока не добавлены.'));
              }
              return ListView.builder(
                itemCount: clinics.length,
                itemBuilder: (context, index) {
                  final clinic = clinics[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_hospital, color: Colors.redAccent),
                      title: Text(clinic.name),
                      subtitle: Text(clinic.address ?? 'Адрес уточняется'),
                      trailing: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SupportScreen()),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
