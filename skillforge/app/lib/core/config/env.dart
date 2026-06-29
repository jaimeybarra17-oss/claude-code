import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to runtime configuration loaded from `.env`.
/// Fails fast at startup if a required key is missing.
class Env {
  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  static String _require(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError('Missing required env var: $key');
    }
    return value;
  }
}
