import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/cafe.dart';
import '../../services/api_service.dart';
import '../../services/local_repository.dart';
import '../../core/utils.dart';
import '../cafes/cafe_picker_sheet.dart';
import '../../core/image_picker_util.dart';
import '../../core/widgets/local_image.dart';
import 'package:image_picker/image_picker.dart';

class CreateEditListPage extends StatefulWidget {
  final String? initialId;
  final String? initialTitle;
  final String? initialDescription;
  final bool? initialIsPublic;
  final List<Map<String, dynamic>>? initialItems; 

  const CreateEditListPage({
    super.key,
    this.initialId,
    this.initialTitle,
    this.initialDescription,
    this.initialIsPublic,
    this.initialItems,
    this.initialCoverImage,
  });

  final String? initialCoverImage;

  @override
  State<CreateEditListPage> createState() => _CreateEditListPageState();
}

class _CreateEditListPageState extends State<CreateEditListPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late List<Map<String, dynamic>> _items;
  bool _isSaving = false;
  XFile? _coverImageFile;
  String? _existingCoverImage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descController = TextEditingController(text: widget.initialDescription ?? '');
    _items = widget.initialItems != null ? List.from(widget.initialItems!) : [];
    _existingCoverImage = widget.initialCoverImage;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isEditMode => widget.initialId != null;

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  Future<void> _removeCafe(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kafe?'),
        content: const Text('Apakah Anda yakin ingin menghapus kafe ini dari daftar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _items.removeAt(index);
      });
    }
  }

  Future<void> _editNote(int index) async {
    final item = _items[index];
    final noteCtrl = TextEditingController(text: item['notes']?.toString() ?? '');

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
      setState(() {
        _items[index]['notes'] = result;
      });
    }
  }

  Future<void> _showCafePicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CafePickerSheet(
        onSelected: (cafe) {
          final exists = _items.any((item) => item['cafe_id'] == cafe.id);
          if (exists) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kafe sudah ada di daftar ini')));
            return;
          }
          
          if (mounted) {
            setState(() {
              _items.add({
                'cafe_id': cafe.id,
                'cafe_name': cafe.name,
                'cafe_area': cafe.area,
                'cafe_city': cafe.city,
                'image_url': cafe.imageUrl,
                'notes': '',
              });
            });
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _saveList() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul tidak boleh kosong')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final desc = _descController.text.trim();
      final cafeIds = _items.map((i) => i['cafe_id'].toString()).toList();
      final Map<String, String> notes = {
        for (var i in _items) i['cafe_id'].toString(): i['notes']?.toString() ?? ''
      };

      if (_isEditMode) {
        await ApiService.updateList(
          widget.initialId!,
          title,
          desc,
          cafeIds,
          notes,
          coverImagePath: _coverImageFile?.path ?? _existingCoverImage,
        );
      } else {
        await ApiService.createList(
          title,
          desc,
          cafeIds,
          notes,
          coverImagePath: _coverImageFile?.path,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan daftar: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteList() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Daftar?'),
        content: const Text('Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: AppColors.secondary))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await ApiService.deleteList(widget.initialId!);
        if (mounted) {
          Navigator.pop(context, true); 
          Navigator.pop(context, true); 
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Daftar' : 'Daftar Baru'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteList,
            ),
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _isSaving ? null : _saveList,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final file = await ImagePickerUtil.pickImageSource(context);
                          if (file != null && mounted) {
                            setState(() {
                              _coverImageFile = file;
                              _existingCoverImage = null; // Reset existing if new is picked
                            });
                          }
                        },
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _coverImageFile != null
                                ? LocalImage(_coverImageFile!.path, fit: BoxFit.cover, width: double.infinity, height: 150)
                                : (_existingCoverImage != null && _existingCoverImage!.isNotEmpty)
                                    ? LocalImage(_existingCoverImage!, fit: BoxFit.cover, width: double.infinity, height: 150)
                                    : const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                          SizedBox(height: 8),
                                          Text('Tambah Cover Daftar', style: TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: 'Nama Daftar',
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                      TextField(
                        controller: _descController,
                        style: const TextStyle(fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'Deskripsi (opsional)',
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_items.length} Kafe', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _showCafePicker,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    onReorder: _onReorderItem,
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final hasNote = item['notes'] != null && item['notes'].toString().isNotEmpty;

                      final String? imageUrl = item['image_url'] ?? item['cafe_image'];

                      return Card(
                        key: ValueKey(item['cafe_id']),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 1,
                        child: ListTile(
                          leading: imageUrl != null && imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LocalImage(
                                    imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.coffee, color: Colors.grey),
                                ),
                          title: Text(item['cafe_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(LocationHelper.formatLocation(item['cafe_area']?.toString(), item['cafe_city']?.toString()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              if (hasNote) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '📝 ${item['notes']}',
                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[800]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ]
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(hasNote ? Icons.edit_note : Icons.note_add, color: hasNote ? AppColors.primary : Colors.grey),
                                onPressed: () => _editNote(index),
                                tooltip: 'Catatan',
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _removeCafe(index),
                                tooltip: 'Hapus',
                              ),
                              const Icon(Icons.drag_handle, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
