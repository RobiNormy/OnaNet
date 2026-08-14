import 'package:supabase_flutter/supabase_flutter.dart';

/// Single source of truth for OnaNet's authenticated Supabase session.
abstract final class AuthSession {
  static GoTrueClient get _auth => Supabase.instance.client.auth;

  static User? get currentUser => _auth.currentUser;
  static Session? get currentSession => _auth.currentSession;
  static String? get accessToken => currentSession?.accessToken;
  static bool get isSignedIn => currentUser != null;

  static Stream<User?> get userChanges =>
      _auth.onAuthStateChange.map((event) => event.session?.user);
}
