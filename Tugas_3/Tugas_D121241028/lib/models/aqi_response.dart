// Model respons Indeks Kualitas Udara (AQI).
//
// Dibentuk dari JSON yang dikirim WAQI.info. Semua angka dibungkus dengan
// konversi aman, sehingga tidak ada ParseException bila salah satu bidang
// kosong atau bertipe tak terduga.

library;

class AqiResponse {
  /// Status mentah dari server ('ok' atau 'error').
  final String status;

  /// Kode galat dari server, bila status bukan 'ok'.
  final String? errorCode;

  /// Nama kota yang diminta.
  final String city;

  /// Nilai AQI (Indeks Kualitas Udara).
  final int aqi;

  /// Identifikasi stasiun pengukur.
  final int stationId;

  /// Kategori kualitas udara (Baik, Sedang, dsb).
  final String category;

  /// Warna yang lazim dipakai untuk kategori tersebut.
  final String color;

  /// Waktu pengukuran terakhir.
  final String time;

  /// Suhu udara (°C), boleh null.
  final double? temperature;

  /// Kelembaban (%), boleh null.
  final double? humidity;

  /// Tekanan udara (hPa), boleh null.
  final double? pressure;

  /// Kecepatan angin (m/s), boleh null.
  final double? windSpeed;

  /// Polutan utama (contoh: pm25).
  final String? dominantPollutant;

  /// Konsentrasi tiap polutan.
  final Map<String, double> pollutants;

  /// Pesan galat, hanya terisi bila [status] bukan 'ok'.
  final String? errorMessage;

  const AqiResponse({
    required this.status,
    this.errorCode,
    required this.city,
    required this.aqi,
    required this.stationId,
    required this.category,
    required this.color,
    required this.time,
    this.temperature,
    this.humidity,
    this.pressure,
    this.windSpeed,
    this.dominantPollutant,
    required this.pollutants,
    this.errorMessage,
  });

  /// Membentuk model dari JSON.
  ///
  /// `json` diharapkan objek berisi kunci `data`. Bila `status` bukan 'ok',
  /// pesan galat diambil dari `data` (WAQI mengirim pesan sebagai string).
  factory AqiResponse.fromJson(Map<String, dynamic> json) {
    final status = (json['status'] as String?) ?? 'unknown';

    // --- Cabang galat -------------------------------------------------
    if (status != 'ok') {
      final raw = json['data'];
      final message = raw is String ? raw : 'Permintaan ditolak server.';
      return AqiResponse(
        status: status,
        errorCode: (json['code'] as String?) ?? 'unknown',
        city: '-',
        aqi: 0,
        stationId: 0,
        category: 'Tidak diketahui',
        color: 'grey',
        time: '-',
        pollutants: const {},
        errorMessage: message,
      );
    }

    // --- Cabang sukses -----------------------------------------------
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    final iaqi = data['iaqi'] as Map<String, dynamic>? ?? const {};
    final dom = (data['dominentpol'] as String?) ?? 'pm25';
    final aqi = _toInt(data['aqi']);

    return AqiResponse(
      status: status,
      city: _cityName(data),
      aqi: aqi,
      stationId: _toInt(data['idx']),
      category: _category(aqi),
      color: _categoryColor(aqi),
      time: _stationTime(data),
      temperature: _readNum(iaqi, 't'),
      humidity: _readNum(iaqi, 'h'),
      pressure: _readNum(iaqi, 'p'),
      windSpeed: _readNum(iaqi, 'w'),
      dominantPollutant: dom,
      pollutants: _pollutants(iaqi),
    );
  }

  // ---------------------------------------------------------------------
  // Pembantu parsing
  // ---------------------------------------------------------------------

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// Mengambil satu nilai numerik dari `iaqi`.
  ///
  /// WAQI membungkus tiap pengukuran sebagai `{"v": <angka>}`.
  static double? _readNum(Map<String, dynamic> iaqi, String key) {
    final v = iaqi[key];
    if (v == null) return null;
    final inner = v is Map ? v['v'] : v;
    if (inner == null) return null;
    if (inner is num) return inner.toDouble();
    return double.tryParse(inner.toString());
  }

  /// WAQI mengirim nama kota bersarang di `data.city.name`.
  static String _cityName(Map<String, dynamic> data) {
    final city = data['city'];
    if (city is Map && city['name'] != null) {
      return city['name'].toString();
    }
    if (city is String) return city;
    return 'Kota tidak diketahui';
  }

  static String _stationTime(Map<String, dynamic> data) {
    final time = data['time'];
    if (time is Map && time['s'] != null) return time['s'].toString();
    return '-';
  }

  /// Kategori AQI mengikuti rentang EPA.
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

  /// Mengambil seluruh pasangan polutan -> konsentrasi.
  static Map<String, double> _pollutants(Map<String, dynamic> iaqi) {
    final result = <String, double>{};
    for (final key in iaqi.keys) {
      final parsed = _readNum(iaqi, key);
      if (parsed != null) result[key] = parsed;
    }
    return result;
  }
}
