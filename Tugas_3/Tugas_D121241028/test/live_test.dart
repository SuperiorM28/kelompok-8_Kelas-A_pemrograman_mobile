// Uji nyata: layanan mengambil data asli dari Open-Meteo tanpa token.
//
// Pengujian ini perlu koneksi internet. Jalankan dengan:
//   flutter test test/live_test.dart
//
// Bukan bagian dari pengujian otomatis di test/aqi_app_test.dart karena
// bergantung jaringan, tetapi berguna untuk membuktikan data yang tampil
// benar-benar datang dari server.

import 'package:flutter_test/flutter_test.dart';

import 'package:air_quality_app/services/aqi_service.dart';

void main() {
  const service = AqiService();

  test('Jakarta — data asli dari Open-Meteo', () async {
    final result = await service.fetchByCity('Jakarta');

    // ignore: avoid_print
    print('kota    : ${result.city}');
    // ignore: avoid_print
    print('aqi     : ${result.aqi}');
    // ignore: avoid_print
    print('kategori: ${result.category}');
    // ignore: avoid_print
    print('suhu    : ${result.temperature}');
    // ignore: avoid_print
    print('lembab  : ${result.humidity}');
    // ignore: avoid_print
    print('polutan : ${result.pollutants}');

    expect(result.status, 'ok');
    expect(result.aqi, greaterThan(0));
    expect(result.city.toLowerCase(), contains('jakarta'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('Bandung — kota Indonesia lain', () async {
    final result = await service.fetchByCity('Bandung');
    expect(result.status, 'ok');
    expect(result.aqi, greaterThan(0));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('kota tidak dikenal — memicu galat, bukan data contoh', () async {
    await expectLater(
      service.fetchByCity('KotaTidakAdaXYZ123'),
      throwsA(isA<AqiError>()),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('kota kosong — ditolak sebelum menyentuh jaringan', () async {
    await expectLater(
      service.fetchByCity('   '),
      throwsA(isA<AqiError>()),
    );
  });
}
