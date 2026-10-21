// Layar utama Aplikasi Pengecek Kualitas Udara.
//
// Memenuhi kriteria 2 tugas: seluruh keadaan asinkron ditangani satu
// FutureBuilder yang mencakup tiga cabang —
// * ConnectionState.waiting  → Loading
// * snapshot.hasData         → Success
// * snapshot.hasError        → Error
//
// Kriteria 3: kota terakhir diambil dari SharedPreferences saat dibuat,
// dan riwayat ditarik dari SQLite lalu ditampilkan sebagai saran pencarian.

library;

import 'package:flutter/material.dart';

import '../models/aqi_response.dart';
import '../services/aqi_service.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  /// Layanan yang dipakai.
  ///
  /// Diisi dari luar hanya untuk pengujian; bila null, layanan bawaan
  /// dipakai sehingga aplikasi normal tidak terpengaruh.
  final AqiService? serviceOverride;

  const HomeScreen({super.key, this.serviceOverride});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Klien API.
  late final AqiService _service = widget.serviceOverride ?? const AqiService();

  final TextEditingController _controller = TextEditingController();
  final StorageService _storage = StorageService.instance;

  /// Future yang sedang diikuti `FutureBuilder`.
  ///
  /// Bila null, berarti belum ada pencarian — tampilkan sambutan.
  Future<AqiResponse>? _future;

  List<SearchHistory> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadLastCity();
    _loadHistory();
  }

  /// Kriteria 3a — kota terakhir dari SharedPreferences.
  void _loadLastCity() {
    final last = _storage.getLastCity();
    if (last != null && last.isNotEmpty) {
      _controller.text = last;
    }
  }

  /// Kriteria 3b — riwayat dari SQLite.
  Future<void> _loadHistory() async {
    final rows = await _storage.getHistory();
    if (!mounted) return;
    setState(() => _history = rows);
  }

  /// Memulai pencarian baru.
  ///
  /// `setState` mengganti `_future` sehingga `FutureBuilder` membangun ulang
  /// dan melewati ketiga keadaannya.
  void _search() {
    FocusScope.of(context).unfocus();
    final city = _controller.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nama kota terlebih dahulu.')),
      );
      return;
    }

    setState(() => _future = _service.fetchByCity(city));
  }

  /// Menyimpan hasil ke penyimpanan lokal setelah sukses.
  ///
  /// Dipanggil lewat `addPostFrameCallback`, bukan langsung dari `build`,
  /// supaya tidak ada Future yang dikembalikan dari callback setState.
  Future<void> _persist(AqiResponse result) async {
    await _storage.saveLastCity(result.city);
    await _storage.addHistory(
      city: result.city,
      aqi: result.aqi,
      category: result.category,
    );
    await _refreshHistory();
  }

  /// Memuat ulang riwayat dari SQLite.
  Future<void> _refreshHistory() async {
    final rows = await _storage.getHistory();
    if (!mounted) return;
    setState(() => _history = rows);
  }

  /// Mengulang pencarian terakhir dari layar Error.
  void _retry() {
    final city = _controller.text.trim();
    if (city.isEmpty) return;
    setState(() => _future = _service.fetchByCity(city));
  }

  /// Memilih kota dari saran riwayat.
  void _pickFromHistory(String city) {
    _controller.text = city;
    _search();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Kualitas Udara'),
        backgroundColor: const Color(0xFF0B2265),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _searchBox(),
              const SizedBox(height: 16),
              if (_history.isNotEmpty) ...[
                _historySection(),
                const SizedBox(height: 16),
              ],
              _resultArea(),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Kotak pencarian
  // -----------------------------------------------------------------

  Widget _searchBox() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cari kualitas udara kota',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Contoh: Jakarta, Bandung, Surabaya',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Nama kota',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Cari'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B2265),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Riwayat pencarian
  // -----------------------------------------------------------------

  Widget _historySection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Riwayat pencarian',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await _storage.clearHistory();
                    await _loadHistory();
                  },
                  child: const Text('Hapus', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _history.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = _history[index];
                  return ActionChip(
                    label: Text('${item.city} · ${item.aqi}'),
                    avatar: const Icon(Icons.location_city, size: 16),
                    onPressed: () => _pickFromHistory(item.city),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Area hasil — FutureBuilder dengan 3 state
  // -----------------------------------------------------------------

  Widget _resultArea() {
    // Belum ada pencarian.
    if (_future == null) {
      return _welcome();
    }

    return FutureBuilder<AqiResponse>(
      future: _future,
      builder: (context, snapshot) {
        // ---- STATE 1: LOADING -------------------------------------
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard();
        }

        // ---- STATE 3: ERROR ---------------------------------------
        if (snapshot.hasError) {
          return _errorCard(snapshot.error.toString());
        }

        // ---- STATE 2: SUCCESS -------------------------------------
        if (snapshot.hasData) {
          final result = snapshot.data!;
          // Simpan ke lokal setelah frame selesai. Tidak dilakukan di dalam
          // build langsung: mengembalikan Future dari sini membuat setState
          // ikut mengembalikan Future dan memicu galat Flutter.
          WidgetsBinding.instance.addPostFrameCallback((_) => _persist(result));
          return _successCard(result);
        }

        return _welcome();
      },
    );
  }

  Widget _welcome() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Icon(Icons.air, size: 56, color: Color(0xFF0B2265)),
            SizedBox(height: 12),
            Text(
              'Masukkan nama kota untuk melihat kualitas udaranya.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            CircularProgressIndicator(color: Color(0xFF0B2265)),
            SizedBox(height: 16),
            Text('Mengambil data dari server…'),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String raw) {
    // Ambil pesan ramah dari objek AqiError bila tersedia.
    final message = raw.replaceFirst(RegExp(r'^AqiError:\s*'), '');
    return Card(
      elevation: 1,
      color: const Color(0xFFFFF1F1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Gagal mengambil data',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _successCard(AqiResponse r) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kota + waktu
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF0B2265)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.city,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Diukur ${r.time}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // AQI utama
            Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _aqiColor(r.aqi),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${r.aqi}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'AQI',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _aqiColor(r.aqi).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  r.category,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _aqiColor(r.aqi),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Cuaca
            _weatherRow(r),
            const SizedBox(height: 20),

            // Polutan
            const Text(
              'Konsentrasi Polutan (µg/m³)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _pollutantTable(r),
          ],
        ),
      ),
    );
  }

  Widget _weatherRow(AqiResponse r) {
    Widget tile(String label, String value, IconData icon) {
      return Expanded(
        child: Column(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0B2265)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          tile('Suhu', _fmt(r.temperature, '°C'), Icons.thermostat),
          tile('Kelembaban', _fmt(r.humidity, '%'), Icons.water_drop),
          tile('Tekanan', _fmt(r.pressure, 'hPa'), Icons.speed),
          tile('Angin', _fmt(r.windSpeed, 'm/s'), Icons.air),
        ],
      ),
    );
  }

  String _fmt(double? value, String unit) {
    if (value == null) return '-';
    final rounded = value.round();
    return '$rounded$unit';
  }

  Widget _pollutantTable(AqiResponse r) {
    if (r.pollutants.isEmpty) {
      return const Text('Data polutan tidak tersedia.');
    }
    final rows = r.pollutants.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: rows.take(8).map((e) {
        final isMain = e.key == r.dominantPollutant;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  e.key.toUpperCase(),
                  style: TextStyle(
                    fontWeight: isMain ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (e.value / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 50,
                child: Text(
                  e.value.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (isMain) ...[
                const SizedBox(width: 4),
                const Icon(Icons.star, size: 14, color: Colors.orange),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _aqiColor(int aqi) {
    if (aqi <= 50) return const Color(0xFF2E7D32);
    if (aqi <= 100) return const Color(0xFFF9A825);
    if (aqi <= 150) return const Color(0xFFEF6C00);
    if (aqi <= 200) return const Color(0xFFC62828);
    if (aqi <= 300) return const Color(0xFF6A1B9A);
    return const Color(0xFF7B1FA2);
  }
}
