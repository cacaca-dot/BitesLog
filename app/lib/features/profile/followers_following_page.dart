import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'profile_page.dart';

class FollowersFollowingPage extends StatefulWidget {
  final String userId;
  final int initialTab;
  final String username;

  const FollowersFollowingPage({
    super.key,
    required this.userId,
    this.initialTab = 0,
    required this.username,
  });

  @override
  State<FollowersFollowingPage> createState() => _FollowersFollowingPageState();
}

class _FollowersFollowingPageState extends State<FollowersFollowingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, initialIndex: widget.initialTab, vsync: this);
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final id = await AuthService.getUserId();
    if (mounted) setState(() => _currentUserId = id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.username, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: _currentUserId == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _UserListTab(
                  fetchUsers: () => ApiService.getFollowers(widget.userId),
                  currentUserId: _currentUserId!,
                ),
                _UserListTab(
                  fetchUsers: () => ApiService.getFollowing(widget.userId),
                  currentUserId: _currentUserId!,
                ),
              ],
            ),
    );
  }
}

class _UserListTab extends StatefulWidget {
  final Future<List<dynamic>> Function() fetchUsers;
  final String currentUserId;

  const _UserListTab({required this.fetchUsers, required this.currentUserId});

  @override
  State<_UserListTab> createState() => _UserListTabState();
}

class _UserListTabState extends State<_UserListTab> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _error;

  // Track follow state per user id for optimistic updates
  final Map<String, bool> _followOverrides = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; _followOverrides.clear(); });
    try {
      final data = await widget.fetchUsers();
      if (mounted) setState(() { _users = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _toggleFollow(String userId, bool currentlyFollowing) async {
    // Optimistic
    setState(() => _followOverrides[userId] = !currentlyFollowing);

    try {
      if (currentlyFollowing) {
        await ApiService.unfollowUser(userId);
      } else {
        await ApiService.followUser(userId);
      }
    } catch (e) {
      // Rollback
      if (mounted) {
        setState(() => _followOverrides[userId] = currentlyFollowing);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_users.isEmpty) return const Center(child: Text('Tidak ada.', style: TextStyle(color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final userId = user['id'].toString();
          final isSelf = userId == widget.currentUserId;

          // Determine follow state: override > server
          final isFollowing = _followOverrides.containsKey(userId)
              ? _followOverrides[userId]!
              : (user['is_following'] == true);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.accent,
              backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
              child: user['avatar_url'] == null
                  ? Text(
                      (user['full_name'] ?? user['username'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            title: Text(user['full_name'] ?? user['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('@${user['username'] ?? ''}', style: const TextStyle(color: Colors.grey)),
            trailing: isSelf
                ? null
                : SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      onPressed: () => _toggleFollow(userId, isFollowing),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? AppColors.card : AppColors.primary,
                        foregroundColor: isFollowing ? AppColors.text : Colors.white,
                        side: isFollowing ? const BorderSide(color: Colors.grey) : null,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontSize: 13)),
                    ),
                  ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(userId: userId, isCurrentUser: isSelf),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
