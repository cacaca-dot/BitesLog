import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';
import '../../core/widgets/local_image.dart';
import '../cafes/cafe_detail_page.dart';
import 'create_edit_list_page.dart';

class ListDetailPage extends StatefulWidget {
  final String listId;

  const ListDetailPage({super.key, required this.listId});

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  Map<String, dynamic>? _listData;
  bool _isLoading = true;
  String? _error;
  bool _hasChanged = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getListDetail(widget.listId);
      if (mounted) {
        setState(() {
          _listData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Widget _buildRatingStars(double rating) {
    List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      if (rating >= i) {
        stars.add(const Icon(Icons.star, color: Colors.orange, size: 16));
      } else if (rating >= i - 0.5) {
        stars.add(const Icon(Icons.star_half, color: Colors.orange, size: 16));
      } else {
        stars.add(const Icon(Icons.star_border, color: Colors.orange, size: 16));
      }
    }
    stars.add(const SizedBox(width: 4));
    stars.add(Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));
    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail List')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail List')),
        body: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
      );
    }

    if (_listData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail List')),
        body: const Center(child: Text('Data tidak ditemukan.')),
      );
    }

    final list = _listData!;
    final items = list['items'] as List<dynamic>? ?? [];

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pop(context, _hasChanged);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasChanged),
          ),
          title: Text(list['title'] ?? 'List Detail'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEditListPage(
                      initialId: list['id'],
                      initialTitle: list['title'],
                      initialDescription: list['description'],
                      initialIsPublic: true,
                      initialItems: List<Map<String, dynamic>>.from(items),
                      initialCoverImage: list['cover_image'],
                    ),
                  ),
                );

                if (result == true) {
                  _hasChanged = true;
                  _fetchDetail();
                }
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _fetchDetail,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list['cover_image'] != null && list['cover_image'].toString().isNotEmpty)
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: LocalImage(list['cover_image'], fit: BoxFit.cover),
                  ),
                Container(
                  color: AppColors.card,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(list['title'] ?? '', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text)),
                      if (list['description'] != null && list['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(list['description'], style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    '${items.length} Kafe',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildCafeItem(item);
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCafeItem(Map<String, dynamic> item) {
    final double rating = item['cafe_rating'] != null ? double.tryParse(item['cafe_rating'].toString()) ?? 0.0 : 0.0;
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CafeDetailPage(cafeId: item['cafe_id'].toString())),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80, height: 80,
                child: (item['cafe_image'] != null && item['cafe_image'].toString().isNotEmpty)
                    ? LocalImage(item['cafe_image'], fit: BoxFit.cover, errorWidget: Container(color: AppColors.accent, child: const Icon(Icons.local_cafe, color: AppColors.secondary)))
                    : Container(color: AppColors.accent, child: const Icon(Icons.local_cafe, color: AppColors.secondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['cafe_name'] ?? 'Unknown Cafe',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(LocationHelper.formatLocation(item['cafe_area']?.toString(), item['cafe_city']?.toString()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(item['cafe_price'] ?? '\$\$', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildRatingStars(rating),
                  if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '📝 ${item['notes']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[800], fontStyle: FontStyle.italic),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
