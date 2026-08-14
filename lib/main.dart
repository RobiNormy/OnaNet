import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ona_net/core/theme/theme_provider.dart';
import 'package:ona_net/features/customer/data/saved_providers_store.dart';
import 'package:ona_net/features/customer/presentation/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty) {
    throw StateError(
      'Missing Supabase configuration. Run Flutter with '
      '--dart-define-from-file=supabase.local.json.',
    );
  }
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SavedProvidersStore()),
      ],
      child: OnaNet(),
    ),
  );
}
