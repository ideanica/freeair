// Pilih implementasi NotificationService sesuai platform.
//
// Default memakai no-op karena package:flutter_local_notifications menarik
// dart:io (lewat implementasi Linux) dan tidak punya implementasi web.
export 'notification_service_noop.dart'
    if (dart.library.io) 'notification_service_local.dart';
