import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuestService {
  static const _guestKey = 'is_guest_mode';

  Future<void> enableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, true);
  }

  Future<void> disableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, false);
  }

  Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestKey) ?? false;
  }
}

final guestServiceProvider = Provider<GuestService>((ref) {
  return GuestService();
});

final isGuestProvider = StateProvider<bool>((ref) => false);

