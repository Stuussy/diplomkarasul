import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'navigation_container.dart';
import 'providers/session_provider.dart';
import 'screens/auth/login_screen.dart';
import 'services/api_service.dart';
import 'theme/clinic_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DentalApp());
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
