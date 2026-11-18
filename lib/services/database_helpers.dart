// Pilih penyimpanan riwayat sesuai kemampuan platform.
//
// Default (web) memakai SharedPreferences karena sqflite tidak bisa
// dikompilasi ke JavaScript; pada Android/iOS/desktop memakai SQLite.
export 'database_helper_prefs.dart'
    if (dart.library.io) 'database_helper_sqlite.dart';
