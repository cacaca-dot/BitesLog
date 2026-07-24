import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/utils.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_repository.dart';
import '../../core/widgets/local_image.dart';
import 'edit_visit_page.dart';
import '../cafes/cafe_detail_page.dart';
import '../../core/globals.dart';
import '../profile/profile_page.dart';

class VisitDetailPage extends StatefulWidget {
  final String visitId;
  final String? focusCommentId;
  const VisitDetailPage({super.key, required this.visitId, this.focusCommentId});

  @override
  State<VisitDetailPage> createState() => _VisitDetailPageState();
}

class _VisitDetailPageState extends State<VisitDetailPage> {
  Map<String, dynamic>? _visit;
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;

  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      _currentUserId = await LocalRepository.getUserId();
      
      final visit = await ApiService.getVisitDetail(widget.visitId);
      
      if (mounted) {
        setState(() {
          _visit = visit;
          _error = null;
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



  Future<void> _deleteVisit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kunjungan?'),
        content: const Text('Apakah Anda yakin ingin menghapus kunjungan ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteVisit(widget.visitId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kunjungan dihapus')));
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editVisit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditVisitPage(visit: _visit!),
      ),
    );
    if (result == true) {
      _hasChanged = true;
      _fetchData(); // Refresh data
    }
  }

  // Removed _toggleLike



  String _formatRupiah(dynamic price) {
    if (price == null) return '';
    final numValue = num.tryParse(price.toString());
    if (numValue == null) return '';
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(numValue);
  }
  
  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _visit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Gagal memuat: $_error')),
      );
    }

    final v = _visit!;
    final isOwner = _currentUserId != null && v['user_id']?.toString() == _currentUserId;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasChanged),
          ),

        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: _editVisit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteVisit,
            ),
          ]
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // PHOTO HEADER
                    Builder(
                      builder: (context) {
                        List<dynamic> photos = [];
                        if (v['photos'] != null && (v['photos'] as List).isNotEmpty) {
                          photos = v['photos'];
                        } else if (v['photo_path'] != null && v['photo_path'].toString().isNotEmpty) {
                          photos = [{'url': v['photo_path']}];
                        }
                        
                        if (photos.isNotEmpty) {
                          return SizedBox(
                            height: 250,
                            child: PageView.builder(
                              itemCount: photos.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    LocalImage(
                                      photos[index] is String ? photos[index] : (photos[index] is Map ? (photos[index]['url'] ?? photos[index]['photo_url'])?.toString() : null),
                                      height: 250,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorWidget: Container(
                                        height: 250,
                                        width: double.infinity,
                                        color: AppColors.card,
                                        child: const Icon(Icons.image_not_supported, size: 50, color: AppColors.secondary),
                                      ),
                                    ),
                                    if (photos.length > 1)
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${index + 1}/${photos.length}',
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          );
                        } else {
                          return Container(
                            height: 250,
                            width: double.infinity,
                            color: AppColors.card,
                            child: const Icon(Icons.image, size: 50, color: AppColors.secondary),
                          );
                        }
                      }
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // DATE
                          if (v['visit_date'] != null)
                            Text(
                              _formatDate(v['visit_date']?.toString() ?? ''), 
                              style: const TextStyle(color: Colors.grey, fontSize: 14)
                            ),
                          const SizedBox(height: 16),

                          // CAFE INFO
                          InkWell(
                            onTap: () {
                              final cafeId = v['cafe_id']?.toString();
                              if (cafeId != null && cafeId.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CafeDetailPage(cafeId: cafeId)),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.place, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(v['cafe_name']?.toString() ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                                      Text(LocationHelper.formatLocation(v['cafe_area']?.toString(), v['cafe_city']?.toString()), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // RATING
                          if (v['rating'] != null)
                            Row(
                              children: [
                                Row(
                                  children: List.generate(5, (index) {
                                    double rating = double.tryParse(v['rating'].toString()) ?? 0;
                                    IconData icon = Icons.star_border;
                                    if (rating >= index + 1) icon = Icons.star;
                                    else if (rating >= index + 0.5) icon = Icons.star_half;
                                    return Icon(icon, color: Colors.amber, size: 20);
                                  }),
                                ),
                                const SizedBox(width: 8),
                                Text(v['rating'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          
                          const SizedBox(height: 16),

                          // CHIPS (Favorite Drink & Price)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (v['favorite_drink'] != null && v['favorite_drink'].toString().trim().isNotEmpty)
                                Chip(
                                  avatar: const Icon(Icons.local_cafe, size: 16, color: AppColors.primary),
                                  label: Text(v['favorite_drink']?.toString() ?? ''),
                                  backgroundColor: AppColors.accent.withOpacity(0.5),
                                  side: BorderSide.none,
                                ),
                              if (v['price'] != null && v['price'].toString().trim().isNotEmpty)
                                Chip(
                                  avatar: const Icon(Icons.payments, size: 16, color: Colors.grey),
                                  label: Text(_formatRupiah(v['price'])),
                                  backgroundColor: AppColors.card,
                                  side: BorderSide.none,
                                ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),

                          // REVIEW (The Experience)
                          if (v['review'] != null && v['review'].toString().trim().isNotEmpty) ...[
                            const Text('The Experience', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(v['review']?.toString() ?? '', style: const TextStyle(height: 1.5, fontSize: 15)),
                            const SizedBox(height: 16),
                          ],

                          // PRIVATE NOTES
                          if (isOwner && v['notes'] != null && v['notes'].toString().trim().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.withOpacity(0.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.lock, size: 16, color: Colors.amber),
                                      SizedBox(width: 8),
                                      Text('Private Notes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(v['notes'], style: const TextStyle(fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Removed likes and comments section
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
