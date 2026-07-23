import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme.dart';
import '../../models/cafe.dart';
import '../../services/api_service.dart';
import '../cafes/cafe_detail_page.dart';
import '../cafes/add_cafe_page.dart' as biteslog_add_cafe;
import '../cafes/cafe_picker_sheet.dart';

class CreateEditListPage extends StatefulWidget {
  final String? initialId;
  final String? initialTitle;
  final String? initialDescription;
  final bool? initialIsPublic;
  final List<Map<String, dynamic>>? initialItems; // Pakai Map supaya ada note & city

  const CreateEditListPage({
    super.key,
    this.initialId,
    this.initialTitle,
    this.initialDescription,
    this.initialIsPublic,
    this.initialItems,
  });

  @override
  State<CreateEditListPage> createState() => _CreateEditListPageState();
}

class _CreateEditListPageState extends State<CreateEditListPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late bool _isPublic;
  late List<Map<String, dynamic>> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descController = TextEditingController(text: widget.initialDescription ?? '');
    _isPublic = widget.initialIsPublic ?? true;
    _items = widget.initialItems != null ? List.from(widget.initialItems!) : [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isEditMode => widget.initialId != null;

  void _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });

    if (_isEditMode) {
      try {
        final order = _items.map((e) => e['cafe_id'].toString()).toList();
        await ApiService.reorderCafes(widget.initialId!, order);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan urutan: $e')));
        }
      }
    }
  }

  void _removeCafe(int index) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Cafe?'),
        content: const Text('Yakin ingin menghapus cafe ini dari list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final removedItem = _items[index];
    setState(() {
      _items.removeAt(index);
    });

    if (_isEditMode) {
      try {
        await ApiService.removeCafeFromList(widget.initialId!, removedItem['cafe_id']);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus cafe dari server')));
          // Rollback
          setState(() {
            _items.insert(index, removedItem);
          });
        }
      }
    }
  }

  Future<void> _editNote(int index) async {
    if (!_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simpan list terlebih dahulu untuk menambahkan note')));
      return;
    }

    final item = _items[index];
    final noteCtrl = TextEditingController(text: item['note']?.toString() ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Catatan Kurator'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Tulis kesan atau rekomendasi...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppColors.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, noteCtrl.text),
            child: const Text('Simpan', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null) {
      final newNote = result.trim().isEmpty ? null : result.trim();
      final oldNote = item['note'];

      setState(() {
        _items[index]['note'] = newNote;
      });

      try {
        await ApiService.updateCafeNote(widget.initialId!, item['cafe_id'], newNote);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan catatan: $e')));
          setState(() {
            _items[index]['note'] = oldNote;
          });
        }
      }
    }
  }

  Future<void> _showCafePicker() async {
    final dynamic result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CafePickerSheet(
        onSelected: (cafe) => Navigator.pop(context, cafe),
      ),
    );

    if (result != null && mounted) {
      String cafeId = '';
      String cafeName = 'Unknown';
      String cafeCategory = 'Unknown';
      String cafeCity = 'Unknown City';
      String cafeImageUrl = '';

      if (result is Cafe) {
        cafeId = result.id;
        cafeName = result.name;
        cafeCategory = result.categories.isNotEmpty ? result.categories.join(', ') : 'Unknown';
        cafeCity = result.city;
        cafeImageUrl = result.imageUrl;
      }

      if (_items.any((c) => c['cafe_id'] == cafeId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cafe sudah ada di dalam list')),
        );
        return;
      }

      final newItem = {
        'cafe_id': cafeId,
        'name': cafeName,
        'categories': result.categories,
        'city': cafeCity,
        'note': null,
        'imageUrl': cafeImageUrl,
      };

      if (_isEditMode) {
        try {
          await ApiService.addCafeToList(widget.initialId!, cafeId);
          setState(() {
            _items.add(newItem);
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menambah cafe: $e')));
        }
      } else {
        setState(() {
          _items.add(newItem);
        });
      }
    }
  }

  Future<void> _saveList() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final description = _descController.text.trim();
    final finalDesc = description.isEmpty ? null : description;

    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        await ApiService.updateList(
          listId: widget.initialId!,
          title: title,
          description: finalDesc,
          isPublic: _isPublic,
        );
        // Cafe modification logic handled independently via API
      } else {
        final resp = await ApiService.createList(
          title: title,
          description: finalDesc,
          isPublic: _isPublic,
        );
        final newListId = resp['id'] as String;

        for (final item in _items) {
          try {
            await ApiService.addCafeToList(newListId, item['cafe_id']);
          } catch (e) {}
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('List tersimpan')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildCafePlaceholder(List<String> categories) {
    String emoji = '🌿';
    final cat = categories.isNotEmpty ? categories.first.toLowerCase() : '';
    if (cat.contains('coffee') || cat.contains('kopi')) emoji = '☕';
    else if (cat.contains('matcha')) emoji = '🍵';
    else if (cat.contains('bakery') || cat.contains('roti')) emoji = '🥐';

    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTitleEmpty = _titleController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit List' : 'Buat List Baru'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // TOP FORM CARD
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
                            controller: _titleController,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
                            decoration: const InputDecoration(
                              labelText: 'Judul List',
                              hintText: 'Cth: Tempat Nongkrong Jaksel',
                              border: UnderlineInputBorder(),
                              floatingLabelStyle: TextStyle(color: AppColors.primary),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _descController,
                            maxLines: 3,
                            style: const TextStyle(color: AppColors.text),
                            decoration: const InputDecoration(
                              labelText: 'Deskripsi (opsional)',
                              hintText: 'Cth: Cafe nyaman buat WFC dan nugas',
                              border: UnderlineInputBorder(),
                              floatingLabelStyle: TextStyle(color: AppColors.primary),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Jadikan list publik', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
                            subtitle: const Text('Bisa dilihat semua orang di BitesLog', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                            value: _isPublic,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setState(() => _isPublic = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // LIST ITEMS SECTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cafe di list ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${_items.length} Cafe', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
                        ),
                        child: const Center(
                          child: Text('Belum ada cafe. Tekan tombol Tambah di bawah.', style: TextStyle(color: AppColors.secondary)),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        onReorder: _onReorder,
                        proxyDecorator: (Widget child, int index, Animation<double> animation) {
                          return Material(
                            elevation: 4,
                            color: Colors.transparent,
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Container(
                            key: ValueKey(item['cafe_id']),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Drag Handle
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 12, top: 12),
                                      child: Icon(Icons.drag_indicator, color: AppColors.secondary),
                                    ),
                                  ),
                                  // Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty)
                                        ? Image.network(
                                            item['imageUrl'],
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _buildCafePlaceholder((item['categories'] as List?)?.map((e) => e.toString()).toList() ?? []),
                                          )
                                        : _buildCafePlaceholder((item['categories'] as List?)?.map((e) => e.toString()).toList() ?? []),
                                  ),
                                  const SizedBox(width: 12),
                                  // Info & Note
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on, size: 12, color: AppColors.secondary),
                                            const SizedBox(width: 4),
                                            Text(item['city'] ?? 'Unknown City', style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Note Bubble
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  (item['note'] != null && item['note'].toString().trim().isNotEmpty)
                                                      ? item['note']
                                                      : 'Tambah catatan kurator (opsional)...',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontStyle: FontStyle.italic,
                                                    color: (item['note'] != null && item['note'].toString().trim().isNotEmpty) ? AppColors.text : AppColors.secondary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () => _editNote(index),
                                                child: const Icon(Icons.edit, size: 16, color: AppColors.primary),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Trash Icon
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _removeCafe(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    
                    const SizedBox(height: 16),
                    // Add Cafe Button (Dashed)
                    GestureDetector(
                      onTap: _showCafePicker,
                      child: CustomPaint(
                        painter: _DashedBorderPainter(color: AppColors.primary, strokeWidth: 2, radius: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Tambah Cafe', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
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
                    onPressed: (isTitleEmpty || _isSaving) ? null : _saveList,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.secondary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan List', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  _DashedBorderPainter({required this.color, required this.strokeWidth, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius));
    final Path path = Path()..addRRect(rrect);

    const double dashWidth = 8;
    const double dashSpace = 4;
    double distance = 0;
    
    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final Path extractPath = pathMetric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
      distance = 0;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

