import 'package:flutter/foundation.dart';

import 'web_notification_stub.dart' if (dart.library.html) 'web_notification_real.dart';

class WebNotificationService {
  bool _permitted = false;

  Future<void> requestPermission() async {
    if (!kIsWeb) return;
    try {
      final result = await requestWebPermission();
      _permitted = result;
      debugPrint('Web notification permission: $_permitted');
    } catch (e) {
      debugPrint('Web notification not supported: $e');
    }
  }

  void show(String title, String body) {
    if (!kIsWeb || !_permitted) return;
    try {
      showWebNotification(title, body);
    } catch (e) {
      debugPrint('Web notification error: $e');
    }
  }
}