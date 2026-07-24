import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../core/widgets/local_image.dart';
import '../cafes/cafe_detail_page.dart';

class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});

  @override
  State<WatchlistPage> createState() => WatchlistPageState();
}

class WatchlistPageState extends State<WatchlistPage> {
  List<dynamic> _watchlist = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    fetchWatchlist();
  }

  Future<void> fetchWatchlist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await ApiService.getWatchlist();
      if (mounted) {
        setState(() {
          _watchlist = items;
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

  Future<void> _removeItem(int index) async {
    final item = _watchlist[index];
    final cafeId = item['id'].toString();
    
    final backupItem = item;
    
    setState(() {
      _watchlist.removeAt(index);
    });

    try {
      await ApiService.removeFromWatchlist(cafeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dihapus dari Ingin Dikunjungi')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _watchlist.insert(index, backupItem);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _watchlist.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.push_pin_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Belum ada kafe yang ingin dikunjungi. Jelajahi & tandai kafe incaranmu!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.secondary, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _watchlist.length,
                itemBuilder: (context, index) {
                  final item = _watchlist[index];
                  final rawRating = item['rating'] ?? item['avg_rating'];
                  final double ratingVal = rawRating != null ? (double.tryParse(rawRating.toString()) ?? 0.0) : 0.0;
                  final rating = ratingVal > 0 ? '⭐ ${ratingVal.toStringAsFixed(1)}' : 'Belum ada rating';
                  
                  return Dismissible(
                    key: Key(item['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      _removeItem(index);
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CafeDetailPage(cafeId: item['id'].toString()),
                            ),
                          ).then((_) => fetchWatchlist()); // Refresh on back just in case
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item['image_url'] != null
                                    ? LocalImage(
                                        item['image_url'],
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorWidget: _buildPlaceholder(),
                                      )
                                    : _buildPlaceholder(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item['city']} - $rating',
                                      style: const TextStyle(color: AppColors.secondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[300],
      child: const Icon(Icons.coffee, color: Colors.grey),
    );
  }
}
