import 'dart:io';

// Program Kasir Sederhana & Perhitungan Diskon Belanjaan Interaktif
// Dibuat untuk Mini Practice Tugas 2 Pemrograman Mobile

// 1. Function untuk menampilkan daftar harga barang (katalog)
void tampilkanKatalog(Map<String, double> daftarHarga) {
  print('==================================================');
  print('               DAFTAR HARGA BARANG                ');
  print('==================================================');
  int no = 1;
  daftarHarga.forEach((nama, harga) {
    print('$no. $nama : Rp ${harga.toStringAsFixed(0)}');
    no++;
  });
  print('==================================================');
}

// 2. Function untuk menghitung subtotal belanjaan
double hitungSubtotal(Map<String, int> belanjaan, Map<String, double> daftarHarga) {
  double total = 0.0;
  
  belanjaan.forEach((barang, jumlah) {
    if (daftarHarga.containsKey(barang)) {
      total += (daftarHarga[barang]! * jumlah);
    }
  });
  
  return total;
}

// 3. Function untuk menentukan persentase diskon menggunakan if / else if / else dan operator perbandingan
double hitungPersentaseDiskon(double totalBelanja) {
  double diskon = 0.0;

  // Menggunakan operator perbandingan (>=) dan percabangan if / else if / else
  if (totalBelanja >= 200000) {
    diskon = 0.20; // Diskon 20% jika belanja >= Rp 200.000
  } else if (totalBelanja >= 100000) {
    diskon = 0.10; // Diskon 10% jika belanja >= Rp 100.000
  } else if (totalBelanja >= 50000) {
    diskon = 0.05; // Diskon 5% jika belanja >= Rp 50.000
  } else {
    diskon = 0.0;  // Tidak ada diskon jika belanja < Rp 50.000
  }

  return diskon;
}

// 4. Function untuk menampilkan struk dan total akhir belanjaan
void cetakStruk(
  Map<String, int> belanjaan,
  Map<String, double> daftarHarga,
  double subtotal,
  double persentaseDiskon,
  double nominalDiskon,
  double totalAkhir,
) {
  print('\n==================================================');
  print('              STRUK PEMBELIAN TOKO                ');
  print('==================================================');
  print('Daftar Belanja:');
  
  belanjaan.forEach((barang, jumlah) {
    double hargaSatuan = daftarHarga[barang] ?? 0.0;
    double totalItem = hargaSatuan * jumlah;
    print('- $barang x $jumlah @ Rp ${hargaSatuan.toStringAsFixed(0)} = Rp ${totalItem.toStringAsFixed(0)}');
  });

  print('--------------------------------------------------');
  print('Subtotal Belanja        : Rp ${subtotal.toStringAsFixed(0)}');
  print('Diskon (${(persentaseDiskon * 100).toInt()}%)            : -Rp ${nominalDiskon.toStringAsFixed(0)}');
  print('--------------------------------------------------');
  print('TOTAL AKHIR             : Rp ${totalAkhir.toStringAsFixed(0)}');
  print('==================================================');
  print('          Terima Kasih Telah Berbelanja!          ');
  print('==================================================');
}

void main() {
  // 01. Menyimpan daftar harga (Built-in Type: Map<String, double>)
  Map<String, double> daftarHarga = {
    'Beras 5kg': 75000.0,
    'Minyak Goreng 2L': 34000.0,
    'Gula Pasir 1kg': 17500.0,
    'Telur 1 Rak': 55000.0,
    'Susu UHT 1L': 19000.0,
    'Kopi Bubuk': 12000.0,
  };

  // 02. Menyimpan daftar belanjaan (Built-in Type: Map<String, int>)
  Map<String, int> daftarBelanjaan = {};

  // Menampilkan katalog barang
  tampilkanKatalog(daftarHarga);

  List<String> listBarang = daftarHarga.keys.toList();

  // Input interaktif dari pengguna
  while (true) {
    stdout.write('\nPilih nomor barang (1-${listBarang.length}) atau ketik 0 untuk selesai: ');
    String? inputPilihan = stdin.readLineSync();
    int? nomorPilihan = int.tryParse(inputPilihan ?? '');

    if (nomorPilihan == null) {
      print('Input tidak valid! Masukkan angka.');
      continue;
    }

    if (nomorPilihan == 0) {
      break;
    }

    if (nomorPilihan < 1 || nomorPilihan > listBarang.length) {
      print('Nomor barang tidak ditemukan! Silakan pilih antara 1-${listBarang.length}.');
      continue;
    }

    String barangDipilih = listBarang[nomorPilihan - 1];

    stdout.write('Masukkan jumlah untuk "$barangDipilih": ');
    String? inputJumlah = stdin.readLineSync();
    int? jumlah = int.tryParse(inputJumlah ?? '');

    if (jumlah == null || jumlah <= 0) {
      print('Jumlah harus berupa bilangan bulat positif!');
      continue;
    }

    // Tambahkan atau update jumlah ke daftar belanjaan
    daftarBelanjaan[barangDipilih] = (daftarBelanjaan[barangDipilih] ?? 0) + jumlah;
    print('>> Berhasil menambahkan $barangDipilih ($jumlah pcs) ke keranjang.');
  }

  // Cek jika pengguna tidak belanja apapun
  if (daftarBelanjaan.isEmpty) {
    print('\nAnda belum memilih barang belanjaan. Program selesai.');
    return;
  }

  // 03. Menghitung subtotal belanjaan
  double subtotal = hitungSubtotal(daftarBelanjaan, daftarHarga);

  // 04. Menentukan case diskon belanjaan (Function & if / else if / else)
  double persentaseDiskon = hitungPersentaseDiskon(subtotal);
  double nominalDiskon = subtotal * persentaseDiskon;

  // 05. Menghitung total akhir
  double totalAkhir = subtotal - nominalDiskon;

  // 06. Menampilkan struk dan total akhir belanjaan
  cetakStruk(
    daftarBelanjaan,
    daftarHarga,
    subtotal,
    persentaseDiskon,
    nominalDiskon,
    totalAkhir,
  );
}
