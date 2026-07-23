import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/cafe.dart';
import '../../services/api_service.dart';
import '../../core/utils.dart';
import '../../core/image_picker_util.dart';
import 'cafe_detail_page.dart';

class AddCafePage extends StatefulWidget {
  final bool fromLogVisit;
  final String? initialName;
  const AddCafePage({super.key, this.fromLogVisit = false, this.initialName});

  @override
  State<AddCafePage> createState() => _AddCafePageState();
}

class _AddCafePageState extends State<AddCafePage> {
  final _nameController = TextEditingController();
  final List<String> _selectedCategories = [];
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  
  static const List<String> _availableCategories = ['Kopi', 'Non-Kopi', 'Dessert', 'Roti', 'Kue', 'Makanan Berat', 'Brunch', 'Lainnya'];
  
  String? _priceRange;
  double? _latitude;
  double? _longitude;
  
  XFile? _imageFile;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;
  bool _isLoadingLocation = false;
  bool _allowPop = false;
  

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }


  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePickerUtil.pickImageSource(context);
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) {
          setState(() {
            _imageFile = image;
            _imageBytes = bytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
      }
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied, we cannot request permissions.');
      } 

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      
      // Reverse Geocoding
      try {
        String street = '';
        String city = '';

        if (kIsWeb) {
          // Fallback untuk Web karena geocoding butuh API key khusus di Web
          final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}');
          final response = await http.get(url, headers: {'User-Agent': 'BitesLogApp/1.0'});
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final addressObj = data['address'] ?? {};
            
            street = addressObj['road'] ?? addressObj['pedestrian'] ?? '';
            String suburb = addressObj['suburb'] ?? '';
            if (street.isNotEmpty && suburb.isNotEmpty) street += ', $suburb';
            else if (street.isEmpty) street = suburb;

            city = addressObj['city'] ?? addressObj['town'] ?? addressObj['village'] ?? addressObj['county'] ?? addressObj['state'] ?? '';
          }
        } else {
          // Native iOS/Android (gratis via platform geocoder)
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            
            String streetName = place.street ?? '';
            String subLocality = place.subLocality ?? '';
            
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
        
        city = normalizeCity(city);
        
        if (mounted && (street.isNotEmpty || city.isNotEmpty)) {
          setState(() {
            if (street.isNotEmpty) _addressController.text = street;
            if (city.isNotEmpty) _cityController.text = city;
          });
        }
      } catch (e) {
        // Geocoding failed, but we still have lat/lng
        debugPrint('Geocoding error: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lokasi & Alamat berhasil didapatkan!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  bool _hasUnsavedChanges() {
    if (_nameController.text.trim().isNotEmpty) return true;
    if (_selectedCategories.isNotEmpty) return true;
    if (_areaController.text.trim().isNotEmpty) return true;
    if (_addressController.text.trim().isNotEmpty) return true;
    if (_cityController.text.trim().isNotEmpty) return true;
    if (_priceRange != null) return true;
    if (_imageFile != null) return true;
    return false;
  }

  void _safePop() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _onWillPop() async {
    if (!_hasUnsavedChanges()) {
      setState(() => _allowPop = true);
      _safePop();
      return;
    }
    
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang perubahan?'),
        content: const Text('Data kafe ini belum disimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Lanjut Isi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buang', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (shouldPop == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _safePop();
      });
    }
  }

  Future<void> _saveCafe({bool force = false}) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    
    try {
      String? imageUrl;
      if (_imageBytes != null) {
        final base64Image = 'data:image/jpeg;base64,' + base64Encode(_imageBytes!);
        imageUrl = await ApiService.uploadImage(base64Image);
      }

      final data = {
        'name': name,
        'categories': _selectedCategories,
        'area': _areaController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'price_range': _priceRange,
        'latitude': _latitude,
        'longitude': _longitude,
        'image_url': imageUrl,
      };

      // Buang value yang kosong agar tidak dikirim sbg empty string
      data.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

      final result = await ApiService.addCafe(data, force: force);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kafe berhasil ditambahkan!')));
        
        final createdCafe = Cafe.fromJson(result['data']);
        if (widget.fromLogVisit) {
          Navigator.pop(context, createdCafe);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => CafeDetailPage(cafeId: createdCafe.id.toString())),
          );
        }
      }
    } on DuplicateCafeException catch (e) {
      if (mounted) {
        _showDuplicateDialog(e.candidates);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showDuplicateDialog(List<dynamic> candidates) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sepertinya cafe ini sudah ada', style: TextStyle(color: AppColors.primary)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final c = candidates[index];
              final distance = c['distance_m'] != null ? '${c['distance_m']}m' : '';
              final rating = c['avg_rating'] != null ? '⭐ ${c['avg_rating']}' : 'Belum ada rating';
              
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${c['city']} - $rating\n$distance'),
                  isThreeLine: distance.isNotEmpty,
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () {
                      Navigator.pop(context); // close dialog
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CafeDetailPage(cafeId: c['id'].toString()),
                        ),
                      );
                    },
                    child: const Text('Pakai ini', style: TextStyle(color: Colors.white)),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveCafe(force: true);
            },
            child: const Text('Tetap buat baru', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isNameEmpty = _nameController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _onWillPop,
        ),
        title: const Text('Tambah Kafe Baru'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      body: PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _onWillPop();
        },
        child: SafeArea(
          child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    
                    // CARD FORM
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
                            decoration: const InputDecoration(
                              labelText: 'Nama Kafe',
                              hintText: 'Cth: Kopi Kenangan',
                              border: UnderlineInputBorder(),
                              floatingLabelStyle: TextStyle(color: AppColors.primary),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Kategori', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _availableCategories.map((c) {
                              final isSelected = _selectedCategories.contains(c);
                              return FilterChip(
                                label: Text(c, style: const TextStyle(fontSize: 12)),
                                selected: isSelected,
                                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedCategories.add(c);
                                    } else {
                                      _selectedCategories.remove(c);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _areaController,
                            decoration: const InputDecoration(
                              labelText: 'Area / Kecamatan (opsional)',
                              hintText: 'Cth: Dago, Braga',
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _addressController,
                            maxLines: 3,
                            minLines: 1,
                            decoration: const InputDecoration(
                              labelText: 'Alamat',
                              hintText: 'Cth: Jl. Sudirman No.1',
                              helperText: 'Alamat dari GPS cuma perkiraan — koreksi manual biar pas ya.',
                              helperMaxLines: 2,
                              helperStyle: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'Kota (opsional)',
                              hintText: 'Cth: Jakarta Selatan',
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          const Text('Kisaran Harga (opsional)', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: PriceHelper.availableRanges.map((range) {
                              return ButtonSegment(
                                value: range,
                                label: Text(PriceHelper.getLabel(range), style: const TextStyle(fontSize: 11)),
                              );
                            }).toList(),
                            selected: _priceRange != null ? {_priceRange!} : <String>{},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _priceRange = newSelection.first;
                              });
                            },
                            emptySelectionAllowed: true,
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return AppColors.primary;
                                }
                                return AppColors.background;
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return AppColors.text;
                              }),
                              side: WidgetStateProperty.all(BorderSide(color: AppColors.primary.withOpacity(0.3))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // LOCATION BUTTON
                    ElevatedButton.icon(
                      onPressed: _isLoadingLocation ? null : _getLocation,
                      icon: _isLoadingLocation 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                      label: Text(_latitude != null ? 'Lokasi & Alamat Tersimpan' : 'Pakai lokasi sekarang (GPS)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _latitude != null ? AppColors.accent : AppColors.card,
                        foregroundColor: _latitude != null ? AppColors.text : AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // IMAGE PICKER BUTTON
                    Column(
                      children: [
                        if (_imageBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_imageBytes!, height: 150, width: double.infinity, fit: BoxFit.cover),
                          ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text('Pilih Foto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.card,
                            foregroundColor: AppColors.secondary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppColors.secondary.withOpacity(0.5)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            
            // BOTTOM SAVE BUTTON
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (isNameEmpty || _isSaving) ? null : _saveCafe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.secondary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan Cafe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
      ),
    );
  }
}
