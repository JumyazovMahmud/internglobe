import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:internglobe/screens/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'screens/root_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,   // ← Use this
  );
  await Supabase.initialize(
    url: 'https://cfgezwtetrtgzgmhfwoh.supabase.co',
    anonKey: 'sb_publishable_XPg1rCq8klF-R1VIR-K6ZA_yF65xens',
  );
  runApp(const InternGlobeApp());
}

class InternGlobeApp extends StatelessWidget {
  const InternGlobeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InternGlobe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1565C0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          primary: const Color(0xFF1565C0),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF1565C0),
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF1565C0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          primary: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF1565C0),
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
          elevation: 2,
          color: Color(0xFF1E293B),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}