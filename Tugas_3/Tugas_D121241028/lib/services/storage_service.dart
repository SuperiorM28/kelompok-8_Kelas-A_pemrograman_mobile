// Lapisan penyimpanan lokal.
//
// Memenuhi kriteria 3 tugas dengan menyediakan DUA mekanisme:
//   1. SharedPreferences — menyimpan "kota terakhir yang dicari".
//   2. SQLite (sqflite)  — menyimpan riwayat pencarian.
//
// Semua operasi dibungkus try/catch: kegagalan penyimpanan tidak pernah
// membuat aplikasi Crash, dan pencarian tetap bisa berjalan.

library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Satu entri riwayat pencarian.
class SearchHistory {
  final int? id;
  final String city;
  final int aqi;
  final String category;
  final String searchedAt;

  const SearchHistory({
    this.id,
    required this.city,
    required this.aqi,
    required this.category,
    required this.searchedAt,
  });

  /// Dari baris tabel SQLite.
  factory SearchHistory.fromRow(Map<String, Object?> row) {
    return SearchHistory(
      id: row['id'] as int?,
      city: (row['city'] as String?) ?? '-',
      aqi: (row['aqi'] as int?) ?? 0,
      category: (row['category'] as String?) ?? '-',
      searchedAt: (row['searched_at'] as String?) ?? '-',
    );
  }

  /// Menuju baris tabel SQLite.
  Map<String, Object?> toRow() => {
        'city': city,
        'aqi': aqi,
        'category': category,
        'searched_at': searchedAt,
      };
}

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const String _lastCityKey = 'last_city';

  Database? _db;
  SharedPreferences? _prefs;

  bool _initialised = false;

  /// Menandakan inisialisasi sudah pernah dicoba.
  ///
  /// Bila SharedPreferences tidak tersedia (mis. di pengujian), aplikasi
  /// tetap jalan tanpa penyimpanan — tidak ada Crash.
  bool get isInitialised => _initialised;

  /// Menyiapkan SharedPreferences dan basis data.
  ///
  /// Dipanggil sekali dari `main()` sebelum aplikasi mulai.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null; // lanjut tanpa preferensi
    }

    try {
      _db = await _openDatabase();
    } catch (_) {
      _db = null; // lanjut tanpa SQLite
    }

    _initialised = true;
  }

  /// Membuka (atau membuat) basis data SQLite.
  Future<Database> _openDatabase() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'air_quality.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS search_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            city TEXT NOT NULL,
            aqi INTEGER NOT NULL,
            category TEXT NOT NULL,
            searched_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ---------------------------------------------------------------------
  // 1. Kota terakhir — SharedPreferences
  // ---------------------------------------------------------------------

  /// Membaca kota terakhir yang dicari.
  String? getLastCity() {
    try {
      return _prefs?.getString(_lastCityKey);
    } catch (_) {
      return null;
    }
  }

  /// Menyimpan kota terakhir yang dicari.
  Future<void> saveLastCity(String city) async {
    try {
      await _prefs?.setString(_lastCityKey, city);
    } catch (_) {
      // abaikan — penyimpanan bukan hal kritis
    }
  }

  // ---------------------------------------------------------------------
  // 2. Riwayat pencarian — SQLite
  // ---------------------------------------------------------------------

  /// Menyimpan satu pencarian ke riwayat.
  Future<void> addHistory({
    required String city,
    required int aqi,
    required String category,
  }) async {
    final db = _db;
    if (db == null) return;

    try {
      // Riwayat dibatasi 20 entri terakhir agar tidak membengkak.
      await db.delete(
        'search_history',
        where: 'id NOT IN (SELECT id FROM search_history ORDER BY id DESC LIMIT 19)',
      );
      await db.insert('search_history', {
        'city': city,
        'aqi': aqi,
        'category': category,
        'searched_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // abaikan — riwayat gagal disimpan tidak mengganggu pencarian
    }
  }

  /// Membaca riwayat pencarian, terbaru lebih dulu.
  Future<List<SearchHistory>> getHistory({int limit = 20}) async {
    final db = _db;
    if (db == null) return const [];

    try {
      final rows = await db.query(
        'search_history',
        orderBy: 'id DESC',
        limit: limit,
      );
      return rows.map(SearchHistory.fromRow).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Menghapus seluruh riwayat.
  Future<void> clearHistory() async {
    final db = _db;
    if (db == null) return;
    try {
      await db.delete('search_history');
    } catch (_) {
      // abaikan
    }
  }
}
