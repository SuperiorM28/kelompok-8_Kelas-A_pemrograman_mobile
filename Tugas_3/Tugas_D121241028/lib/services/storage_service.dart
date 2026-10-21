// Lapisan penyimpanan lokal.
//
// Memenuhi kriteria 3 tugas dengan menyediakan DUA mekanisme:
//   1. SharedPreferences — menyimpan "kota terakhir yang dicari".
//   2. SQLite (sqflite)  — menyimpan riwayat pencarian.
//
// Catatan penting tentang platform:
//   * Di Android/iOS/desktop, riwayat disimpan di SQLite.
//   * Di web, `sqflite` tidak tersedia. Riwayat disimpan sebagai satu
//     berkas JSON di SharedPreferences, sehingga tetap tersimpan dan
//     aplikasi tidak error.
//
// Semua operasi dibungkus try/catch: kegagalan penyimpanan tidak pernah
// membuat aplikasi Crash, dan pencarian tetap bisa berjalan.

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// Dari berkas JSON (jalur web).
  factory SearchHistory.fromJson(Map<String, dynamic> json) {
    return SearchHistory(
      id: json['id'] as int?,
      city: (json['city'] as String?) ?? '-',
      aqi: (json['aqi'] as int?) ?? 0,
      category: (json['category'] as String?) ?? '-',
      searchedAt: (json['searched_at'] as String?) ?? '-',
    );
  }

  /// Menuju baris tabel SQLite.
  Map<String, Object?> toRow() => {
        'city': city,
        'aqi': aqi,
        'category': category,
        'searched_at': searchedAt,
      };

  /// Menuju berkas JSON (jalur web).
  Map<String, dynamic> toJson() => {
        'id': id,
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
  static const String _historyKey = 'search_history';

  Database? _db;
  SharedPreferences? _prefs;

  bool _initialised = false;

  /// Menandakan inisialisasi sudah pernah dicoba.
  bool get isInitialised => _initialised;

  /// Benar bila aplikasi berjalan di browser.
  ///
  /// Di web `sqflite` tidak tersedia, sehingga riwayat disimpan sebagai
  /// berkas JSON di SharedPreferences.
  bool get _isWeb => kIsWeb;

  /// Menyiapkan SharedPreferences dan basis data.
  ///
  /// Dipanggil sekali dari `main()` sebelum aplikasi mulai.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null; // lanjut tanpa preferensi
    }

    if (!_isWeb) {
      try {
        _db = await _openDatabase();
      } catch (_) {
        _db = null; // lanjut tanpa SQLite
      }
    }

    _initialised = true;
  }

  /// Membuka (atau membuat) basis data SQLite.
  ///
  /// Hanya dipanggil di luar web.
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
  // 2. Riwayat pencarian — SQLite di native, JSON di web
  // ---------------------------------------------------------------------

  /// Menyimpan satu pencarian ke riwayat.
  Future<void> addHistory({
    required String city,
    required int aqi,
    required String category,
  }) async {
    if (_isWeb) {
      await _addHistoryWeb(city, aqi, category);
      return;
    }

    final db = _db;
    if (db == null) return;

    try {
      // Riwayat dibatasi 20 entri terakhir agar tidak membengkak.
      await db.delete(
        'search_history',
        where:
            'id NOT IN (SELECT id FROM search_history ORDER BY id DESC LIMIT 19)',
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

  /// Menyimpan riwayat di web sebagai berkas JSON.
  Future<void> _addHistoryWeb(String city, int aqi, String category) async {
    final rows = await getHistory();
    final now = DateTime.now().toIso8601String();

    // Gabungkan dengan entri lama, terbaru lebih dulu, maksimum 20.
    final merged = <SearchHistory>[
      SearchHistory(
        id: 1,
        city: city,
        aqi: aqi,
        category: category,
        searchedAt: now,
      ),
      ...rows,
    ].take(20).toList();

    // Beri ulang nomor urut.
    final numbered = <SearchHistory>[
      for (var i = 0; i < merged.length; i++)
        SearchHistory(
          id: i + 1,
          city: merged[i].city,
          aqi: merged[i].aqi,
          category: merged[i].category,
          searchedAt: merged[i].searchedAt,
        ),
    ];

    try {
      await _prefs?.setString(_historyKey, jsonEncode(numbered));
    } catch (_) {
      // abaikan
    }
  }

  /// Membaca riwayat pencarian, terbaru lebih dulu.
  Future<List<SearchHistory>> getHistory({int limit = 20}) async {
    if (_isWeb) return _getHistoryWeb(limit);

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

  /// Membaca riwayat dari berkas JSON di web.
  Future<List<SearchHistory>> _getHistoryWeb(int limit) async {
    try {
      final raw = _prefs?.getString(_historyKey);
      if (raw == null || raw.isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(SearchHistory.fromJson)
          .toList();

      if (items.length <= limit) return items;
      return items.sublist(0, limit);
    } catch (_) {
      return const [];
    }
  }

  /// Menghapus seluruh riwayat.
  Future<void> clearHistory() async {
    if (_isWeb) {
      try {
        await _prefs?.remove(_historyKey);
      } catch (_) {
        // abaikan
      }
      return;
    }

    final db = _db;
    if (db == null) return;
    try {
      await db.delete('search_history');
    } catch (_) {
      // abaikan
    }
  }
}
