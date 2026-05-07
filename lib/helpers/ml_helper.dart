// lib/helpers/ml_helper.dart
// Machine Learning Helper - Prediksi Durasi Perjalanan
// Menggunakan Decision Tree sederhana (offline, tanpa API)

class MLHelper {
  // ── Kategori Destinasi ──────────────────────────────────────────
  static const Map<String, String> _destinasiKategori = {
    // Pantai / Kepulauan
    'bali': 'pantai',
    'lombok': 'pantai',
    'labuan bajo': 'pantai',
    'raja ampat': 'pantai',
    'manado': 'pantai',
    'belitung': 'pantai',
    'bunaken': 'pantai',
    'wakatobi': 'pantai',
    'banda neira': 'pantai',
    'pulau komodo': 'pantai',
    'gili': 'pantai',
    'derawan': 'pantai',
    'karimunjawa': 'pantai',
    'sabang': 'pantai',
    'bintan': 'pantai',
    'batam': 'pantai',

    // Kota Besar
    'jakarta': 'kota',
    'surabaya': 'kota',
    'medan': 'kota',
    'bandung': 'kota',
    'makassar': 'kota',
    'semarang': 'kota',
    'palembang': 'kota',
    'tangerang': 'kota',
    'depok': 'kota',
    'bekasi': 'kota',

    // Budaya / Sejarah
    'yogyakarta': 'budaya',
    'jogja': 'budaya',
    'solo': 'budaya',
    'surakarta': 'budaya',
    'borobudur': 'budaya',
    'prambanan': 'budaya',
    'candi': 'budaya',
    'toraja': 'budaya',

    // Alam / Pegunungan
    'bromo': 'alam',
    'rinjani': 'alam',
    'semeru': 'alam',
    'dieng': 'alam',
    'flores': 'alam',
    'danau toba': 'alam',
    'bukittinggi': 'alam',
    'padang': 'alam',
    'malang': 'alam',
    'batu': 'alam',
    'wonosobo': 'alam',
    'pangalengan': 'alam',
    'lembang': 'alam',
  };

  // ── Jarak Kota (estimasi jam perjalanan dari kota-kota besar) ───
  static const Map<String, Map<String, double>> _jarakJam = {
    'jakarta': {
      'bali': 2.0,
      'yogyakarta': 1.0,
      'jogja': 1.0,
      'surabaya': 1.5,
      'medan': 2.5,
      'makassar': 2.5,
      'lombok': 2.5,
      'labuan bajo': 3.0,
      'raja ampat': 5.0,
    },
    'surabaya': {
      'bali': 0.5,
      'yogyakarta': 1.0,
      'jogja': 1.0,
      'jakarta': 1.5,
      'lombok': 1.0,
      'bromo': 2.0,
      'malang': 1.0,
    },
    'yogyakarta': {
      'jakarta': 1.0,
      'surabaya': 1.0,
      'bali': 1.5,
      'bromo': 3.0,
      'semarang': 1.0,
    },
    'medan': {
      'jakarta': 2.5,
      'danau toba': 3.0,
      'bukittinggi': 4.0,
      'padang': 4.0,
    },
  };

  /// ── DECISION TREE: Prediksi Durasi Perjalanan ──────────────────
  ///
  /// Input:
  ///   - lokasiTujuan : nama kota/destinasi tujuan
  ///   - kotaAsal     : nama kota asal user (dari GPS)
  ///   - tanggalMulai : DateTime tanggal mulai
  ///   - tanggalSelesai: DateTime tanggal selesai
  ///
  /// Output: [DurasiPrediksi] berisi rekomendasi dan alasan
  static DurasiPrediksi prediksiDurasi({
    required String lokasiTujuan,
    required String kotaAsal,
    required DateTime tanggalMulai,
    required DateTime tanggalSelesai,
  }) {
    final durasiDipilih = tanggalSelesai.difference(tanggalMulai).inDays + 1;
    final kategori = _getKategori(lokasiTujuan);
    final jarakJam = _estimasiJarak(kotaAsal, lokasiTujuan);
    final isWeekend = _cekWeekend(tanggalMulai, tanggalSelesai);

    // ── Node 1: Kategori Destinasi ────────────────────────────────
    int durasiIdeal;
    String alasanKategori;

    switch (kategori) {
      case 'pantai':
        // Node 2: Jarak
        if (jarakJam > 3.0) {
          durasiIdeal = 5; // jauh → minimal 5 hari
          alasanKategori = 'Destinasi pantai yang jauh ideal minimal 5 hari';
        } else if (jarakJam > 1.5) {
          durasiIdeal = 4;
          alasanKategori = 'Destinasi pantai ideal 4 hari';
        } else {
          durasiIdeal = 3;
          alasanKategori = 'Destinasi pantai dekat ideal 3 hari';
        }
        break;

      case 'budaya':
        // Node 2: Weekend?
        if (isWeekend && durasiDipilih <= 3) {
          durasiIdeal = 3;
          alasanKategori = 'Destinasi budaya cocok untuk long weekend 3 hari';
        } else {
          durasiIdeal = 4;
          alasanKategori =
              'Destinasi budaya & sejarah ideal 4 hari agar bisa menjelajah';
        }
        break;

      case 'alam':
        // Node 2: Jarak
        if (jarakJam > 3.0) {
          durasiIdeal = 5;
          alasanKategori = 'Destinasi alam terpencil butuh minimal 5 hari';
        } else {
          durasiIdeal = 3;
          alasanKategori = 'Destinasi alam ideal 3 hari';
        }
        break;

      case 'kota':
        durasiIdeal = 2;
        alasanKategori = 'Wisata kota cukup 2 hari';
        break;

      default:
        // Node: Unknown → pakai jarak sebagai penentu
        if (jarakJam > 4.0) {
          durasiIdeal = 5;
          alasanKategori = 'Perjalanan jauh disarankan minimal 5 hari';
        } else if (jarakJam > 2.0) {
          durasiIdeal = 3;
          alasanKategori = 'Perjalanan sedang disarankan 3 hari';
        } else {
          durasiIdeal = 2;
          alasanKategori = 'Perjalanan dekat cukup 2 hari';
        }
    }

    // ── Node Akhir: Bandingkan dengan durasi yang dipilih user ─────
    final selisih = durasiDipilih - durasiIdeal;
    String status;
    String pesan;
    PrediksiStatus statusEnum;

    if (selisih == 0) {
      status = '✅ Sempurna!';
      pesan = '$alasanKategori. Durasi yang kamu pilih sudah ideal!';
      statusEnum = PrediksiStatus.sempurna;
    } else if (selisih > 0 && selisih <= 2) {
      status = '👍 Bagus!';
      pesan =
          '$alasanKategori. Kamu punya $selisih hari ekstra untuk bersantai!';
      statusEnum = PrediksiStatus.bagus;
    } else if (selisih > 2) {
      status = '⚠️ Terlalu Lama';
      pesan =
          '$alasanKategori. Durasi ${durasiDipilih} hari mungkin terlalu lama, ideal $durasiIdeal hari.';
      statusEnum = PrediksiStatus.terlalu_lama;
    } else if (selisih < 0 && selisih >= -1) {
      status = '⚠️ Agak Singkat';
      pesan =
          '$alasanKategori. Tambah ${selisih.abs()} hari lagi agar lebih maksimal.';
      statusEnum = PrediksiStatus.agak_singkat;
    } else {
      status = '❌ Terlalu Singkat';
      pesan =
          '$alasanKategori. Durasi ${durasiDipilih} hari kurang, disarankan $durasiIdeal hari.';
      statusEnum = PrediksiStatus.terlalu_singkat;
    }

    return DurasiPrediksi(
      durasiDipilih: durasiDipilih,
      durasiIdeal: durasiIdeal,
      kategoriDestinasi: kategori,
      status: status,
      pesan: pesan,
      statusEnum: statusEnum,
      jarakEstimasiJam: jarakJam,
    );
  }

  // ── Helper: Ambil kategori destinasi ───────────────────────────
  static String _getKategori(String lokasi) {
    final lokasiLower = lokasi.toLowerCase();
    for (final entry in _destinasiKategori.entries) {
      if (lokasiLower.contains(entry.key)) {
        return entry.value;
      }
    }
    return 'unknown';
  }

  // ── Helper: Estimasi jarak (jam) ───────────────────────────────
  static double _estimasiJarak(String asal, String tujuan) {
    final asalLower = asal.toLowerCase();
    final tujuanLower = tujuan.toLowerCase();

    for (final kotaAsal in _jarakJam.entries) {
      if (asalLower.contains(kotaAsal.key)) {
        for (final kotaTujuan in kotaAsal.value.entries) {
          if (tujuanLower.contains(kotaTujuan.key)) {
            return kotaTujuan.value;
          }
        }
      }
    }
    // Default: estimasi berdasarkan panjang nama (fallback sederhana)
    return 2.5;
  }

  // ── Helper: Cek apakah perjalanan di akhir pekan ───────────────
  static bool _cekWeekend(DateTime mulai, DateTime selesai) {
    return mulai.weekday == DateTime.friday ||
        mulai.weekday == DateTime.saturday ||
        selesai.weekday == DateTime.saturday ||
        selesai.weekday == DateTime.sunday;
  }

  // ── Helper: Parse tanggal dari string format app ───────────────
  static DateTime? parseTanggal(String dateStr) {
    const bulan = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'Mei': 5,
      'Jun': 6,
      'Jul': 7,
      'Ags': 8,
      'Sep': 9,
      'Okt': 10,
      'Nov': 11,
      'Des': 12,
    };

    try {
      // Format: "15 Jan 2025" atau "15 Jan 2025 - 20 Jan 2025"
      final parts = dateStr.split(' - ');
      final tanggalStr = parts[0].trim();
      final components = tanggalStr.split(' ');
      if (components.length == 3) {
        final day = int.parse(components[0]);
        final month = bulan[components[1]] ?? 1;
        final year = int.parse(components[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  // ── Helper: Ambil nama kota dari koordinat (reverse geocoding sederhana) ─
  static String kotaDariLokasi(double lat, double lng) {
    // Mapping koordinat kasar ke nama kota Indonesia
    if (lat >= -6.5 && lat <= -5.9 && lng >= 106.5 && lng <= 107.2) {
      return 'Jakarta';
    } else if (lat >= -7.1 && lat <= -6.8 && lng >= 107.4 && lng <= 107.8) {
      return 'Bandung';
    } else if (lat >= -7.9 && lat <= -7.6 && lng >= 110.2 && lng <= 110.6) {
      return 'Yogyakarta';
    } else if (lat >= -7.4 && lat <= -7.1 && lng >= 112.5 && lng <= 112.9) {
      return 'Surabaya';
    } else if (lat >= -8.8 && lat <= -8.3 && lng >= 115.0 && lng <= 115.6) {
      return 'Bali';
    } else if (lat >= -6.3 && lat <= -5.8 && lng >= 106.8 && lng <= 107.3) {
      return 'Bekasi';
    } else if (lat >= -7.1 && lat <= -6.9 && lng >= 110.3 && lng <= 110.6) {
      return 'Semarang';
    } else if (lat >= 3.4 && lat <= 3.8 && lng >= 98.5 && lng <= 98.9) {
      return 'Medan';
    } else if (lat >= -5.3 && lat <= -4.9 && lng >= 119.3 && lng <= 119.6) {
      return 'Makassar';
    }
    return 'Indonesia';
  }
}

// ── Model Data ──────────────────────────────────────────────────

enum PrediksiStatus {
  sempurna,
  bagus,
  terlalu_lama,
  agak_singkat,
  terlalu_singkat,
}

class DurasiPrediksi {
  final int durasiDipilih;
  final int durasiIdeal;
  final String kategoriDestinasi;
  final String status;
  final String pesan;
  final PrediksiStatus statusEnum;
  final double jarakEstimasiJam;

  DurasiPrediksi({
    required this.durasiDipilih,
    required this.durasiIdeal,
    required this.kategoriDestinasi,
    required this.status,
    required this.pesan,
    required this.statusEnum,
    required this.jarakEstimasiJam,
  });
}
