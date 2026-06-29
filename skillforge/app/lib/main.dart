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
  await dotenv.load(fileName: '.env');
  final supabase = await SupabaseService.initialize();

  runApp(
    ProviderScope(
      overrides: [supabaseProvider.overrideWithValue(supabase)],
      child: SkillForgeApp(isSignedIn: supabase.isSignedIn),
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
