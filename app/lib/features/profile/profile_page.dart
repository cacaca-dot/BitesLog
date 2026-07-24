import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../diary/diary_page.dart';
import '../lists/lists_page.dart';
import '../auth/auth_screen.dart';
import 'edit_profile_page.dart';
import 'followers_following_page.dart';
import '../watchlist/watchlist_page.dart';
import '../notifications/notifications_page.dart';
import '../../core/globals.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  final bool isCurrentUser;

  const ProfilePage({super.key, this.userId, this.isCurrentUser = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _error;

  // Follow state (optimistic)
  bool _isFollowing = false;
  int _followerCount = 0;
  bool _isSelf = false;
  String? _resolvedUserId;
  
  @override
  void initState() {
    super.initState();
    final length = widget.isCurrentUser ? 3 : 2;
    _tabController = TabController(length: length, vsync: this);
    _fetchProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  bool get _effectiveIsSelf => widget.isCurrentUser || _isSelf;

  Future<void> _fetchProfile() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final data = widget.isCurrentUser
          ? await ApiService.getMyProfile()
          : await ApiService.getUserProfile(widget.userId!);

      if (mounted) {
        // Resolve userId for self profile (needed for followers/following navigation)
        if (widget.isCurrentUser && _resolvedUserId == null) {
          _resolvedUserId = await AuthService.getUserId();
        }
        setState(() {
          // Check if we need to update TabController length
          final expectedLength = _effectiveIsSelf ? 3 : 2;
          if (_tabController.length != expectedLength) {
            _tabController.dispose();
            _tabController = TabController(length: expectedLength, vsync: this);
          }

          _profileData = data;
          _isFollowing = data['is_following'] == true;
          _followerCount = int.tryParse(data['follower_count']?.toString() ?? '0') ?? 0;
          _isSelf = data['is_self'] == true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isLoading = false; });
      }
    }
  }

  // Optimistic follow/unfollow with rollback
  Future<void> _toggleFollow() async {
    final wasFollowing = _isFollowing;
    final prevCount = _followerCount;

    // Optimistic update
    setState(() {
      _isFollowing = !wasFollowing;
      _followerCount = wasFollowing ? prevCount - 1 : prevCount + 1;
    });

    try {
      if (wasFollowing) {
        await ApiService.unfollowUser(widget.userId!);
      } else {
        await ApiService.followUser(widget.userId!);
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _followerCount = prevCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ${wasFollowing ? 'berhenti mengikuti' : 'mengikuti'}: $e')),
        );
      }
    }
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTasteChip(Map<String, dynamic>? taste) {
    if (taste == null || taste['tag'] == 'Belum ada taste tag' || taste['tag'] == 'Belum ada tag selera') {
      return const Chip(
        label: Text('🌱 Belum ada tag selera'),
        backgroundColor: AppColors.accent,
        labelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        side: BorderSide.none,
      );
    }
    
    return Chip(
      label: Text('${taste['emoji'] ?? ''} ${taste['tag']}'),
      backgroundColor: AppColors.accent,
      labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      side: BorderSide.none,
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final user = _profileData?['user'] ?? {};
        bool isPrivate = user['is_private'] ?? false;
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('Keluar', style: TextStyle(color: Colors.redAccent)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            actionsAlignment: MainAxisAlignment.center,
                            content: const Text(
                              'Yakin ingin keluar?', 
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.w600, 
                                color: Colors.black87,
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(context, false), 
                                child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold))
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD32F2F),
                                  side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await AuthService.logout();
                            // Menggunakan global navigatorKey agar lebih aman dari isu context/mounted
                            navigatorKey.currentState?.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                              (route) => false,
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gagal logout: $e')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Gagal memuat profil: $_error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _fetchProfile, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    final user = _profileData?['user'] ?? {};
    final stats = _profileData?['stats'] ?? {};
    final taste = _profileData?['taste'];
    final followingCount = int.tryParse(_profileData?['following_count']?.toString() ?? '0') ?? 0;

    final avgRating = stats['avg_rating_given'] != null && double.tryParse(stats['avg_rating_given'].toString()) != null && double.parse(stats['avg_rating_given'].toString()) > 0
        ? double.parse(stats['avg_rating_given'].toString()).toStringAsFixed(1)
        : '–';

    // userId for API calls in tabs
    final effectiveUserId = widget.userId ?? _resolvedUserId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        actions: _effectiveIsSelf ? [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.primary),
            onPressed: _showSettingsSheet,
          ),
        ] : null,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar with badge
                    GestureDetector(
                      onTap: _effectiveIsSelf ? () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
                        );
                        if (result == true) _fetchProfile();
                      } : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.accent,
                            backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                            child: user['avatar_url'] == null
                                ? Text((user['full_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          if (_effectiveIsSelf)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Name & Username
                    Text(
                      user['full_name'] ?? 'User',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user['username'] ?? ''}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    // Bio
                    if (user['bio'] != null && user['bio'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          user['bio'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: AppColors.text),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Pengikut / Mengikuti
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FollowersFollowingPage(
                                userId: effectiveUserId,
                                initialTab: 0,
                                username: user['username'] ?? '',
                              ),
                            )).then((_) => _fetchProfile());
                          },
                          child: Column(
                            children: [
                              Text('$_followerCount', style: const TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text('Pengikut', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Container(width: 1, height: 24, color: Colors.grey.shade300),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FollowersFollowingPage(
                                userId: effectiveUserId,
                                initialTab: 1,
                                username: user['username'] ?? '',
                              ),
                            )).then((_) => _fetchProfile());
                          },
                          child: Column(
                            children: [
                              Text('$followingCount', style: const TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text('Mengikuti', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Follow Button for others
                    if (!_effectiveIsSelf) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing ? AppColors.card : AppColors.primary,
                            foregroundColor: _isFollowing ? AppColors.text : Colors.white,
                            side: _isFollowing ? const BorderSide(color: Colors.grey) : null,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(_isFollowing ? 'Mengikuti' : 'Ikuti'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Stats Bar (Pink panel)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn('Kunjungan', '${stats['total_visits'] ?? 0}'),
                          _buildStatColumn('Kafe', '${stats['unique_cafes'] ?? 0}'),
                          _buildStatColumn('Daftar', '${stats['total_lists'] ?? 0}'),
                          _buildStatColumn('Rating', avgRating),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Seleraku
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Seleraku', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildTasteChip(taste),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    const Tab(text: 'Diari'),
                    const Tab(text: 'Daftar'),
                    if (_effectiveIsSelf) const Tab(text: 'Ingin Dikunjungi'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Diary Tab
            _effectiveIsSelf
                ? const DiaryPage()
                : _ProfileDiaryTab(userId: effectiveUserId!, isFollowing: _isFollowing, isPrivate: user['is_private'] == true),

            // Lists Tab
            _effectiveIsSelf
                ? _ProfileListsTab(isCurrentUser: true)
                : _ProfileListsTab(isCurrentUser: false, userId: effectiveUserId, isFollowing: _isFollowing, isPrivate: user['is_private'] == true),
            
            // Watchlist Tab
            if (_effectiveIsSelf) const WatchlistPage(),
          ],
        ),
      ),
    );
  }
}

// ============================================
// DIARY TAB for other users (privacy-aware)
// ============================================

class _ProfileDiaryTab extends StatefulWidget {
  final String userId;
  final bool isFollowing;
  final bool isPrivate;
  const _ProfileDiaryTab({required this.userId, required this.isFollowing, required this.isPrivate});

  @override
  State<_ProfileDiaryTab> createState() => _ProfileDiaryTabState();
}

class _ProfileDiaryTabState extends State<_ProfileDiaryTab> {
  bool _isLoading = true;
  bool _locked = false;
  List<dynamic> _visits = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant _ProfileDiaryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowing != widget.isFollowing) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getUserVisits(widget.userId);
      if (mounted) {
        setState(() {
          _locked = data['locked'] == true;
          _visits = (data['visits'] as List<dynamic>?) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isLoading = false; });
      }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_locked) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('🔒 Akun ini privat — ikuti buat lihat aktivitasnya', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Let the user use the header button to follow, or we could trigger it here.
                // We'll just prompt them to tap the header follow button if they tap this.
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan tekan tombol Ikuti di bagian atas profil')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Ikuti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
    if (_visits.isEmpty) return const Center(child: Text('Belum ada kunjungan.', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _visits.length,
      itemBuilder: (_, i) {
        final v = _visits[i];
        final rating = v['rating'] != null ? double.tryParse(v['rating'].toString()) ?? 0.0 : 0.0;
        
        return Card(
          color: AppColors.card,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 60, height: 60,
                    child: (v['cafe_image'] != null && v['cafe_image'].toString().isNotEmpty)
                        ? Image.network(v['cafe_image'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.accent, child: const Icon(Icons.local_cafe, color: AppColors.secondary)))
                        : Container(color: AppColors.accent, child: const Icon(Icons.local_cafe, color: AppColors.secondary)),
                  ),
                ),
                const SizedBox(width: 12),
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
        );
      },
    );
  }
}

// ============================================
// LISTS TAB (privacy-aware for other users)
// ============================================

class _ProfileListsTab extends StatefulWidget {
  final bool isCurrentUser;
  final String? userId;
  final bool isFollowing;
  final bool isPrivate;
  const _ProfileListsTab({required this.isCurrentUser, this.userId, this.isFollowing = false, this.isPrivate = false});

  @override
  State<_ProfileListsTab> createState() => _ProfileListsTabState();
}

class _ProfileListsTabState extends State<_ProfileListsTab> {
  List<dynamic> _lists = [];
  bool _isLoading = true;
  bool _locked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  @override
  void didUpdateWidget(covariant _ProfileListsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowing != widget.isFollowing) {
      _fetchLists();
    }
  }

  Future<void> _fetchLists() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      if (widget.isCurrentUser) {
        final data = await ApiService.getMyLists();
        if (mounted) setState(() { _lists = data; _isLoading = false; _locked = false; });
      } else {
        final data = await ApiService.getUserLists(widget.userId!);
        if (mounted) {
          setState(() {
            _locked = data['locked'] == true;
            _lists = (data['lists'] as List<dynamic>?) ?? [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_locked) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('🔒 Akun ini privat — ikuti buat lihat aktivitasnya', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan tekan tombol Ikuti di bagian atas profil')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Ikuti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
    if (_lists.isEmpty) {
      return const Center(child: Text('Belum ada daftar.', style: TextStyle(color: Colors.grey)));
    }

    return RefreshIndicator(
      onRefresh: _fetchLists,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _lists.length,
        itemBuilder: (context, index) {
          final list = _lists[index];
          return ListCard(list: list, onRefresh: _fetchLists);
        },
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.background, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
