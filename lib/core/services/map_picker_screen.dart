import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../app/theme/app_colors.dart';
import 'location_service.dart';

class MapPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final String? initialAddress;

  const MapPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialAddress,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selectedPosition;
  String? _address;
  bool _loadingAddress = false;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedPosition = LatLng(widget.initialLat, widget.initialLng);
    _address = widget.initialAddress;
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loadingAddress = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'SerenoApp/1.0',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addr = data['address'];
        if (addr != null) {
          final parts = <String>[];
          if (addr['road'] != null) parts.add(addr['road']);
          if (addr['house_number'] != null) parts.add(addr['house_number']);
          if (addr['suburb'] != null) parts.add(addr['suburb']);
          if (addr['city'] != null || addr['town'] != null) {
            parts.add(addr['city'] ?? addr['town']);
          }
          setState(() => _address = parts.isNotEmpty ? parts.join(', ') : data['display_name']);
        } else {
          setState(() => _address = data['display_name']);
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    setState(() => _loadingAddress = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ajustar localização'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                LocationResult(
                  latitude: _selectedPosition.latitude,
                  longitude: _selectedPosition.longitude,
                  address: _address,
                ),
              );
            },
            child: const Text('Confirmar',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: 17,
              onTap: (tapPosition, point) {
                setState(() => _selectedPosition = point);
                _reverseGeocode(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sereno.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPosition,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_pin,
                      color: AppColors.expense,
                      size: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _loadingAddress
                            ? Row(children: [
                                const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.primary)),
                                const SizedBox(width: 8),
                                Text('Buscando endereço...',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                              ])
                            : Text(
                                _address ?? 'Toque no mapa para selecionar',
                                style: theme.textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no mapa para ajustar o ponto',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}