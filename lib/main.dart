import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ona_net/core/theme/theme_provider.dart';
import 'package:ona_net/features/customer/data/saved_providers_store.dart';
import 'package:ona_net/features/customer/presentation/home_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
