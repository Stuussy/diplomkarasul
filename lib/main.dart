import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'navigation_container.dart';
import 'providers/session_provider.dart';
import 'screens/auth/login_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'theme/clinic_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await _requestInitialPermissions();
  runApp(const DentalApp());
}

Future<void> _requestInitialPermissions() async {
  final permissions = <Permission>[
    Permission.camera,
    Permission.notification,
  ];
  for (final permission in permissions) {
    final status = await permission.status;
    if (!status.isGranted) {
      await permission.request();
    }
  }
}

class DentalApp extends StatelessWidget {
  const DentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(apiService),
        ),
      ],
      child: MaterialApp(
        title: 'Dental AI',
        theme: ClinicTheme.light(),
        home: const _AuthGate(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        if (session.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!session.isAuthenticated) {
          return const LoginScreen();
        }
        return const MainNavigationScreen();
      },
    );
  }
}
