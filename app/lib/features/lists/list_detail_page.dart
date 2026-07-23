import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../models/cafe.dart';
import '../cafes/cafe_detail_page.dart';
import 'create_edit_list_page.dart';
import '../../services/auth_service.dart';
import '../../core/widgets/threaded_comments_section.dart';

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
  String? _currentUserId;
  
  bool _isLiked = false;
  bool _isSaved = false;
  int _likeCount = 0;
  int _commentCount = 0;

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
      _currentUserId = await AuthService.getUserId();
      final data = await ApiService.getListDetail(widget.listId);
      if (mounted) {
        setState(() {
          _listData = data;
          _isLiked = data['is_liked'] ?? false;
          _isSaved = data['is_saved'] ?? false;
          _likeCount = data['like_count'] ?? 0;
          _commentCount = data['comment_count'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _toggleLike() async {
    if (_listData == null) return;
    final oldLiked = _isLiked;
    final oldLikeCount = _likeCount;

    // Optimistic UI update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final result = await ApiService.toggleLike('list', widget.listId, oldLiked);
      // Sinkronisasi dari server jika perlu
      if (mounted) {
        setState(() {
          _isLiked = result['liked'] ?? _isLiked;
          _likeCount = result['count'] ?? _likeCount;
        });
      }
    } catch (e) {
      // Rollback on fail
      if (mounted) {
        setState(() {
          _isLiked = oldLiked;
          _likeCount = oldLikeCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _toggleSave() async {
    if (_listData == null) return;
    final oldSaved = _isSaved;

    // Optimistic UI update
    setState(() {
      _isSaved = !_isSaved;
    });

    try {
      final result = await ApiService.toggleSaveList(widget.listId, oldSaved);
      if (mounted) {
        setState(() {
          _isSaved = result['is_saved'] ?? _isSaved;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isSaved ? 'Tersimpan di List Tersimpan ✓' : 'Dihapus dari List Tersimpan'))
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaved = oldSaved;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
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
    final isOwner = list['is_owner'] == true;
    final items = list['items'] as List<dynamic>? ?? [];
    final author = list['author'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(list['title'] ?? 'List Detail'),
        actions: [
          if (!isOwner)
            IconButton(
              icon: Icon(_isSaved ? Icons.library_add_check : Icons.library_add, color: AppColors.primary),
              onPressed: _toggleSave,
            ),
          if (isOwner)
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
                      initialIsPublic: list['is_public'] ?? true,
                      initialItems: List<Map<String, dynamic>>.from(items),
                    ),
                  ),
                );

                if (result == true) {
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
              // HEADER SECTION
              Container(
                color: AppColors.card,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        list['is_public'] == true ? 'PUBLIC' : 'PRIVATE',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(list['title'] ?? '', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text)),
                    if (list['description'] != null && list['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(list['description'], style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                    ],
                    const SizedBox(height: 24),
                    // AUTHOR ROW
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.accent,
                          backgroundImage: author['avatar_url'] != null ? NetworkImage(author['avatar_url']) : null,
                          child: author['avatar_url'] == null ? const Icon(Icons.person, color: AppColors.primary) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(author['full_name'] ?? 'Unknown Author', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                              Text('@${author['username'] ?? 'username'}', style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
                            ],
                          ),
                        ),
                        // ACTIONS (LIKE & COMMENT)
                        Row(
                          children: [
                            InkWell(
                              onTap: _toggleLike,
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: AppColors.primary, size: 24),
                                    const SizedBox(width: 4),
                                    Text('$_likeCount', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () {
                                _scrollController.animateTo(
                                  _scrollController.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.chat_bubble_outline, color: AppColors.secondary, size: 24),
                                    const SizedBox(width: 4),
                                    Text('$_commentCount', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // ITEMS SECTION
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('Belum ada cafe di list ini.', style: TextStyle(color: AppColors.secondary))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final rating = item['avg_rating'] != null ? double.tryParse(item['avg_rating'].toString()) ?? 0.0 : 0.0;
                    final pos = (item['position'] ?? index) + 1;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: AppColors.card,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          final cafeId = item['cafe_id']?.toString();
                          if (cafeId != null && cafeId.isNotEmpty) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => CafeDetailPage(cafeId: cafeId)));
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Number Badge
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary,
                                child: Text('$pos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildRatingStars(rating),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${(item['categories'] as List?)?.join(', ') ?? ''} • ${item['city'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
                                    
                                    // Curator Note Bubble
                                    if (item['note'] != null && item['note'].toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withOpacity(0.2),
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Text(
                                          item['note'],
                                          style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.text, fontSize: 13),
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                ThreadedCommentsSection(
                  targetType: 'list',
                  targetId: widget.listId,
                  currentUserId: _currentUserId,
                  onCountChanged: (count) {
                    if (mounted) setState(() => _commentCount = count);
                  },
                ),
                const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
