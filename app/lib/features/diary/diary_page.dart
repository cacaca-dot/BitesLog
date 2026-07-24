import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../core/utils.dart';
import '../../core/widgets/local_image.dart';
import '../visit/visit_detail_page.dart';
import '../log/log_visit_page.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  bool _isLoading = true;
  String? _error;
  int _totalCount = 0;
  
  // Kunci = 'Juli 2026', Value = List of visits
  final Map<String, List<dynamic>> _groupedVisits = {};
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getMyVisits();
      final total = response['total_count'] ?? 0;
      final visits = (response['visits'] as List<dynamic>?) ?? [];

      _groupedVisits.clear();

      for (var v in visits) {
        if (v['visit_date'] != null) {
          try {
            final dt = DateTime.parse(v['visit_date'].toString());
            final monthStr = DateFormat('MMMM yyyy', 'id_ID').format(dt);
            
            if (!_groupedVisits.containsKey(monthStr)) {
              _groupedVisits[monthStr] = [];
            }
            _groupedVisits[monthStr]!.add(v);
          } catch (e) {
            // Abaikan jika format tanggal invalid
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalCount = total;
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

  String _formatDay(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM', 'id_ID').format(dt);
    } catch (e) {
      return '';
    }
  }

  String _formatRelativeTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inDays > 1) {
        return '${diff.inDays} hari lalu';
      } else if (diff.inDays == 1) {
        return 'Kemarin';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} jam lalu';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} menit lalu';
      } else {
        return 'Baru saja';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, size: 64, color: AppColors.secondary),
            const SizedBox(height: 16),
            const Text(
              'Belum ada kunjungan.\nYuk mulai log pertamamu!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LogVisitPage()),
                );
                if (result == true) {
                  _fetchData();
                }
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Log Visit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> v) {
    String? photoUrl;
    if (v['photos'] != null && (v['photos'] as List).isNotEmpty) {
      final firstPhoto = v['photos'][0];
      photoUrl = firstPhoto is Map ? firstPhoto['url'] : firstPhoto.toString();
    }
    final photo = photoUrl ?? v['photo_path'] ?? v['cafe_image'];
    final rating = v['rating'] != null ? double.tryParse(v['rating'].toString()) ?? 0.0 : 0.0;
    
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisitDetailPage(visitId: (v['id'] ?? v['visit_id']).toString()),
            ),
          );
          if (result == true) {
            _fetchData();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: (photo != null && photo.toString().isNotEmpty)
                      ? LocalImage(
                          photo,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: AppColors.accent,
                            child: const Icon(Icons.local_cafe, color: AppColors.secondary),
                          ),
                        )
                      : Container(
                          color: AppColors.accent,
                          child: const Icon(Icons.local_cafe, color: AppColors.secondary),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            v['cafe_name'] ?? 'Unknown Cafe',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text),
                          ),
                        ),
                        if (rating > 0)
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.orange, size: 14),
                              const SizedBox(width: 4),
                              Text(rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            LocationHelper.formatLocation(v['cafe_area'], v['cafe_city']),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    Text(
                      _formatRelativeTime(v['created_at'] ?? v['visit_date'] ?? ''),
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    
                    if (v['review'] != null && v['review'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        v['review'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.text, fontSize: 13),
                      ),
                    ],
                    
                    if (v['favorite_drink'] != null && v['favorite_drink'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          v['favorite_drink'],
                          style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Gagal memuat diary: $_error', style: const TextStyle(color: Colors.red)));
    if (_groupedVisits.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Total Count Header
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              '$_totalCount kunjungan',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
          ),
          
          // Grouped Lists
          ..._groupedVisits.entries.map((entry) {
            final month = entry.key;
            final visits = entry.value;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 8),
                  child: Text(
                    month,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
                  ),
                ),
                ...visits.map((v) => _buildEntryCard(v)).toList(),
                const SizedBox(height: 16),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}
