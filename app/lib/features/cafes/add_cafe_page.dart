import 'dart:async';
import 'dart:convert';
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
import 'package:url_launcher/url_launcher.dart';
import '../../core/image_picker_util.dart';
import '../../core/widgets/local_image.dart';
import 'cafe_detail_page.dart';

class AddCafePage extends StatefulWidget {
  final bool fromLogVisit;
  final String? initialName;
  final Map<String, dynamic>? editCafeData;
  const AddCafePage({super.key, this.fromLogVisit = false, this.initialName, this.editCafeData});

  @override
  State<AddCafePage> createState() => _AddCafePageState();
}

class _AddCafePageState extends State<AddCafePage> {
  final _nameController = TextEditingController();
  final List<String> _selectedCategories = [];
  final _pasteController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  
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
  

  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    if (widget.editCafeData != null) {
      final d = widget.editCafeData!;
      _nameController.text = d['name'] ?? '';
      _areaController.text = d['area'] ?? '';
      _addressController.text = d['address'] ?? '';
      _priceRange = d['price_range'] ?? d['price'];
      _latitude = d['latitude'] ?? d['lat'];
      _longitude = d['longitude'] ?? d['lng'];
      _existingImageUrl = d['image_url'];
      if (d['categories'] is List) {
        _selectedCategories.addAll(List<String>.from(d['categories']));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pasteController.dispose();
    _areaController.dispose();
    _addressController.dispose();
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

        String area = '';
        if (kIsWeb) {
          // Fallback untuk Web karena geocoding butuh API key khusus di Web
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
          // Native iOS/Android (gratis via platform geocoder)
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            
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
        
        city = normalizeCity(city);
        
        if (mounted && (street.isNotEmpty || city.isNotEmpty || area.isNotEmpty)) {
          setState(() {
            if (street.isNotEmpty) _addressController.text = street;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lokasi & Alamat berhasil didapatkan!')));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lokasi GPS berhasil, tapi alamat tidak ditemukan.')));
        }
      } catch (e) {
        // Geocoding failed, but we still have lat/lng
        debugPrint('Geocoding error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titik koordinat berhasil disimpan (Geocoding butuh internet).')));
        }
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
    if (_addressController.text.trim().isNotEmpty) return true;
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
        title: const Text('Buang perubahan?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        content: const Text('Data kafe ini belum disimpan.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Lanjut Isi', style: TextStyle(color: AppColors.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buang', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

  Future<void> _saveCafe() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    
    try {
      final address = _addressController.text.trim();
      final pasteContent = _pasteController.text.trim();
      
      String parsedArea = _areaController.text.trim();
      String parsedCity = '';
      
      final sourceForCity = pasteContent.isNotEmpty ? pasteContent : address;
      final kotaMatch = RegExp(r'(Kota|Kabupaten)\s+([A-Za-z\s]+)(?:,|$)').firstMatch(sourceForCity);
      if (kotaMatch != null) {
        parsedCity = '${kotaMatch.group(1)} ${kotaMatch.group(2)!.trim()}';
      }

      final data = {
        'name': name,
        'categories': _selectedCategories.join(','),
        'address': address,
        'area': parsedArea,
        'city': parsedCity,
        'price_range': _priceRange,
        'latitude': _latitude,
        'longitude': _longitude,
      };
      
      if (_imageFile != null) {
        data['image_url'] = _imageFile!.path;
      }

      data.removeWhere((key, value) => value == null || (value is String && value.isEmpty));

      if (widget.editCafeData != null) {
        await ApiService.updateCafe(widget.editCafeData!['id'], data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kafe berhasil diperbarui!')));
          Navigator.pop(context, true);
        }
      } else {
        final result = await ApiService.addCafe(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kafe berhasil ditambahkan!')));
          
          final createdCafe = Cafe.fromJson(result);
          if (widget.fromLogVisit) {
            Navigator.pop(context, createdCafe);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => CafeDetailPage(cafeId: createdCafe.id.toString())),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        title: Text(widget.editCafeData != null ? 'Edit Kafe' : 'Tambah Kafe Baru'),
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
                                showCheckmark: false,
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
                            controller: _pasteController,
                            maxLines: 2,
                            minLines: 1,
                            decoration: const InputDecoration(
                              labelText: 'Tempel Alamat dari Google Maps',
                              hintText: 'Tempel alamat lengkap di sini...',
                              helperText: 'Otomatis mengisi Area dan Alamat di bawah',
                              helperStyle: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              border: UnderlineInputBorder(),
                            ),
                            onChanged: (val) {
                              if (val.isEmpty) return;
                              final kecMatch = RegExp(r'Kecamatan\s+([A-Za-z\s]+)(?:,|$)').firstMatch(val);
                              if (kecMatch != null) {
                                _areaController.text = kecMatch.group(1)!.trim();
                              }
                              final parts = val.split(RegExp(r',\s*Kecamatan'));
                              if (parts.length > 1) {
                                _addressController.text = parts[0].trim();
                              } else {
                                _addressController.text = val;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _areaController,
                            decoration: const InputDecoration(
                              labelText: 'Area / Kecamatan',
                              hintText: 'Cth: Dago, Braga',
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _addressController,
                            maxLines: 2,
                            minLines: 1,
                            decoration: const InputDecoration(
                              labelText: 'Alamat',
                              hintText: 'Cth: Jl. Sudirman No.1',
                              helperText: 'Bisa diisi manual atau otomatis',
                              helperStyle: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              border: UnderlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 24),
                          
                          const Text('Kisaran Harga', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
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

                    // LOCATION BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingLocation ? null : _getLocation,
                            icon: _isLoadingLocation 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location, size: 20),
                            label: Text(
                              _latitude != null ? 'Diperbarui' : 'Lokasi Saat Ini',
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.card,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_latitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: const [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text('Koordinat lokasi tersimpan', style: TextStyle(color: Colors.green, fontSize: 12)),
                          ],
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
                          )
                        else if (_existingImageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LocalImage(_existingImageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
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
