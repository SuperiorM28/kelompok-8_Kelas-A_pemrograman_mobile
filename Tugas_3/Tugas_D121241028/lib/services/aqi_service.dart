// Lapisan akses REST API.
//
// Aplikasi mencoba dua sumber data, keduanya tanpa kunci API:
//
//   1. Open-Meteo (geocoding + air quality + forecast) — sumber utama.
//      Terbuka untuk umum, tidak butuh token, dan melaporkan AQI
//      (european_aqi & us_aqi) lengkap dengan polutan dan cuaca.
//   2. WAQI.info — cadangan, dipakai bila token diisi.
//
// Bila keduanya gagal, aplikasi jatuh ke data contoh agar tetap bisa
// dijalankan. Semua galat dibungkus AqiError sehingga tidak pernah Crash.

library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/aqi_response.dart';

/// Galat yang dilempar lapisan service.
class AqiError implements Exception {
  /// Penjelasan yang bisa ditampilkan langsung ke pengguna.
  final String message;

  /// Penyebab teknis, berguna untuk debug.
  final String detail;

  const AqiError(this.message, [this.detail = '']);

  @override
  String toString() => 'AqiError: $message${detail.isEmpty ? '' : ' ($detail)'}';
}

/// Klien data kualitas udara.
class AqiService {
  /// Token WAQI.info.
  ///
  /// Opsional. Isi dari https://aqicn.org/api/ bila ingin memakai WAQI
  /// sebagai sumber. Bila kosong, WAQI dilewati dan Open-Meteo dipakai.
  final String token;

  /// Pengganti pengambilan HTTP.
  ///
  /// Dipakai pengujian untuk menyuntikkan tiruan tanpa menurunkan kelas.
  final Future<http.Response> Function(Uri uri) _fetcher;

  /// Jeda sebelum sumber cadangan dicoba, agar Loading sempat terlihat.
  final Duration _fallbackDelay;

  const AqiService({
    this.token = '',
    Future<http.Response> Function(Uri)? fetcher,
    Duration fallbackDelay = const Duration(milliseconds: 600),
  })  : _fetcher = fetcher ?? _defaultFetch,
        _fallbackDelay = fallbackDelay;

  /// Pengambilan bawaan.
  static Future<http.Response> _defaultFetch(Uri uri) => http.get(uri);

  // ---------------------------------------------------------------------
  // Alamat API
  // ---------------------------------------------------------------------

  static const String _geoBase = 'https://geocoding-api.open-meteo.com/v1/search';
  static const String _airBase =
      'https://air-quality-api.open-meteo.com/v1/air-quality';
  static const String _wxBase = 'https://api.open-meteo.com/v1/forecast';
  static const String _waqiBase = 'https://api.waqi.info';

  static const Duration _timeout = Duration(seconds: 15);

  // ---------------------------------------------------------------------
  // Titik masuk
  // ---------------------------------------------------------------------

  /// Mengambil data AQI kota berdasarkan nama.
  ///
  /// Urutan: Open-Meteo → WAQI (bila token ada).
  ///
  /// Bila kota tidak ditemukan di sumber mana pun, AqiError dilempar —
  /// bukan data contoh. Data contoh hanya dipakai bila sumber merespons
  /// tetapi isinya tidak bisa dipakai.
  Future<AqiResponse> fetchByCity(String city) async {
    final trimmed = city.trim();
    if (trimmed.isEmpty) {
      throw const AqiError('Nama kota belum diisi.');
    }

    // --- 1. Open-Meteo (tanpa token) --------------------------------
    Object? lastError;
    try {
      return await _fromOpenMeteo(trimmed);
    } on AqiError catch (e) {
      lastError = e;
    } catch (e) {
      lastError = e;
    }

    // --- 2. WAQI (hanya bila token diisi) ---------------------------
    if (token.isNotEmpty) {
      try {
        return await _fromWaqi(trimmed);
      } on AqiError catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
      }
    }

    // --- Gagal total ------------------------------------------------
    if (lastError is AqiError) {
      throw lastError;
    }
    final detail = lastError.toString();
    throw AqiError(
      'Kota "$trimmed" tidak ditemukan.',
      detail.isEmpty ? '' : detail,
    );
  }

  // ---------------------------------------------------------------------
  // Open-Meteo
  // ---------------------------------------------------------------------

  /// Mengambil data dari Open-Meteo: geocoding lalu kualitas udara + cuaca.
  Future<AqiResponse> _fromOpenMeteo(String city) async {
    final coords = await _geocode(city);

    // Kedua panggilan dijalankan bersamaan karena saling bebas.
    final responses = await Future.wait([
      _get(Uri.parse(
        '$_airBase?latitude=${coords.lat}&longitude=${coords.lon}'
        '&current=european_aqi,us_aqi,pm10,pm2_5,carbon_monoxide,'
        'nitrogen_dioxide,sulphur_dioxide,ozone&timezone=auto',
      )),
      _get(Uri.parse(
        '$_wxBase?latitude=${coords.lat}&longitude=${coords.lon}'
        '&current=temperature_2m,relative_humidity_2m,pressure_msl,'
        'wind_speed_10m&timezone=auto',
      )),
    ]);

    final air = _decode(responses[0]);
    final weather = _decode(responses[1]);

    final current = air['current'] as Map<String, dynamic>? ?? const {};
    final wx = weather['current'] as Map<String, dynamic>? ?? const {};

    // Open-Meteo memberi dua skala; pakai US AQI karena rentangnya lebih
    // lazim dipakai, lalu ganti ke European AQI bila yang itu kosong.
    final rawAqi = current['us_aqi'] ?? current['european_aqi'];
    final aqi = _toInt(rawAqi);
    if (aqi <= 0) {
      throw const AqiError('Server tidak mengirim nilai AQI.');
    }

    return AqiResponse(
      status: 'ok',
      city: coords.name,
      aqi: aqi,
      stationId: 0,
      category: _category(aqi),
      color: _categoryColor(aqi),
      time: _timeLabel(current['time']),
      temperature: _toDouble(wx['temperature_2m']),
      humidity: _toDouble(wx['relative_humidity_2m']),
      pressure: _toDouble(wx['pressure_msl']),
      windSpeed: _toDouble(wx['wind_speed_10m']),
      dominantPollutant: 'pm25',
      pollutants: {
        'pm25': _toDouble(current['pm2_5']) ?? 0,
        'pm10': _toDouble(current['pm10']) ?? 0,
        'o3': _toDouble(current['ozone']) ?? 0,
        'no2': _toDouble(current['nitrogen_dioxide']) ?? 0,
        'so2': _toDouble(current['sulphur_dioxide']) ?? 0,
        'co': _toDouble(current['carbon_monoxide']) ?? 0,
      },
    );
  }

  /// Mencari koordinat kota.
  Future<_Coords> _geocode(String city) async {
    final uri = Uri.parse(
      '$_geoBase?name=${Uri.encodeQueryComponent(city)}'
      '&count=1&language=id&format=json',
    );

    final response = await _get(uri);
    final decoded = _decode(response);
    final results = decoded['results'];

    if (results is! List || results.isEmpty) {
      throw AqiError('Kota "$city" tidak ditemukan.');
    }

    final first = results.first as Map<String, dynamic>;
    return _Coords(
      lat: _toDouble(first['latitude']) ?? 0,
      lon: _toDouble(first['longitude']) ?? 0,
      name: (first['name'] as String?) ?? city,
    );
  }

  // ---------------------------------------------------------------------
  // WAQI (cadangan)
  // ---------------------------------------------------------------------

  Future<AqiResponse> _fromWaqi(String city) async {
    await Future<void>.delayed(_fallbackDelay);

    final uri = Uri.parse('$_waqiBase/feed/$city/')
        .replace(queryParameters: {'token': token});

    final response = await _get(uri);
    final decoded = _decode(response);

    final parsed = AqiResponse.fromJson(decoded);
    if (parsed.status != 'ok') {
      throw AqiError(parsed.errorMessage ?? 'Permintaan ditolak server.');
    }
    return parsed;
  }

  // ---------------------------------------------------------------------
  // Pembantu HTTP
  // ---------------------------------------------------------------------

  /// Melakukan GET dengan penanganan galat jaringan.
  Future<http.Response> _get(Uri uri) async {
    http.Response response;
    try {
      response = await _fetcher(uri).timeout(_timeout);
    } on SocketException {
      throw const AqiError('Tidak ada koneksi internet.', 'SocketException');
    } on HttpException {
      throw const AqiError('Koneksi terputus di tengah jalan.', 'HttpException');
    } on FormatException {
      rethrow;
    } catch (e) {
      if (e is AqiError) rethrow;
      throw const AqiError('Permintaan gagal dikirim.', 'cek koneksi Anda');
    }

    if (response.statusCode == 404) {
      throw const AqiError('Data tidak ditemukan di server.', '404');
    }
    if (response.statusCode != 200) {
      throw AqiError(
        'Server menjawab ${response.statusCode}.',
        'coba beberapa saat lagi',
      );
    }
    return response;
  }

  /// Mengurai badan respons menjadi peta.
  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AqiError('Jawaban server tidak terbaca.', 'bukan JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AqiError('Format jawaban server tidak dikenal.');
    }
    return decoded;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String _timeLabel(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    // "2026-10-22T02:00" -> "02:00"
    final match = RegExp(r'T(\d{2}:\d{2})').firstMatch(s);
    return match?.group(1) ?? s;
  }

  // ---------------------------------------------------------------------
  // Kategori & warna (rentang US EPA)
  // ---------------------------------------------------------------------

  static String _category(int aqi) {
    if (aqi <= 50) return 'Baik';
    if (aqi <= 100) return 'Sedang';
    if (aqi <= 150) return 'Tidak Sehat untuk Kelompok Sensitif';
    if (aqi <= 200) return 'Tidak Sehat';
    if (aqi <= 300) return 'Sangat Tidak Sehat';
    return 'Berbahaya';
  }

  static String _categoryColor(int aqi) {
    if (aqi <= 50) return 'green';
    if (aqi <= 100) return 'yellow';
    if (aqi <= 150) return 'orange';
    if (aqi <= 200) return 'red';
    if (aqi <= 300) return 'purple';
    return 'maroon';
  }

}

/// Koordinat hasil geocoding.
class _Coords {
  final double lat;
  final double lon;
  final String name;

  const _Coords({required this.lat, required this.lon, required this.name});
}
