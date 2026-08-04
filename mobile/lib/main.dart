import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/welcome_screen.dart';
import 'screens/client/client_shell.dart';
import 'screens/professional/professional_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tltbtwctxaxsevcxwwco.supabase.co',
    publishableKey: 'sb_publishable_7Wige7bkmk3CgHxcch1N6w_aZcBVR7i',
  );

  runApp(const ShapeRushApp());
}

class ShapeRushApp extends StatelessWidget {
  const ShapeRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShapeRush',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late Future<Widget> _startPage;

  @override
  void initState() {
    super.initState();
    _startPage = _resolveStartPage();
  }

  Future<Widget> _resolveStartPage() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return const WelcomeScreen();

    final profile = await supabase
        .from('profiles')
        .select('user_type')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      await supabase.auth.signOut();
      return const WelcomeScreen();
    }

    final userType =
        profile['user_type']?.toString().trim().toLowerCase() ?? '';

    if (userType == 'free' || userType == 'priority') {
      return const ClientShell();
    }

    if (userType == 'fitness professional') {
      final professional = await supabase
          .from('fitness_professional')
          .select('approved')
          .eq('profile_id', user.id)
          .maybeSingle();

      if (professional?['approved'] == true) {
        return const ProfessionalShell();
      }
    }

    await supabase.auth.signOut();
    return const WelcomeScreen();
  }

  void _retry() {
    setState(() => _startPage = _resolveStartPage());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _startPage,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to restore your session.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return snapshot.data ?? const WelcomeScreen();
      },
    );
  }
}
