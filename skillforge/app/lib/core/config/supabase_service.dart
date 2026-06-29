import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Thin wrapper around the Supabase client + the typed calls the client makes.
/// Reads go through PostgREST (guarded by RLS); AI goes through Edge Functions.
class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient _client;

  static Future<SupabaseService> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
    return SupabaseService(Supabase.instance.client);
  }

  String? get userId => _client.auth.currentUser?.id;
  bool get isSignedIn => userId != null;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithOtp(String email) =>
      _client.auth.signInWithOtp(email: email);

  Future<void> signOut() => _client.auth.signOut();

  /// Fetch the current user's profile (RLS scopes it to them).
  Future<Map<String, dynamic>?> fetchProfile() async {
    final id = userId;
    if (id == null) return null;
    return _client.from('profiles').select().eq('id', id).maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchCareers() async =>
      List<Map<String, dynamic>>.from(
        await _client.from('careers').select().order('sort_order'),
      );

  Future<Map<String, dynamic>?> fetchActiveEnrollment() async {
    final id = userId;
    if (id == null) return null;
    return _client
        .from('enrollments')
        .select()
        .eq('user_id', id)
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  /// Stream a reply from the AI coach Edge Function (plain-text deltas).
  Future<String> askCoach({String? threadId, required String message}) async {
    final res = await _client.functions.invoke(
      'ai-coach',
      body: {'threadId': threadId, 'message': message},
    );
    return res.data is String ? res.data as String : res.data.toString();
  }
}
