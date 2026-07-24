import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/cafe.dart';
import '../../services/api_service.dart';
import '../../core/utils.dart';
import '../../core/image_picker_util.dart';
import '../../core/widgets/local_image.dart';

class EditVisitPage extends StatefulWidget {
  final Map<String, dynamic> visit;
  const EditVisitPage({super.key, required this.visit});

  @override
  State<EditVisitPage> createState() => _EditVisitPageState();
}

class _EditVisitPageState extends State<EditVisitPage> {
  DateTime _visitDate = DateTime.now();
  double? _rating;
  
  final _reviewController = TextEditingController();
  final _drinkController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  List<XFile> _newImageFiles = [];
  List<Uint8List> _newWebImageBytesList = [];
  List<dynamic> _existingPhotos = [];
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    // Prefill data
    final v = widget.visit;
    if (v['visit_date'] != null) {
      try {
        _visitDate = DateTime.parse(v['visit_date']);
      } catch (_) {}
    }
    if (v['rating'] != null) {
      _rating = double.tryParse(v['rating'].toString());
    }
    if (v['review'] != null) _reviewController.text = v['review'];
    if (v['favorite_drink'] != null) _drinkController.text = v['favorite_drink'];
    if (v['price'] != null) _priceController.text = v['price'].toString();
    if (v['notes'] != null) _notesController.text = v['notes'];
    if (v['photos'] != null && (v['photos'] as List).isNotEmpty) {
      _existingPhotos = List.from(v['photos']);
    } else if (v['photo_path'] != null) {
      _existingPhotos = [{'url': v['photo_path'], 'position': 0}];
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _drinkController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _visitDate = date);
    }
  }

  Future<void> _pickImages() async {
    int totalPhotos = _existingPhotos.length + _newImageFiles.length;
    if (totalPhotos >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maksimal 4 foto')));
      return;
    }
    try {
      final List<XFile>? images = await ImagePickerUtil.pickMultiImageSource(context);
      if (images != null && images.isNotEmpty) {
        int remaining = 4 - totalPhotos;
        List<XFile> toAdd = images.take(remaining).toList();
        
        if (kIsWeb) {
          List<Uint8List> newBytes = [];
          for (var img in toAdd) {
            newBytes.add(await img.readAsBytes());
          }
          setState(() {
            _newImageFiles.addAll(toAdd);
            _newWebImageBytesList.addAll(newBytes);
          });
        } else {
          setState(() {
            _newImageFiles.addAll(toAdd);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
      }
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingPhotos.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImageFiles.removeAt(index);
      if (kIsWeb) {
        _newWebImageBytesList.removeAt(index);
      }
    });
  }

  bool _hasUnsavedChanges() {
    final v = widget.visit;
    final initialRating = v['rating'] != null ? double.tryParse(v['rating'].toString()) : null;
    final initialReview = v['review'] ?? '';
    final initialDrink = v['favorite_drink'] ?? '';
    final initialPrice = v['price']?.toString() ?? '';
    final initialNotes = v['notes'] ?? '';

    if (_rating != initialRating) return true;
    if (_reviewController.text.trim() != initialReview) return true;
    if (_drinkController.text.trim() != initialDrink) return true;
    
    final priceStr = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (priceStr != initialPrice) return true;
    if (_notesController.text.trim() != initialNotes) return true;
    if (_newImageFiles.isNotEmpty) return true;
    
    final initialPhotosLen = (v['photos'] != null && (v['photos'] as List).isNotEmpty) ? (v['photos'] as List).length : (v['photo_path'] != null ? 1 : 0);
    if (_existingPhotos.length != initialPhotosLen) return true;

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
        content: const Text('Perubahan ini belum disimpan.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
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

  Future<void> _saveVisit() async {
    final reviewText = _reviewController.text.trim();
    if (_rating == null && reviewText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi minimal rating atau review'))
      );
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      String? photoPath;
      if (_newImageFiles.isNotEmpty) {
        photoPath = _newImageFiles.first.path;
      } else if (_existingPhotos.isNotEmpty) {
        photoPath = (_existingPhotos.first['url'] ?? _existingPhotos.first['photo_url'])?.toString();
      }

      final priceStr = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
      
      final data = {
        'visit_date': _visitDate.toIso8601String().split('T')[0],
        'rating': _rating,
        'review': reviewText.isEmpty ? null : reviewText,
        'favorite_drink': _drinkController.text.trim().isEmpty ? null : _drinkController.text.trim(),
        'price': priceStr.isEmpty ? null : priceStr,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'photo_path': photoPath,
      };

      await ApiService.updateVisit(widget.visit['id'].toString(), data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kunjungan diperbarui')));
        Navigator.pop(context, true); // Return true to trigger refresh
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
    final v = widget.visit;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _onWillPop,
        ),
        title: const Text('Edit Kunjungan'),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cafe Info (Read-only)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v['cafe_name'] ?? 'Unknown Cafe', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (v['cafe_city'] != null) Text(v['cafe_city'], style: const TextStyle(color: AppColors.secondary, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Date
                    const Text('Tanggal Kunjungan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              "${_visitDate.day}/${_visitDate.month}/${_visitDate.year}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Rating
                    const Text('Rating kamu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          IconData iconData = Icons.star_border;
                          if (_rating != null) {
                            if (_rating! >= index + 1) iconData = Icons.star;
                            else if (_rating! >= index + 0.5) iconData = Icons.star_half;
                          }
                          
                          return GestureDetector(
                            onTapDown: (details) {
                              final double dx = details.localPosition.dx;
                              double newValue = index + (dx > 20 ? 1.0 : 0.5);
                              setState(() {
                                if (_rating == newValue) {
                                  _rating = null;
                                } else {
                                  _rating = newValue;
                                }
                              });
                            },
                            child: Icon(iconData, color: Colors.amber, size: 40),
                          );
                        }),
                      ),
                    ),
                    if (_rating != null)
                      Center(
                        child: Text(
                          '${_rating} Bintang',
                          style: const TextStyle(color: AppColors.secondary, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Review
                    const Text('Review', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reviewController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Bagaimana pengalamanmu?',
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Minuman Favorit
                    const Text('Pesanan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _drinkController,
                      decoration: InputDecoration(
                        hintText: 'Cth: Caramel Macchiato',
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Harga
                    const Text('Perkiraan Harga', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: InputDecoration(
                        hintText: 'Cth: 50.000',
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),



                    // Image Picker
                    // Image Picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Foto Kunjungan (Maks 4)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('${_existingPhotos.length + _newImageFiles.length}/4', style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_existingPhotos.isNotEmpty || _newImageFiles.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: _existingPhotos.length + _newImageFiles.length,
                        itemBuilder: (context, index) {
                          final isExisting = index < _existingPhotos.length;
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: isExisting
                                      ? LocalImage(_existingPhotos[index]['url'] ?? _existingPhotos[index]['photo_url'], fit: BoxFit.cover)
                                      : (kIsWeb
                                          ? Image.memory(_newWebImageBytesList[index - _existingPhotos.length], fit: BoxFit.cover)
                                          : Image.file(File(_newImageFiles[index - _existingPhotos.length].path), fit: BoxFit.cover)),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    if (isExisting) {
                                      _removeExistingImage(index);
                                    } else {
                                      _removeNewImage(index - _existingPhotos.length);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    if (_existingPhotos.length + _newImageFiles.length < 4)
                      Padding(
                        padding: EdgeInsets.only(top: (_existingPhotos.isNotEmpty || _newImageFiles.isNotEmpty) ? 16.0 : 0.0),
                        child: ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Tambah Foto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.card,
                            foregroundColor: AppColors.secondary,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: AppColors.secondary.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Save Button
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
                    onPressed: _isSaving ? null : _saveVisit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.secondary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
