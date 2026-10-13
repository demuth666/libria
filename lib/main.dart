import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

/// Titik masuk aplikasi Libria.
Future<void> main() async {
  // Siapkan binding sebelum memakai layanan plugin (Firebase dan locale).
  WidgetsFlutterBinding.ensureInitialized();

  // Konfigurasi Firebase dibaca dari android/app/google-services.json.
  await Firebase.initializeApp();

  // Muat data locale Indonesia agar tanggal dan waktu tampil dengan id_ID.
  await initializeDateFormatting('id_ID');

  runApp(const ProviderScope(child: LibriaApp()));
}
