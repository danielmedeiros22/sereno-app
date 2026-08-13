import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationResult {
  final double latitude;
  final double longitude;
  final String? address;

  LocationResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class LocationService {
  Future<LocationResult?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final address = await _reverseGeocode(position.latitude, position.longitude);

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'SerenoApp/1.0',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addr = data['address'];
        if (addr == null) return data['display_name'];

        final parts = <String>[];
        if (addr['road'] != null) parts.add(addr['road']);
        if (addr['house_number'] != null) parts.add(addr['house_number']);
        if (addr['suburb'] != null) parts.add(addr['suburb']);
        if (addr['city'] != null || addr['town'] != null) {
          parts.add(addr['city'] ?? addr['town']);
        }

        return parts.isNotEmpty ? parts.join(', ') : data['display_name'];
      }
    } catch (e) {
      debugPrint('Geocode error: $e');
    }
    return null;
  }
}