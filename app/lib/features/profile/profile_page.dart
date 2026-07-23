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

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
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
    _tabController = TabController(length: 2, vsync: this);
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
          SnackBar(content: Text('Gagal ${wasFollowing ? 'unfollow' : 'follow'}: $e')),
        );
      }
    }
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTasteChip(Map<String, dynamic>? taste) {
    if (taste == null || taste['tag'] == 'Belum ada taste tag') {
      return Chip(
        label: const Text('🌱 Belum ada taste tag'),
        backgroundColor: AppColors.accent,
        labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
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
                            title: const Text('Keluar'),
                            content: const Text('Yakin ingin keluar?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Keluar', style: TextStyle(color: Colors.redAccent)),
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
        title: Text(user['username'] ?? 'Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.accent,
                          backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                          child: user['avatar_url'] == null
                              ? Text((user['full_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['full_name'] ?? 'User',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text),
                              ),
                              const SizedBox(height: 4),
                              Row(
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
                                    child: Text(
                                      '$_followerCount Followers',
                                      style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
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
                                    child: Text(
                                      '$followingCount Following',
                                      style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (user['bio'] != null && user['bio'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(user['bio'] ?? '', style: const TextStyle(fontSize: 14, color: AppColors.text)),
                      ),

                    if (_effectiveIsSelf)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
                                );
                                if (result == true) _fetchProfile();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.text,
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Edit Profil'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const WatchlistPage()),
                                );
                              },
                              icon: const Icon(Icons.bookmark_border, size: 18),
                              label: const Text('Ingin Dikunjungi'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.text,
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
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
                          child: Text(_isFollowing ? 'Following' : 'Follow'),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Stats Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('Visits', '${stats['total_visits'] ?? 0}'),
                        _buildStatColumn('Cafes', '${stats['unique_cafes'] ?? 0}'),
                        _buildStatColumn('Lists', '${stats['total_lists'] ?? 0}'),
                        _buildStatColumn('Rating', avgRating),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // My Taste
                    Text(_effectiveIsSelf ? 'My Taste' : 'Taste', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 8),
                    _buildTasteChip(taste),
                    const SizedBox(height: 16),
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
                  tabs: const [
                    Tab(text: 'Diary'),
                    Tab(text: 'Lists'),
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
            const Text('🔒 Akun ini privat — follow buat lihat aktivitasnya', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Let the user use the header button to follow, or we could trigger it here.
                // We'll just prompt them to tap the header follow button if they tap this.
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan tekan tombol Follow di bagian atas profil')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Follow', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        return Card(
          color: AppColors.card,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
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
                      Text(v['cafe_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
                      if (v['rating'] != null)
                        Row(children: [
                          const Icon(Icons.star, color: Colors.orange, size: 14),
                          const SizedBox(width: 4),
                          Text(v['rating'].toString(), style: const TextStyle(fontSize: 13, color: AppColors.text)),
                        ]),
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
            const Text('🔒 Akun ini privat — follow buat lihat aktivitasnya', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan tekan tombol Follow di bagian atas profil')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Follow', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
    if (_lists.isEmpty) {
      return const Center(child: Text('Belum ada list.', style: TextStyle(color: Colors.grey)));
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
