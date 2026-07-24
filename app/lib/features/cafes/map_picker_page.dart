import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;
import '../../core/theme.dart';

class MapPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerPage({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();
  late LatLng _currentCenter;
  
  bool _isDragging = false;
  bool _isLoadingAddress = false;
  
  String _address = '';
  String _area = '';
  String _city = '';

  @override
  void initState() {
    super.initState();
    // Default to Bandung if no initial coordinates are given
    _currentCenter = LatLng(
      widget.initialLat ?? -6.917464,
      widget.initialLng ?? 107.619123,
    );
    _fetchAddress(_currentCenter);
  }

  Future<void> _fetchAddress(LatLng position) async {
    setState(() => _isLoadingAddress = true);
    try {
      String street = '';
      String city = '';
      String area = '';

      if (kIsWeb) {
        // Web Nominatim fallback
        final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}');
        final response = await http.get(url, headers: {'User-Agent': 'BitesLogApp/1.0'});
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final addressObj = data['address'] ?? {};
          
          street = addressObj['road'] ?? addressObj['pedestrian'] ?? '';
          String suburb = addressObj['suburb'] ?? '';
          area = suburb;
          if (street.isNotEmpty && suburb.isNotEmpty) street += ', $suburb';
          else if (street.isEmpty) street = suburb;

          city = addressObj['city'] ?? addressObj['town'] ?? addressObj['village'] ?? addressObj['county'] ?? addressObj['state'] ?? '';
        }
      } else {
        // Native geocoding
        List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          geocoding.Placemark place = placemarks[0];
          
          String streetName = place.street ?? '';
          String subLocality = place.subLocality ?? '';
          area = subLocality;
          
          List<String> addressParts = [];
          if (streetName.isNotEmpty) addressParts.add(streetName);
          if (subLocality.isNotEmpty && subLocality != streetName) addressParts.add(subLocality);
          
          street = addressParts.join(', ');
          city = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? '';
        }
      }

      String normalizeCity(String? raw) {
        if (raw == null) return '';
        return raw
            .replaceAll(RegExp(r'\s+(City|Regency)$', caseSensitive: false), '')
            .replaceAll(RegExp(r'^(Kota|Kabupaten)\s+', caseSensitive: false), '')
            .trim();
      }

      if (mounted) {
        setState(() {
          _address = street;
          _city = normalizeCity(city);
          _area = area;
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih dari Peta', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.text),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
              onPositionChanged: (MapPosition position, bool hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _currentCenter = position.center ?? _currentCenter;
                    _isDragging = true;
                  });
                }
              },
              onMapEvent: (MapEvent event) {
                if (event is MapEventMoveEnd) {
                  setState(() => _isDragging = false);
                  _fetchAddress(_currentCenter);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.biteslog.app',
              ),
            ],
          ),
          
          // Center Marker Pin
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0), // Adjust to make the pin point to the exact center
              child: Icon(
                Icons.location_on,
                size: 48,
                color: _isDragging ? Colors.red.withOpacity(0.5) : Colors.red,
              ),
            ),
          ),
          
          // Bottom Info Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Alamat Terpilih:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 8),
                    if (_isLoadingAddress)
                      const Row(
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Mencari alamat...'),
                        ],
                      )
                    else if (_address.isEmpty && _city.isEmpty)
                      const Text('Alamat tidak ditemukan di titik ini.', style: TextStyle(color: Colors.grey))
                    else
                      Text(
                        '$_address\n${_area.isNotEmpty ? '$_area, ' : ''}$_city',
                        style: const TextStyle(fontSize: 14),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isDragging || _isLoadingAddress
                          ? null
                          : () {
                              Navigator.pop(context, {
                                'latitude': _currentCenter.latitude,
                                'longitude': _currentCenter.longitude,
                                'address': _address,
                                'area': _area,
                                'city': _city,
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Pilih Lokasi Ini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
