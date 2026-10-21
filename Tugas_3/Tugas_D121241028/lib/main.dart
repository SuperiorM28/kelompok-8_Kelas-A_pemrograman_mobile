// Titik masuk Aplikasi Pengecek Kualitas Udara.
//
// Menyiapkan penyimpanan lokal (SharedPreferences + SQLite) lebih dulu
// sehingga layar utama bisa langsung membacanya.

library;

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Siapkan SharedPreferences dan basis data SQLite sebelum aplikasi mulai.
  await StorageService.instance.init();

  runApp(const AirQualityApp());
}

class AirQualityApp extends StatelessWidget {
  const AirQualityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kualitas Udara',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B2265),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
      ),
      home: const HomeScreen(),
    );
  }
}
