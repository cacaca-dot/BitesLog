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
import '../cafes/add_cafe_page.dart';
import '../cafes/cafe_picker_sheet.dart';

class LogVisitPage extends StatefulWidget {
  final VoidCallback? onSaved;
  final Cafe? initialCafe;
  const LogVisitPage({super.key, this.onSaved, this.initialCafe});

  @override
  State<LogVisitPage> createState() => _LogVisitPageState();
}

class _LogVisitPageState extends State<LogVisitPage> {
  Cafe? _selectedCafe;
  DateTime _visitDate = DateTime.now();
  double? _rating;
  
  @override
  void initState() {
    super.initState();
    _selectedCafe = widget.initialCafe;
  }
  
  final _reviewController = TextEditingController();
  final _drinkController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  List<XFile> _imageFiles = [];
  List<Uint8List> _webImageBytesList = [];
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;
  bool _allowPop = false;

  @override
  void dispose() {
    _reviewController.dispose();
    _drinkController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showCafePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return CafePickerSheet(
          onSelected: (cafe) {
            setState(() => _selectedCafe = cafe);
            Navigator.pop(ctx);
          },
        );
      },
    );
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
    if (_imageFiles.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maksimal 4 foto')));
      return;
    }
    try {
      final List<XFile>? images = await ImagePickerUtil.pickMultiImageSource(context);
      if (images != null && images.isNotEmpty) {
        int remaining = 4 - _imageFiles.length;
        List<XFile> toAdd = images.take(remaining).toList();
        
        if (kIsWeb) {
          List<Uint8List> newBytes = [];
          for (var img in toAdd) {
            newBytes.add(await img.readAsBytes());
          }
          setState(() {
            _imageFiles.addAll(toAdd);
            _webImageBytesList.addAll(newBytes);
          });
        } else {
          setState(() {
            _imageFiles.addAll(toAdd);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
      if (kIsWeb) {
        _webImageBytesList.removeAt(index);
      }
    });
  }

  bool _hasUnsavedChanges() {
    if (_selectedCafe != widget.initialCafe) return true;
    if (_rating != null) return true;
    if (_reviewController.text.trim().isNotEmpty) return true;
    if (_drinkController.text.trim().isNotEmpty) return true;
    if (_priceController.text.trim().isNotEmpty) return true;
    if (_notesController.text.trim().isNotEmpty) return true;
    if (_imageFiles.isNotEmpty) return true;
    return false;
  }

  void _safePop() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    // Jika tidak bisa pop (navigasi habis), biarkan saja — shell tetap tampil
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
        content: const Text('Kunjungan ini belum disimpan.'),
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

  Future<void> _saveVisit() async {
    if (_selectedCafe == null) return;
    
    final reviewText = _reviewController.text.trim();
    if (_rating == null && reviewText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi minimal rating atau review'))
      );
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      List<String> photoUrls = [];
      if (kIsWeb) {
        for (var bytes in _webImageBytesList) {
          final base64Image = 'data:image/jpeg;base64,' + base64Encode(bytes);
          final url = await ApiService.uploadImage(base64Image);
          photoUrls.add(url);
        }
      } else {
        for (var file in _imageFiles) {
          final bytes = await file.readAsBytes();
          final base64Image = 'data:image/jpeg;base64,' + base64Encode(bytes);
          final url = await ApiService.uploadImage(base64Image);
          photoUrls.add(url);
        }
      }

      final priceStr = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
      
      final data = {
        'cafe_id': _selectedCafe!.id,
        'visit_date': _visitDate.toIso8601String().split('T')[0],
        'rating': _rating,
        'review': reviewText.isEmpty ? null : reviewText,
        'favorite_drink': _drinkController.text.trim().isEmpty ? null : _drinkController.text.trim(),
        'price': priceStr.isEmpty ? null : priceStr,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'photos': photoUrls,
      };

      await ApiService.addVisit(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kunjungan tersimpan')));
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          setState(() {
            _selectedCafe = null;
            _visitDate = DateTime.now();
            _rating = null;
            _reviewController.clear();
            _drinkController.clear();
            _priceController.clear();
            _notesController.clear();
            _imageFiles.clear();
            _webImageBytesList.clear();
          });

          if (widget.onSaved != null) {
            widget.onSaved!();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _onWillPop,
        ),
        title: const Text('Catat Kunjungan'),
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
                    // Cafe Selector
                    GestureDetector(
                      onTap: _showCafePicker,
                      child: Container(
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
                              child: _selectedCafe != null
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_selectedCafe!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        if (_selectedCafe!.city != null) Text(_selectedCafe!.city!, style: const TextStyle(color: AppColors.secondary, fontSize: 13)),
                                      ],
                                    )
                                  : const Text('Pilih Kafe', style: TextStyle(color: AppColors.secondary, fontSize: 16)),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.secondary),
                          ],
                        ),
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
                    const Text('Pesanan Favorit (opsional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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

                    // Private Notes
                    const Text('Catatan Pribadi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Catatan pribadi (tidak publik)',
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Image Picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Foto Kunjungan (Maks 4)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('${_imageFiles.length}/4', style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_imageFiles.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: _imageFiles.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: kIsWeb
                                      ? Image.memory(_webImageBytesList[index], fit: BoxFit.cover)
                                      : Image.file(File(_imageFiles[index].path), fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    if (_imageFiles.length < 4)
                      Padding(
                        padding: EdgeInsets.only(top: _imageFiles.isNotEmpty ? 16.0 : 0.0),
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
                    const SizedBox(height: 32),
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
                    onPressed: (_selectedCafe == null || _rating == null || _priceController.text.trim().isEmpty || _isSaving) ? null : _saveVisit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.secondary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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


