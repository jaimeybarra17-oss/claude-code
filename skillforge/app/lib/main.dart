import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/supabase_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Exposes the initialized Supabase service to the widget tree.
final supabaseProvider = Provider<SupabaseService>(
  (_) => throw UnimplementedError('initialized in main()'),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if configured. If it fails (e.g. the web preview build
  // ships placeholder env), still render the UI with demo data rather than
  // white-screening — the showcase screens don't require a live client.
  SupabaseService? supabase;
  try {
    await dotenv.load(fileName: '.env');
    supabase = await SupabaseService.initialize();
  } catch (e) {
    debugPrint('SkillForge: running without a live backend ($e)');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (supabase != null) supabaseProvider.overrideWithValue(supabase),
      ],
      child: SkillForgeApp(isSignedIn: supabase?.isSignedIn ?? false),
    ),
  );
}

class SkillForgeApp extends StatelessWidget {
  const SkillForgeApp({super.key, required this.isSignedIn});

  final bool isSignedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SkillForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: AppRouter.build(isSignedIn: isSignedIn),
    );
  }
}
