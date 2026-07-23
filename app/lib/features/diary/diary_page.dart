import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
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
    final photo = (v['photos'] != null && (v['photos'] as List).isNotEmpty) ? v['photos'][0]['url'] : (v['photo_path'] ?? v['cafe_image']);
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
              builder: (_) => VisitDetailPage(visitId: v['visit_id'].toString()),
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
                      ? Image.network(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
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
                    Text(
                      v['cafe_name'] ?? 'Unknown Cafe',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    
                    // Rating Row
                    if (rating > 0)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 14),
                          const SizedBox(width: 4),
                          Text(rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                        ],
                      ),
                      
                    const SizedBox(height: 8),
                    
                    // Date & Drink
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDay(v['visit_date'] ?? ''),
                          style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        if (v['favorite_drink'] != null && v['favorite_drink'].toString().isNotEmpty)
                          Expanded(
                            child: Text(
                              ' • ${v['favorite_drink']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.primary, fontSize: 12),
                            ),
                          ),
                      ],
                    )
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
