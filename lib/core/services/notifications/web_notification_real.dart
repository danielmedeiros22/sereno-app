import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> requestWebPermission() async {
  try {
    final permission = await web.Notification.requestPermission().toDart;
    return permission == 'granted';
  } catch (_) {
    return false;
  }
}

void showWebNotification(String title, String body) {
  try {
    web.Notification(title);
  } catch (_) {}
}