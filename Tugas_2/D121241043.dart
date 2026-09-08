import 'dart:io';

// ====================================================================
// Tugas 2 - Pemrograman Mobile (Kelas A)
// Nama  : Imtyas Qanita Rahman
// NIM   : D121241043
// ====================================================================

// Function 1: Menampilkan daftar harga produk yang tersedia di toko
void tampilkanMenu(Map<String, int> katalogHarga) {
  print('\n' + '=' * 45);
  print('           TOKO BUKU & ATK SMART           ');
  print('=' * 45);
  print('Kode | Nama Barang            | Harga');
  print('-' * 45);

  int kode = 1;
  katalogHarga.forEach((nama, harga) {
    String kodeStr = kode.toString().padRight(4);
    String namaStr = nama.padRight(22);
    String hargaStr = 'Rp $harga'.padLeft(10);
    print('$kodeStr | $namaStr | $hargaStr');
    kode++;
  });
  print('=' * 45);
}

// Function 2: Menghitung subtotal belanjaan
int hitungSubtotal(Map<String, int> keranjang, Map<String, int> katalogHarga) {
  int subtotal = 0;
  keranjang.forEach((item, jumlah) {
    int hargaSatuan = katalogHarga[item] ?? 0;
    subtotal += hargaSatuan * jumlah;
  });
  return subtotal;
}

// Function 3: Menentukan persentase diskon belanjaan berdasarkan subtotal
// Menggunakan:
// - If / else if / else
// - Operator comparison (>=, <, >)
double tentukanDiskon(int subtotal) {
  double persentaseDiskon = 0.0;

  if (subtotal >= 250000) {
    persentaseDiskon = 0.20; // Diskon 20% jika belanja >= Rp 250.000
  } else if (subtotal >= 150000) {
    persentaseDiskon = 0.15; // Diskon 15% jika belanja >= Rp 150.000
  } else if (subtotal >= 75000) {
    persentaseDiskon = 0.05; // Diskon 5% jika belanja >= Rp 75.000
  } else {
    persentaseDiskon = 0.0;  // Tidak ada diskon jika belanja < Rp 75.000
  }

  return persentaseDiskon;
}

// Function 4: Menampilkan rincian struk dan total akhir belanjaan
void cetakRincianBelanja({
  required Map<String, int> keranjang,
  required Map<String, int> katalogHarga,
  required int subtotal,
  required double persentaseDiskon,
  required double potonganHarga,
  required double totalAkhir,
}) {
  print('\n' + '=' * 45);
  print('              STRUK PEMBELIAN              ');
  print('=' * 45);
  print('Item                    Qty   Harga      Total');
  print('-' * 45);

  keranjang.forEach((item, qty) {
    int harga = katalogHarga[item] ?? 0;
    int totalPerItem = harga * qty;
    print(
      '${item.padRight(22)} '
      '${qty.toString().padRight(4)} '
      '${harga.toString().padRight(9)} '
      'Rp $totalPerItem',
    );
  });

  print('-' * 45);
  print('Subtotal Belanja        : Rp $subtotal');
  
  int diskonPersen = (persentaseDiskon * 100).toInt();
  print('Diskon Belanja ($diskonPersen%)      : -Rp ${potonganHarga.toInt()}');
  print('=' * 45);
  print('TOTAL AKHIR             : Rp ${totalAkhir.toInt()}');
  print('=' * 45);
  print('      Terima kasih telah berbelanja!      \n');
}

void main() {
  // [01] Menyimpan daftar harga
  // Tipe data: Map<String, int> (Built-in Types)
  final Map<String, int> daftarHarga = {
    'Buku Tulis Hardcover': 22000,
    'Binder B5 Aesthetic': 45000,
    'Paket Pulpen Gel 12pcs': 30000,
    'Highlighter Set Pastel': 28000,
    'Tempat Pensil Kanvas': 35000,
    'Sticky Notes Set': 15000,
    'Correction Tape': 12000,
  };

  // [02] Menyimpan daftar belanjaan (keranjang belanja)
  // Tipe data: Map<String, int> (Built-in Types)
  final Map<String, int> daftarBelanjaan = {};

  // Menampilkan katalog harga
  tampilkanMenu(daftarHarga);

  final List<String> listProduk = daftarHarga.keys.toList();

  print('Pilih produk dengan mengetik nomor (1-${listProduk.length}).');
  print('Ketik 0 jika sudah selesai berbelanja.\n');

  // Loop input belanjaan dari user
  while (true) {
    stdout.write('Masukkan nomor pilihan produk (0 untuk selesai): ');
    String? inputNo = stdin.readLineSync();
    int? noPilihan = int.tryParse(inputNo?.trim() ?? '');

    if (noPilihan == null) {
      print('>> Peringatan: Masukkan nomor angka yang valid!\n');
      continue;
    }

    // Menggunakan comparison operator (==)
    if (noPilihan == 0) {
      break;
    }

    // Menggunakan comparison operator (< dan >)
    if (noPilihan < 1 || noPilihan > listProduk.length) {
      print('>> Nomor produk tidak ada di daftar! Silakan coba lagi.\n');
      continue;
    }

    String produkDipilih = listProduk[noPilihan - 1];

    stdout.write('Jumlah $produkDipilih yang ingin dibeli: ');
    String? inputQty = stdin.readLineSync();
    int? kuantitas = int.tryParse(inputQty?.trim() ?? '');

    // Menggunakan comparison operator (<=)
    if (kuantitas == null || kuantitas <= 0) {
      print('>> Peringatan: Jumlah barang harus berupa angka positif!\n');
      continue;
    }

    // Masukkan ke dalam map daftar belanjaan
    daftarBelanjaan[produkDipilih] =
        (daftarBelanjaan[produkDipilih] ?? 0) + kuantitas;

    print('>> Berhasil menambahkan $kuantitas x $produkDipilih ke keranjang.\n');
  }

  // Jika tidak ada barang yang dibeli
  if (daftarBelanjaan.isEmpty) {
    print('\nTidak ada produk dalam keranjang belanja. Transaksi dibatalkan.');
    return;
  }

  // Menghitung subtotal
  int subtotal = hitungSubtotal(daftarBelanjaan, daftarHarga);

  // [03] Menentukan case diskon belanjaan (menggunakan function & if/else)
  double persentaseDiskon = tentukanDiskon(subtotal);
  double nominalDiskon = subtotal * persentaseDiskon;

  // [04] Menghitung dan menampilkan total akhir belanjaan
  double totalAkhir = subtotal - nominalDiskon;

  cetakRincianBelanja(
    keranjang: daftarBelanjaan,
    katalogHarga: daftarHarga,
    subtotal: subtotal,
    persentaseDiskon: persentaseDiskon,
    potonganHarga: nominalDiskon,
    totalAkhir: totalAkhir,
  );
}
