import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../models/cafe.dart';
import '../cafes/cafe_detail_page.dart';
import '../search/search_page.dart';
import '../../core/utils.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  List<Cafe> _catalog = [];
  List<Cafe> _popular = [];
  bool _loading = true;
  String? _error;

  // Filter state
  List<String> _availableCategories = [];
  List<String> _availableAreas = [];
  
  List<String> _selectedCategories = [];
  List<String> _selectedAreas = [];
  String? _selectedMinRating;
  List<String> _selectedPrices = [];

  @override
  void initState() {
    super.initState();
    _fetchFilters();
    _fetchData();
  }

  Future<void> _fetchFilters() async {
    try {
      final filters = await ApiService.getFilters();
      if (mounted) {
        setState(() {
          _availableCategories = List<String>.from(filters['categories'] ?? []);
          _availableAreas = List<String>.from(filters['areas'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Gagal fetch filters: $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final data = await ApiService.getCafes(
        categories: _selectedCategories.isNotEmpty ? _selectedCategories : null,
        areas: _selectedAreas.isNotEmpty ? _selectedAreas : null,
        minRating: _selectedMinRating != null ? double.tryParse(_selectedMinRating!) : null,
        priceRange: _selectedPrices.isNotEmpty ? _selectedPrices.join(',') : null,
      );
      final List<Cafe> parsedCafes = data.map((e) => Cafe.fromJson(e as Map<String, dynamic>)).toList();
      
      if (mounted) {
        setState(() {
          _catalog = parsedCafes;
          if (!_isFilterActive) {
            _popular = List<Cafe>.from(parsedCafes)..sort((a, b) => b.visitCount.compareTo(a.visitCount));
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool get _isFilterActive => _selectedCategories.isNotEmpty || _selectedAreas.isNotEmpty || _selectedMinRating != null || _selectedPrices.isNotEmpty;
  int get _activeFilterCount => _selectedCategories.length + _selectedAreas.length + (_selectedMinRating != null ? 1 : 0) + _selectedPrices.length;

  void _resetFilters() {
    setState(() {
      _selectedCategories.clear();
      _selectedAreas.clear();
      _selectedMinRating = null;
      _selectedPrices.clear();
    });
    _fetchData();
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter Cafe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        children: [
                          const Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _availableCategories.map((c) {
                              final isSelected = _selectedCategories.contains(c);
                              return FilterChip(
                                label: Text(c),
                                selected: isSelected,
                                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                onSelected: (val) {
                                  setModalState(() {
                                    if (val) _selectedCategories.add(c);
                                    else _selectedCategories.remove(c);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          const Text('Rating Minimum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: ['3.0', '4.0', '4.5'].map((r) {
                              final isSelected = _selectedMinRating == r;
                              return ChoiceChip(
                                label: Text('$r+'),
                                selected: isSelected,
                                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                onSelected: (val) {
                                  setModalState(() {
                                    _selectedMinRating = val ? r : null;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          const Text('Harga', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: PriceHelper.availableRanges.map((p) {
                              final isSelected = _selectedPrices.contains(p);
                              return FilterChip(
                                label: Text(PriceHelper.getFullLabel(p)),
                                selected: isSelected,
                                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                onSelected: (val) {
                                  setModalState(() {
                                    if (val) _selectedPrices.add(p);
                                    else _selectedPrices.remove(p);
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 20),
                          const Text('Area / Kecamatan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _availableAreas.map((a) {
                              final isSelected = _selectedAreas.contains(a);
                              return FilterChip(
                                label: Text(a),
                                selected: isSelected,
                                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                onSelected: (val) {
                                  setModalState(() {
                                    if (val) _selectedAreas.add(a);
                                    else _selectedAreas.remove(a);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                _selectedCategories.clear();
                                _selectedAreas.clear();
                                _selectedMinRating = null;
                                _selectedPrices.clear();
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {}); // Apply state visually
                              _fetchData();
                            },
                            child: const Text('Terapkan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildActiveFilters() {
    if (!_isFilterActive) return const SizedBox.shrink();

    final List<Widget> chips = [];
    
    for (var c in _selectedCategories) {
      chips.add(InputChip(
        label: Text(c, style: const TextStyle(fontSize: 12)),
        onDeleted: () {
          setState(() => _selectedCategories.remove(c));
          _fetchData();
        },
      ));
    }
    
    for (var a in _selectedAreas) {
      chips.add(InputChip(
        label: Text(a, style: const TextStyle(fontSize: 12)),
        onDeleted: () {
          setState(() => _selectedAreas.remove(a));
          _fetchData();
        },
      ));
    }
    
    if (_selectedMinRating != null) {
      chips.add(InputChip(
        label: Text('⭐ $_selectedMinRating+', style: const TextStyle(fontSize: 12)),
        onDeleted: () {
          setState(() => _selectedMinRating = null);
          _fetchData();
        },
      ));
    }

    for (var p in _selectedPrices) {
      chips.add(InputChip(
        label: Text(PriceHelper.getShortLabel(p), style: const TextStyle(fontSize: 12)),
        onDeleted: () {
          setState(() => _selectedPrices.remove(p));
          _fetchData();
        },
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 8,
          children: chips,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('📍 Bandung', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterBottomSheet,
              ),
              if (_isFilterActive)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_activeFilterCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SearchBar(),
            _buildActiveFilters(),
            Expanded(
              child: _loading 
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Gagal memuat: $_error', style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _fetchData, child: const Text('Coba Lagi')),
                            ],
                          ),
                        )
                      : _catalog.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off, size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text('Nggak ada cafe yang cocok sama filter ini.', style: TextStyle(color: Colors.grey)),
                                  if (_isFilterActive)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: OutlinedButton(
                                        onPressed: _resetFilters,
                                        child: const Text('Reset Filter'),
                                      ),
                                    )
                                ],
                              ),
                            )
                          : ListView(
                              children: [
                                if (!_isFilterActive && _popular.isNotEmpty)
                                  _RowSection(title: 'Popular this week', cafes: _popular),
                                
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                                  child: Text(_isFilterActive ? 'Hasil Filter (${_catalog.length})' : 'Browse catalog',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                                
                                _CatalogGrid(catalog: _catalog),
                                const SizedBox(height: 24),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        readOnly: true,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SearchPage(initialTabIndex: 0),
            ),
          );
        },
        decoration: InputDecoration(
          hintText: 'Cari cafe, orang, atau list...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _RowSection extends StatelessWidget {
  final String title;
  final List<Cafe> cafes;
  const _RowSection({required this.title, required this.cafes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cafes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _CafeCard(cafe: cafes[i], width: 160),
          ),
        ),
      ],
    );
  }
}

class _CatalogGrid extends StatelessWidget {
  final List<Cafe> catalog;
  const _CatalogGrid({required this.catalog});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: catalog.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (_, i) => _CafeCard(cafe: catalog[i]),
    );
  }
}

class _CafeCard extends StatelessWidget {
  final Cafe cafe;
  final double? width;
  const _CafeCard({required this.cafe, this.width});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CafeDetailPage(cafeId: cafe.id)),
        );
      },
      child: Container(
        width: width,
        decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: (cafe.imageUrl.isNotEmpty && cafe.imageUrl.startsWith('http')) 
              ? Image.network(
                  cafe.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.card,
                    child: const Icon(Icons.local_cafe, color: AppColors.secondary, size: 40),
                  ),
                )
              : Container(
                  color: AppColors.card,
                  child: const Icon(Icons.local_cafe, color: AppColors.secondary, size: 40),
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cafe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(cafe.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 14),
                    const SizedBox(width: 4),
                    Text(cafe.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    if (cafe.priceRange != null && cafe.priceRange!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('•', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(PriceHelper.getFullLabel(cafe.priceRange!), style: const TextStyle(color: Colors.green, fontSize: 12)),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}