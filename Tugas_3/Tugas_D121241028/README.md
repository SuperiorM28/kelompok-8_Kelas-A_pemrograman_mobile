# Air Quality App — Aplikasi Pengecek Kualitas Udara
Mata Kuliah: Pemrograman Mobile

Aplikasi Flutter yang menarik data Indeks Kualitas Udara (AQI) dari REST API publik,
menangani tiga keadaan antarmuka (Loading / Success / Error), dan menyimpan
riwayat pencarian secara lokal.

**Tidak perlu kunci API.** Aplikasi memakai Open-Meteo yang terbuka untuk umum,
sehingga langsung bisa dijalankan dan langsung menampilkan data asli.

---

## Kriteria yang Dipenuhi

| No | Kriteria | Cara pemenuhan |
|----|----------|----------------|
| 1 | REST API — ambil data AQI dari public API | `lib/services/aqi_service.dart` — tiga panggilan HTTP: geocoding kota, kualitas udara, dan cuaca. Data diambil dari **Open-Meteo** (tanpa token) dengan **WAQI.info** sebagai cadangan bila token diisi |
| 2 | Asynchronous UI — `FutureBuilder` untuk state Loading, Success, Error | `lib/screens/home_screen.dart` — satu `FutureBuilder<AqiResponse>` dengan tiga cabang `ConnectionState` |
| 3 | Local Storage — simpan "kota terakhir yang dicari" atau riwayat pencarian | `lib/services/storage_service.dart` — **dua-duanya**: kota terakhir di `SharedPreferences`, riwayat pencarian di `sqflite` (SQLite) |

---

## Menjalankan Aplikasi

### 1. Persiapan

```bash
cd Tugas_Pemrograman_Mobile
flutter pub get
```

### 2. Jalankan

```bash
flutter run
```

Atau di VS Code: buka folder `Tugas_Pemrograman_Mobile`, tekan **F5**.

Aplikasi langsung menampilkan data asli — tidak ada langkah konfigurasi.

### Opsional: pakai WAQI.info sebagai sumber

Bila ingin memakai WAQI.info, daftar gratis di <https://aqicn.org/api/> lalu
isi di `lib/services/aqi_service.dart`:

```dart
const AqiService({this.token = ''});   // isi '' dengan token Anda
```

Bila dibiarkan kosong, WAQI dilewati dan Open-Meteo dipakai.

---

## Struktur Berkas

```
lib/
├── main.dart                     titik masuk, tema, inisialisasi storage
├── models/
│   └── aqi_response.dart         model data AQI + parsing JSON
├── services/
│   ├── aqi_service.dart          REST API: Open-Meteo + WAQI
│   └── storage_service.dart      SharedPreferences + SQLite
└── screens/
    └── home_screen.dart          UI utama, FutureBuilder (3 state)
pubspec.yaml                      dependensi: http, shared_preferences, sqflite
```

---

## Alur Aplikasi

1. Pengguna mengetik nama kota lalu menekan tombol **Cari**.
2. Riwayat diambil dari SQLite dan ditampilkan sebagai saran.
3. `FutureBuilder` memasuki `ConnectionState.waiting` → kotak **Loading** tampil.
4. Nama kota diubah menjadi koordinat lewat geocoding.
5. Kualitas udara dan cuaca diambil **sekaligus** (dua panggilan paralel).
6. Respon tiba → **Success**: kartu AQI, kategori, suhu, kelembaban, polutan.
7. Respons gagal (jaringan putus, kota tidak ada) → **Error**: pesan + tombol **Coba Lagi**.
8. Setiap pencarian yang berhasil tersimpan di SQLite; kota terakhir disimpan di
   SharedPreferences dan otomatis dimuat saat aplikasi dibuka.

---

## Sumber Data

| Sumber | Butuh token | Status |
|--------|-------------|--------|
| [Open-Meteo](https://open-meteo.com/) — geocoding + air quality + forecast | Tidak | **Dipakai** |
| [WAQI.info](https://aqicn.org/api/) | Ya (gratis) | Cadangan |

---

## Pengujian

```bash
flutter analyze                 # memastikan tidak ada masalah
flutter test                    # pengujian widget & parsing (tanpa jaringan)
flutter test test/live_test.dart  # pengujian data asli (perlu internet)
```

---

## Catatan

- `http`, `shared_preferences`, dan `sqflite` memerlukan izin internet pada
  aplikasi Android — sudah diatur di `android/app/src/main/AndroidManifest.xml`.
- Semua kesalahan jaringan dibungkus try/catch sehingga tidak ada Crash.
- Bila kota tidak ditemukan, aplikasi menampilkan pesan galat — bukan data palsu.
