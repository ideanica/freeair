package com.example.health_alert

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity diperlukan karena health_connector memakai
// registerForActivityResult untuk meminta izin Health Connect.
class MainActivity : FlutterFragmentActivity()
