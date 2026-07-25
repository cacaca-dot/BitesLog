import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/cafe.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';
import '../../core/widgets/local_image.dart';
import 'add_cafe_page.dart';

class CafePickerSheet extends StatefulWidget {
  final Function(Cafe) onSelected;
  const CafePickerSheet({super.key, required this.onSelected});
  
  @override
  State<CafePickerSheet> createState() => _CafePickerSheetState();
}

class _CafePickerSheetState extends State<CafePickerSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _cafes = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchCafes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchCafes(search: query);
    });
  }

  Future<void> _fetchCafes({String search = ''}) async {
    setState(() => _isLoading = true);
    try {
      final results = await ApiService.getCafes(search: search);
      if (mounted) setState(() => _cafes = results);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Container(
      height: mediaQuery.size.height * 0.8,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Handle
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Pilih Cafe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 16),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari nama cafe...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          const Divider(height: 24),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _cafes.isEmpty
                    ? Center(
                        child: _searchController.text.isEmpty
                            ? const Text('Tidak ada cafe ditemukan', style: TextStyle(color: AppColors.secondary))
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Kafe "${_searchController.text}" tidak ditemukan',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: AppColors.secondary)),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: const Text('Tambahkan sebagai kafe baru', textAlign: TextAlign.center),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () async {
                                        final createdCafe = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AddCafePage(
                                              fromLogVisit: true,
                                              initialName: _searchController.text,
                                            ),
                                          ),
                                        );
                                        if (createdCafe != null && createdCafe is Cafe) {
                                          widget.onSelected(createdCafe);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                      )
                    : ListView.builder(
                        itemCount: _cafes.length,
                        itemBuilder: (ctx, i) {
                          final c = _cafes[i];
                          final cafe = Cafe.fromJson(c);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.accent,
                              child: ClipOval(
                                child: LocalImage(
                                  cafe.imageUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorWidget: const Icon(Icons.local_cafe, color: Colors.white),
                                ),
                              ),
                            ),
                            title: Text(cafe.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                            subtitle: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.orange, size: 14),
                                const SizedBox(width: 4),
                                Text(cafe.rating > 0 ? cafe.rating.toStringAsFixed(1) : '-', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(cafe.city, style: const TextStyle(color: AppColors.secondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            onTap: () => widget.onSelected(cafe),
                          );
                        },
                      ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
