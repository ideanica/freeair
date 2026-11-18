// Pilih implementasi HealthService sesuai kemampuan platform.
//
// Default (web) memakai data simulasi karena package:health_connector
// meng-import dart:io sehingga tidak bisa dikompilasi ke JavaScript.
export 'health_service_demo.dart'
    if (dart.library.io) 'health_service_native.dart';
