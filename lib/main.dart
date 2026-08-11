import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'viewmodels/auth_viewmodel.dart';
import 'views/login_screen.dart';
import 'views/photo_capture_screen.dart';

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Photo d'identité",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF002B48)),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authTokenProvider);
    if (session.isLoading) {
      // Stays behind the native splash (same navy) while the JWT is
      // restored from secure storage, so this never actually flashes.
      return const Scaffold(
        backgroundColor: Color(0xFF002B48),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    FlutterNativeSplash.remove();
    return session.token == null
        ? const LoginScreen()
        : const PhotoCaptureScreen();
  }
}
