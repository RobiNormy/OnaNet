import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ona_net/core/notifications/push_notification_service.dart';
import 'package:ona_net/core/theme/theme_provider.dart';
import 'package:ona_net/features/customer/data/saved_providers_store.dart';
import 'package:ona_net/features/customer/presentation/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://yuisvhqfbmioxqghankl.supabase.co',
);
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_PRWOKp80WG8yt1rsWZQomA_RUcv6Siw',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
  await GoogleSignIn.instance.initialize();
  await PushNotificationService.initialise();
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
