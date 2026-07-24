import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/local_repository.dart';
import '../../services/local_auth_service.dart';
import '../auth/login_page.dart';
import '../../core/widgets/local_image.dart';
import '../diary/diary_page.dart';
import '../lists/lists_page.dart';
import 'edit_profile_page.dart';
import '../watchlist/watchlist_page.dart';

class ProfilePage extends StatefulWidget {
  final bool isCurrentUser;
  // Kita pertahankan param isCurrentUser untuk kompatibilitas route yang mungkin sisa, 
  // tapi sebenarnya offline apps selalu isCurrentUser = true
  const ProfilePage({super.key, this.isCurrentUser = true});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<WatchlistPageState> _watchlistKey = GlobalKey<WatchlistPageState>();
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index == 2) {
        if (_tabController.index == 2) {
          _watchlistKey.currentState?.fetchWatchlist();
        }
      }
    });
    _fetchProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchProfile() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final user = await LocalRepository.getProfile();
      final statsData = await LocalRepository.getMyStats();
      final data = {
        'user': user,
        'stats': statsData['stats'],
        'taste': statsData['taste'],
      };
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isLoading = false; });
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

    final avgRating = stats['avg_rating_given'] != null && double.tryParse(stats['avg_rating_given'].toString()) != null && double.parse(stats['avg_rating_given'].toString()) > 0
        ? double.parse(stats['avg_rating_given'].toString()).toStringAsFixed(1)
        : '–';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Keluar'),
                  content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await LocalAuthService.logout();
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                }
              }
            },
          ),
        ],
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
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
                        );
                        if (result == true) _fetchProfile();
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.accent,
                            child: user['avatar_url'] != null
                                ? ClipOval(
                                    child: LocalImage(
                                      user['avatar_url'],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorWidget: Text((user['full_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                    ),
                                  )
                                : Text((user['full_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
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
                    const SizedBox(height: 24),

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
                  tabs: const [
                    Tab(text: 'Diari'),
                    Tab(text: 'Daftar'),
                    Tab(text: 'Incaran'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            const DiaryPage(),
            _ProfileListsTab(),
            WatchlistPage(key: _watchlistKey),
          ],
        ),
      ),
    );
  }
}

class _ProfileListsTab extends StatefulWidget {
  @override
  State<_ProfileListsTab> createState() => _ProfileListsTabState();
}

class _ProfileListsTabState extends State<_ProfileListsTab> {
  List<dynamic> _lists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  Future<void> _fetchLists() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await LocalRepository.getMyLists();
      if (mounted) setState(() { _lists = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_lists.isEmpty) return const Center(child: Text('Belum ada daftar.', style: TextStyle(color: Colors.grey)));

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
