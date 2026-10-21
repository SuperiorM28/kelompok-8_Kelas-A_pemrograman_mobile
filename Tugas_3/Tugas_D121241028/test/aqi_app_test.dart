// Pengujian widget Air Quality App.
//
// Membuktikan ketiga state yang diminta tugas:
//   1. Loading  — ConnectionState.waiting
//   2. Success  — snapshot.hasData
//   3. Error    — snapshot.hasError
//
// PENTING tentang FutureBuilder (dikutip dari dokumentasi Flutter):
//   "A side-effect of this is that providing a new but already-completed
//    future to a FutureBuilder will result in a single frame in the
//    ConnectionState.waiting state."
//
// Artinya state `waiting` hanya terlihat bila `builder` benar-benar dipanggil
// sebelum Future selesai. Di lingkungan pengujian, Future yang dibuat di
// dalam layanan selesai tepat saat frame dibangun, sehingga `waiting`
// terlewat. Karena itu uji Loading memasang dulu sebuah Completer yang belum
// dituntaskan, sehingga `waiting` pasti terlihat.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:air_quality_app/models/aqi_response.dart';
import 'package:air_quality_app/services/aqi_service.dart';
import 'package:air_quality_app/screens/home_screen.dart';

// ---------------------------------------------------------------------------
// Tiruan HTTP
// ---------------------------------------------------------------------------

/// Layanan yang menjawab dengan [body].
AqiService _serviceReturning(String body) {
  return AqiService(
    token: 'test-token',
    fetcher: (_) async => http.Response(body, 200),
  );
}

/// Layanan yang selalu gagal dengan [error].
AqiService _serviceThrowing(Object error) {
  return AqiService(
    token: 'test-token',
    fetcher: (_) async => throw error,
  );
}

// ---------------------------------------------------------------------------
// JSON contoh
// ---------------------------------------------------------------------------

const String _okBody = '''
{
  "status": "ok",
  "data": {
    "aqi": 78,
    "idx": 1420,
    "city": {"name": "Jakarta"},
    "time": {"s": "14:00"},
    "dominentpol": "pm25",
    "iaqi": {
      "t": {"v": 31.2},
      "h": {"v": 64},
      "p": {"v": 1012},
      "w": {"v": 3.4},
      "pm25": {"v": 24.6},
      "pm10": {"v": 41.2},
      "o3": {"v": 18.4}
    }
  }
}
''';

const String _errorBody = '{"status": "error", "data": "Unknown station"}';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Future<void> _pumpHome(WidgetTester tester, AqiService service) async {
  await tester.pumpWidget(
    MaterialApp(home: HomeScreen(serviceOverride: service)),
  );
  await tester.pump();
}

Future<void> _cari(WidgetTester tester, String kota) async {
  await tester.enterText(find.byType(TextField), kota);
  await tester.tap(find.text('Cari'));
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Uji
// ---------------------------------------------------------------------------

void main() {
  testWidgets('LOADING — kotak tunggu tampil saat permintaan berjalan',
      (tester) async {
    // Completer yang belum dituntaskan menjamin future masih menunggu
    // saat frame pertama dibangun.
    final completer = Completer<http.Response>();

    final service = AqiService(
      token: 'test-token',
      fetcher: (_) => completer.future,
    );

    await _pumpHome(tester, service);
    await _cari(tester, 'Jakarta');
    await tester.pump();

    // --- STATE 1: LOADING ---
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Mengambil data dari server…'), findsOneWidget);

    // Tuntaskan permintaan, lalu periksa beralih ke SUCCESS.
    completer.complete(http.Response(_okBody, 200));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('78'), findsOneWidget);
  });

  testWidgets('SUCCESS — kartu AQI tampil setelah data tiba', (tester) async {
    await _pumpHome(tester, _serviceReturning(_okBody));

    await _cari(tester, 'Jakarta');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('Jakarta'), findsWidgets);
    expect(find.text('78'), findsOneWidget);
    expect(find.text('Sedang'), findsOneWidget);
    expect(find.text('Konsentrasi Polutan (µg/m³)'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ERROR — pesan dan tombol Coba Lagi tampil saat jaringan gagal',
      (tester) async {
    await _pumpHome(tester, _serviceThrowing(http.ClientException('offline')));

    await _cari(tester, 'Jakarta');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('Gagal mengambil data'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ERROR — kota tidak ditemukan di server', (tester) async {
    await _pumpHome(tester, _serviceReturning(_errorBody));

    await _cari(tester, 'KotaTidakAda');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('Gagal mengambil data'), findsOneWidget);
    expect(find.text('Unknown station'), findsOneWidget);
  });

  testWidgets('kosong — snackbar memperingatkan bila kota belum diisi',
      (tester) async {
    await _pumpHome(tester, _serviceReturning(_okBody));

    await tester.tap(find.text('Cari'));
    await tester.pump();

    expect(find.text('Isi nama kota terlebih dahulu.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  test('parsing JSON — nilai diuraikan dengan benar', () {
    final parsed = AqiResponse.fromJson(
      jsonDecode(_okBody) as Map<String, dynamic>,
    );

    expect(parsed.city, 'Jakarta');
    expect(parsed.aqi, 78);
    expect(parsed.category, 'Sedang');
    expect(parsed.temperature, 31.2);
    expect(parsed.humidity, 64);
    expect(parsed.pressure, 1012);
    expect(parsed.windSpeed, 3.4);
    expect(parsed.dominantPollutant, 'pm25');
    expect(parsed.pollutants['pm25'], 24.6);
  });

  test('parsing JSON — cabang galat menangkap pesan', () {
    final parsed = AqiResponse.fromJson(
      jsonDecode(_errorBody) as Map<String, dynamic>,
    );

    expect(parsed.status, 'error');
    expect(parsed.errorMessage, 'Unknown station');
  });
}
