import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../visit/visit_detail_page.dart';
import '../visit/edit_visit_page.dart';
import '../cafes/cafe_detail_page.dart';
import '../profile/profile_page.dart';
import '../search/search_page.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../notifications/notifications_page.dart';
import '../../core/globals.dart';

// ---- Model ----
class FeedItem {
  final String visitId;
  final String userId;
  final String userName;
  final String avatarLetter;
  final String timeAgo;
  final String cafeId;
  final String cafeName;
  final double rating;
  final String reviewText;
  final String? photoUrl;
  final int likes;
  final int comments;
  final bool isLiked;

  const FeedItem({
    required this.visitId,
    required this.userId,
    required this.userName,
    required this.avatarLetter,
    required this.timeAgo,
    required this.cafeId,
    required this.cafeName,
    required this.rating,
    required this.reviewText,
    this.photoUrl,
    required this.likes,
    required this.comments,
    required this.isLiked,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final name = json['username'] as String? ?? 'User';
    
    // Hitung timeAgo sederhana
    String timeStr = 'Baru saja';
    if (json['created_at'] != null) {
      final date = DateTime.tryParse(json['created_at'].toString());
      if (date != null) {
        final diff = DateTime.now().difference(date);
        if (diff.inDays > 0) {
          timeStr = '${diff.inDays}H AGO';
        } else if (diff.inHours > 0) {
          timeStr = '${diff.inHours}J AGO';
        } else if (diff.inMinutes > 0) {
          timeStr = '${diff.inMinutes}M AGO';
        }
      }
    }

    return FeedItem(
      visitId: json['visit_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: name,
      avatarLetter: name.isNotEmpty ? name[0].toUpperCase() : 'U',
      timeAgo: timeStr,
      cafeId: json['cafe_id']?.toString() ?? '',
      cafeName: json['cafe_name'] as String? ?? 'Unknown Cafe',
      rating: (json['rating'] != null) ? double.parse(json['rating'].toString()) : 0.0,
      reviewText: json['review'] as String? ?? '',
      photoUrl: (json['photos'] != null && (json['photos'] as List).isNotEmpty) ? json['photos'][0]['url'] as String? : json['photo_path'] as String?,
      likes: int.tryParse(json['like_count']?.toString() ?? '0') ?? 0,
      comments: int.tryParse(json['comment_count']?.toString() ?? '0') ?? 0,
      isLiked: json['is_liked'] ?? false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware, WidgetsBindingObserver {
  List<FeedItem> _feed = [];
  bool _loading = true;
  String? _error;
  
  int _unreadCount = 0;
  bool _isSubscribed = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUser();
    _fetchFeed();
    _fetchUnreadCount();
  }
  
  Future<void> _loadCurrentUser() async {
    final uid = await AuthService.getUserId();
    if (mounted) setState(() => _currentUserId = uid);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.subscribe(this, route);
        _isSubscribed = true;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUnreadCount();
    }
  }

  @override
  void didPopNext() {
    _fetchUnreadCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isSubscribed) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final count = await ApiService.getUnreadNotificationCount();
      if (mounted) {
        setState(() => _unreadCount = count);
      }
    } catch (_) {}
  }

  void _removeFeedItem(String visitId) {
    setState(() {
      _feed.removeWhere((item) => item.visitId == visitId);
    });
  }

  Future<void> _fetchFeed() async {
    try {
      final data = await ApiService.getFeed();
      final items = data.map((e) => FeedItem.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() {
          _feed = items;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('BitesLog',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const NotificationsPage(),
                  )).then((_) => _fetchUnreadCount());
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Gagal memuat feed: $_error',
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _fetchFeed();
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _feed.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Belum ada aktivitas', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('Follow orang buat lihat feed mereka', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SearchPage(initialTabIndex: 1), // Tab User
                                ),
                              ).then((_) => _fetchFeed());
                            },
                            child: const Text('Cari orang'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchFeed,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _feed.length,
                        itemBuilder: (_, i) => _FeedCard(
                          item: _feed[i], 
                          currentUserId: _currentUserId,
                          onRefresh: _fetchFeed,
                          onDelete: () => _removeFeedItem(_feed[i].visitId),
                        ),
                      ),
                    ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final FeedItem item;
  final String? currentUserId;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;
  const _FeedCard({required this.item, required this.currentUserId, required this.onRefresh, required this.onDelete});

  // Buka halaman detail visit
  Future<void> _openDetail(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitDetailPage(visitId: item.visitId),
      ),
    );
    if (result == true) {
      onRefresh();
    }
  }

  // Buka halaman detail cafe
  Future<void> _openCafeDetail(BuildContext context) async {
    if (item.cafeId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CafeDetailPage(cafeId: item.cafeId),
      ),
    );
  }

  // Toggle Like
  Future<void> _toggleLike(BuildContext context) async {
    try {
      await ApiService.toggleLike('review', item.visitId, item.isLiked);
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal toggle like: $e')));
      }
    }
  }

  // Aksi menu titik tiga
  Future<void> _onMenu(BuildContext context, String value) async {
    if (value == 'edit') {
      try {
        final visitData = await ApiService.getVisitDetail(item.visitId);
        if (context.mounted) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditVisitPage(visit: visitData),
            ),
          );
          if (result == true) {
            onRefresh();
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil data kunjungan: $e')));
        }
      }
    } else if (value == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus Kunjungan'),
          content: const Text('Hapus kunjungan ini? Nggak bisa dibalikin.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD65A7A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
        ),
      );

      if (confirm == true && context.mounted) {
        // Optimistic update
        onDelete();
        
        try {
          await ApiService.deleteVisit(item.visitId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kunjungan dihapus')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal menghapus kunjungan: $e')),
            );
            onRefresh(); // Revert back by fetching real state
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Header: avatar, nama, waktu, titik tiga ----
            GestureDetector(
              onTap: () async {
                final currentId = await AuthService.getUserId();
                final isSelf = currentId == item.userId;
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(
                        userId: item.userId,
                        isCurrentUser: isSelf,
                      ),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.accent,
                    child: Text(item.avatarLetter,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(item.timeAgo,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  // Titik tiga (hanya jika pemilik postingan)
                  if (currentUserId == item.userId)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (v) => _onMenu(context, v),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline, color: Color(0xFFD65A7A)),
                            title: Text('Hapus', style: TextStyle(color: Color(0xFFD65A7A))),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // ---- Nama cafe ----
            InkWell(
              onTap: () => _openCafeDetail(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.place, size: 18, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(item.cafeName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            
            // ---- Body: Rating, Review, Photo ----
            InkWell(
              onTap: () => _openDetail(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Rating ----
                  Row(
                    children: [
                      _StarRow(rating: item.rating),
                      const SizedBox(width: 6),
                      Text(item.rating.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ---- Review ----
                  if (item.reviewText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(item.reviewText, style: const TextStyle(height: 1.4)),
                    ),
                  // ---- Foto ----
                  if (item.photoUrl != null && item.photoUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Image.network(
                          item.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.accent,
                            child: const Icon(Icons.broken_image,
                                color: Colors.white, size: 40),
                          ),
                        ),
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Container(
                          color: AppColors.accent,
                          child: const Icon(Icons.image,
                              color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 24),
            // ---- Like & komentar ----
            Row(
              children: [
                InkWell(
                  onTap: () => _toggleLike(context),
                  child: Row(
                    children: [
                      Icon(item.isLiked ? Icons.favorite : Icons.favorite_border, color: item.isLiked ? Colors.red : null, size: 20),
                      const SizedBox(width: 4),
                      Text('${item.likes}'),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // 👇 ikon komentar bisa diklik → buka detail
                InkWell(
                  onTap: () => _openDetail(context),
                  child: Row(
                    children: [
                      const Icon(Icons.mode_comment_outlined, size: 20),
                      const SizedBox(width: 4),
                      Text('${item.comments}'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        IconData icon;
        if (rating >= i + 1) {
          icon = Icons.star;
        } else if (rating >= i + 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: 18, color: AppColors.primary);
      }),
    );
  }
}