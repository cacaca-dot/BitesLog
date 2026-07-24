import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_auth_service.dart';
import '../../models/cafe.dart';
import '../log/log_visit_page.dart';
import '../visit/visit_detail_page.dart';
import '../profile/profile_page.dart';
import 'add_cafe_page.dart';
import '../../core/utils.dart';
import '../../core/widgets/local_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CafeDetailPage extends StatefulWidget {
  final String cafeId;
  const CafeDetailPage({super.key, required this.cafeId});

  @override
  State<CafeDetailPage> createState() => _CafeDetailPageState();
}

class _CafeDetailPageState extends State<CafeDetailPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _cafe;
  List<dynamic> _reviews = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  List<dynamic> _cafePhotos = [];
  String? _currentUserId;

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cafe = await ApiService.getCafeDetail(widget.cafeId);
      final userId = await LocalAuthService.getCurrentUserId();
      if (mounted) {
        setState(() {
          _cafe = cafe;
          _reviews = cafe['reviews'] ?? [];
          _cafePhotos = cafe['photos'] ?? [];
          _currentUserId = userId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _confirmDelete(BuildContext context, String cafeId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus kafe ini?'),
        content: const Text('Semua kunjungan terkait juga akan terhapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteCafe(cafeId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kafe berhasil dihapus')));
          Navigator.pop(context, true); 
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus kafe: $e')));
        }
      }
    }
  }

  Future<void> _toggleWatchlist(bool isCurrentlyIn) async {
    if (isCurrentlyIn) {
      // Remove
      setState(() {
        _cafe!['is_in_watchlist'] = false;
      });
      try {
        await ApiService.removeFromWatchlist(widget.cafeId);
      } catch (e) {
        setState(() {
          _cafe!['is_in_watchlist'] = true;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } else {
      // Add
      setState(() {
        _cafe!['is_in_watchlist'] = true;
      });
      try {
        await ApiService.addToWatchlist(widget.cafeId);
      } catch (e) {
        setState(() {
          _cafe!['is_in_watchlist'] = false;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }



  Widget _buildReviewCard(Map<String, dynamic> review) {
    final avatarLetter = (review['username'] as String?)?.isNotEmpty == true 
        ? review['username'].toString().substring(0, 1).toUpperCase() 
        : 'U';
    
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        onTap: () async {
          if (review['is_anonymous'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Detail kunjungan privat tidak bisa dilihat')));
            return;
          }
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisitDetailPage(visitId: review['id']?.toString() ?? ''),
            ),
          );
          if (result == true) {
            _fetchData();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date & Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDate(review['created_at']?.toString() ?? ''), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (review['rating'] != null)
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(review['rating'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Review Text
              if (review['review'] != null && review['review'].toString().isNotEmpty)
                Text(review['review']?.toString() ?? '', style: const TextStyle(color: AppColors.text)),
                
              // Drink Tag
              if (review['favorite_drink'] != null && review['favorite_drink'].toString().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_cafe, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(review['favorite_drink']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                    ],
                  ),
                ),
                
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_error != null || _cafe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cafe Detail')),
        body: Center(child: Text('Gagal memuat: $_error')),
      );
    }
    
    final c = _cafe!;
    final cafeModel = Cafe.fromJson(c);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.text,
            actions: [
              if (c['created_by'] != null && _currentUserId != null && c['created_by'].toString() == _currentUserId) ...[
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.black87),
                    tooltip: 'Edit Kafe',
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddCafePage(editCafeData: c),
                        ),
                      );
                      if (result == true) {
                        _fetchData();
                      }
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Hapus Kafe',
                    onPressed: () => _confirmDelete(context, c['id'].toString()),
                  ),
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: (c['image_url'] != null && c['image_url'].toString().isNotEmpty)
                  ? LocalImage(c['image_url'], fit: BoxFit.cover,
                      errorWidget: const Center(child: Icon(Icons.local_cafe, size: 50, color: AppColors.secondary)))
                  : const Center(child: Icon(Icons.local_cafe, size: 50, color: AppColors.secondary)),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Price Range
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          c['name'] ?? 'Unknown Cafe',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text),
                        ),
                      ),
                      if (c['price_range'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(PriceHelper.getFullLabel(c['price_range']), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  
                  // City & Area
                  Builder(
                    builder: (context) {
                      final address = c['address']?.toString() ?? '';
                      String displayArea = c['area']?.toString() ?? '';
                      String displayCity = c['city']?.toString() ?? 'City';
                      
                      if (address.isNotEmpty) {
                        final kecMatch = RegExp(r'Kecamatan\s+([A-Za-z\s]+)(?:,|$)').firstMatch(address);
                        if (kecMatch != null) {
                          displayArea = kecMatch.group(1)!.trim();
                        }
                        
                        final kotaMatch = RegExp(r'(Kota|Kabupaten)\s+([A-Za-z\s]+)(?:,|$)').firstMatch(address);
                        if (kotaMatch != null) {
                          displayCity = '${kotaMatch.group(1)} ${kotaMatch.group(2)!.trim()}';
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_city, size: 14, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Text(displayCity, style: const TextStyle(color: AppColors.secondary)),
                              if (displayArea.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.map, size: 14, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text(displayArea, style: const TextStyle(color: AppColors.secondary)),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  
                  // Categories
                  if (c['categories'] != null && (c['categories'] as List).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (c['categories'] as List).map((cat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Text(cat.toString(), style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                        );
                      }).toList(),
                    ),
                  ],
                  
                  // Address
                  if (c['address'] != null && c['address'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.location_on, size: 14, color: AppColors.secondary),
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: Text(c['address'], style: const TextStyle(color: AppColors.secondary))),
                      ],
                    ),
                  ],
                  
                  Builder(
                    builder: (context) {
                      final name = cafeModel.name;
                      final address = cafeModel.address?.trim();
                      final lat = double.tryParse(c['latitude']?.toString() ?? '');
                      final lng = double.tryParse(c['longitude']?.toString() ?? '');
                      
                      final hasName = name.isNotEmpty;
                      final hasAddress = address != null && address.isNotEmpty;
                      final hasCoords = lat != null && lng != null;
                      
                      if (!hasName && !hasAddress && !hasCoords) {
                        return const SizedBox.shrink();
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            String query;
                            if (hasName && hasAddress) {
                              query = Uri.encodeComponent('$name, $address');
                            } else if (hasName) {
                              query = Uri.encodeComponent(name);
                            } else {
                              query = '$lat,$lng';
                            }
                            
                            final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                            debugPrint('MAPS URL >>> $uri');
                            try {
                              await launchUrl(
                                uri,
                                mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
                                webOnlyWindowName: '_blank',
                              );
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nggak bisa buka Maps')));
                            }
                          },
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text('Buka di Maps', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      );
                    }
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // User Rating & Stats
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text('Rating Kamu', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                            const SizedBox(height: 4),
                              Builder(
                                builder: (context) {
                                  final rating = c['avg_rating'] != null ? (double.tryParse(c['avg_rating'].toString()) ?? 0) : 0.0;
                                  return Row(
                                    children: [
                                      Icon(Icons.star, color: rating > 0 ? Colors.orange : Colors.grey, size: 20),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating > 0 ? rating.toStringAsFixed(1) : 'Belum ada rating',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: rating > 0 ? 18 : 14, color: AppColors.text),
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                        Container(width: 1, height: 30, color: AppColors.secondary.withOpacity(0.3)),
                        Column(
                          children: [
                            const Text('Total Kunjungan', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('${c['visit_count'] ?? 0} kunjungan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LogVisitPage(initialCafe: cafeModel)),
                            );
                            if (result == true) {
                              _fetchData(); // Refresh after logging a visit
                            }
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Catat Kunjungan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleWatchlist(c['is_in_watchlist'] == true),
                          icon: Icon(c['is_in_watchlist'] == true ? Icons.bookmark : Icons.bookmark_border, 
                            color: c['is_in_watchlist'] == true ? AppColors.primary : AppColors.secondary),
                          label: Text(
                            c['is_in_watchlist'] == true ? '✓ Ingin Dikunjungi' : 'Ingin Dikunjungi',
                            style: TextStyle(color: c['is_in_watchlist'] == true ? AppColors.primary : AppColors.secondary, fontWeight: c['is_in_watchlist'] == true ? FontWeight.bold : FontWeight.normal),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: c['is_in_watchlist'] == true ? AppColors.primary : AppColors.secondary.withOpacity(0.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  if (_cafePhotos.isNotEmpty) ...[
                    const Text('Galeri Foto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cafePhotos.length,
                        itemBuilder: (context, index) {
                          final photo = _cafePhotos[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LocalImage(
                                photo['url'] ?? photo['photo_url'],
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  width: 120,
                                  height: 120,
                                  color: AppColors.card,
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  const Text('Kunjungan Kamu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                  const SizedBox(height: 16),
                  
                  if (_reviews.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.rate_review_outlined, size: 48, color: AppColors.secondary),
                          SizedBox(height: 16),
                          Text('Belum ada kunjungan. Yuk catat yang pertama!', style: TextStyle(color: AppColors.secondary)),
                        ],
                      ),
                    )
                  else
                    ..._reviews.map((r) => _buildReviewCard(r)).toList(),
                    
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
