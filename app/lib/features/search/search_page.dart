import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../profile/profile_page.dart';
import '../cafes/cafe_detail_page.dart';
import '../lists/list_detail_page.dart';
import '../../core/utils.dart';

class SearchPage extends StatefulWidget {
  final int initialTabIndex;

  const SearchPage({super.key, this.initialTabIndex = 1});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  Timer? _debounce;
  
  // Per-tab states
  bool _cafeLoading = false;
  bool _userLoading = false;
  bool _listLoading = false;
  
  List<dynamic>? _cafeResults;
  List<dynamic>? _userResults;
  List<dynamic>? _listResults;
  
  String _cafeLastQuery = '';
  String _userLastQuery = '';
  String _listLastQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String get _currentType {
    switch (_tabController.index) {
      case 0: return 'cafe';
      case 1: return 'user';
      case 2: return 'list';
      default: return 'user';
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    
    final query = _searchController.text.trim();
    if (query.length >= 2) {
      // Auto trigger search for the new tab if query has changed for this tab
      String lastQ = _currentType == 'cafe' ? _cafeLastQuery : (_currentType == 'user' ? _userLastQuery : _listLastQuery);
      if (lastQ != query) {
        _performSearch(query, _currentType);
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _cafeResults = null;
        _userResults = null;
        _listResults = null;
        
        _cafeLastQuery = '';
        _userLastQuery = '';
        _listLastQuery = '';
        
        _cafeLoading = false;
        _userLoading = false;
        _listLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query, _currentType);
    });
  }

  Future<void> _performSearch(String query, String type) async {
    // Set loading for specific tab
    setState(() {
      if (type == 'cafe') {
        _cafeLoading = true;
        _cafeLastQuery = query;
      } else if (type == 'user') {
        _userLoading = true;
        _userLastQuery = query;
      } else if (type == 'list') {
        _listLoading = true;
        _listLastQuery = query;
      }
    });

    try {
      final data = await ApiService.search(query, type: type);
      
      // Guard race condition: check if the query we awaited is still the active query for this tab
      if (!mounted) return;
      
      final isActiveQuery = (type == 'cafe' && _cafeLastQuery == query) ||
                            (type == 'user' && _userLastQuery == query) ||
                            (type == 'list' && _listLastQuery == query);
                            
      if (!isActiveQuery) return;
      
      setState(() {
        if (type == 'cafe') _cafeResults = data;
        else if (type == 'user') _userResults = data;
        else if (type == 'list') _listResults = data;
      });
      
    } catch (e) {
      if (!mounted) return;
      final isActiveQuery = (type == 'cafe' && _cafeLastQuery == query) ||
                            (type == 'user' && _userLastQuery == query) ||
                            (type == 'list' && _listLastQuery == query);
                            
      if (isActiveQuery) {
        setState(() {
          if (type == 'cafe') _cafeResults = null;
          else if (type == 'user') _userResults = null;
          else if (type == 'list') _listResults = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        final isActiveQuery = (type == 'cafe' && _cafeLastQuery == query) ||
                            (type == 'user' && _userLastQuery == query) ||
                            (type == 'list' && _listLastQuery == query);
        if (isActiveQuery) {
          setState(() {
            if (type == 'cafe') _cafeLoading = false;
            else if (type == 'user') _userLoading = false;
            else if (type == 'list') _listLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Cari...',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Cafe'),
            Tab(text: 'User'),
            Tab(text: 'List'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCafeTab(),
          _buildUserTab(),
          _buildListTab(),
        ],
      ),
    );
  }

  Widget _buildCafeTab() {
    return _buildTabContent(
      emptyPrompt: 'Ketik nama cafe atau kota...',
      notFoundMsg: 'Cafe tidak ditemukan',
      isLoading: _cafeLoading,
      results: _cafeResults,
      itemBuilder: (context, index) {
        final cafe = _cafeResults![index];
        return _CafeSearchTile(cafe: cafe);
      },
    );
  }

  Widget _buildUserTab() {
    return _buildTabContent(
      emptyPrompt: 'Ketik nama atau username...',
      notFoundMsg: 'User tidak ditemukan',
      isLoading: _userLoading,
      results: _userResults,
      itemBuilder: (context, index) {
        final user = _userResults![index];
        return _UserSearchTile(user: user);
      },
    );
  }

  Widget _buildListTab() {
    return _buildTabContent(
      emptyPrompt: 'Ketik judul list...',
      notFoundMsg: 'List tidak ditemukan',
      isLoading: _listLoading,
      results: _listResults,
      itemBuilder: (context, index) {
        final listData = _listResults![index];
        return _ListSearchTile(listData: listData);
      },
    );
  }

  Widget _buildTabContent({
    required String emptyPrompt,
    required String notFoundMsg,
    required bool isLoading,
    required List<dynamic>? results,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      return Center(child: Text(emptyPrompt, style: const TextStyle(color: Colors.grey)));
    }
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results != null && results.isEmpty) {
      return Center(child: Text(notFoundMsg, style: const TextStyle(color: Colors.grey)));
    }
    if (results != null && results.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: results.length,
        itemBuilder: itemBuilder,
      );
    }
    return Container();
  }
}

class _UserSearchTile extends StatefulWidget {
  final Map<String, dynamic> user;
  const _UserSearchTile({required this.user});

  @override
  State<_UserSearchTile> createState() => _UserSearchTileState();
}

class _UserSearchTileState extends State<_UserSearchTile> {
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.user['is_following'] == true;
  }

  Future<void> _toggleFollow() async {
    final currentlyFollowing = _isFollowing;
    final userId = widget.user['id']?.toString() ?? '';
    if (userId.isEmpty) return;

    setState(() => _isFollowing = !currentlyFollowing);

    try {
      if (currentlyFollowing) {
        await ApiService.unfollowUser(userId);
      } else {
        await ApiService.followUser(userId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = currentlyFollowing);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.user['avatar_url']?.toString();
    final username = widget.user['username']?.toString() ?? 'user';
    final fullName = widget.user['full_name']?.toString() ?? '';
    final avatarLetter = username.isNotEmpty ? username.substring(0, 1).toUpperCase() : 'U';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null || avatarUrl.isEmpty ? Text(avatarLetter, style: const TextStyle(color: Colors.black)) : null,
      ),
      title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(fullName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing ? Colors.grey.shade300 : AppColors.primary,
          foregroundColor: _isFollowing ? Colors.black : Colors.white,
          elevation: 0,
        ),
        onPressed: _toggleFollow,
        child: Text(_isFollowing ? 'Following' : 'Follow'),
      ),
      onTap: () {
        final userId = widget.user['id']?.toString();
        if (userId == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfilePage(userId: userId, isCurrentUser: false)),
        );
      },
    );
  }
}

class _CafeSearchTile extends StatelessWidget {
  final Map<String, dynamic> cafe;
  const _CafeSearchTile({required this.cafe});

  @override
  Widget build(BuildContext context) {
    final imageUrl = cafe['image_url']?.toString();
    final rating = cafe['avg_rating'] != null ? double.parse(cafe['avg_rating'].toString()).toStringAsFixed(1) : '-';
    final name = cafe['name']?.toString() ?? 'Unknown';
    final categoriesList = cafe['categories'] as List?;
    final categoryStr = (categoriesList != null && categoriesList.isNotEmpty) ? categoriesList.join(', ') : '';
    final city = cafe['city']?.toString() ?? '';
    final price = cafe['price_range']?.toString();

    return ListTile(
      leading: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          image: imageUrl != null && imageUrl.isNotEmpty
              ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
              : null,
        ),
        child: imageUrl == null || imageUrl.isEmpty ? const Icon(Icons.local_cafe, color: Colors.grey) : null,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        price != null && price.isNotEmpty 
            ? '$categoryStr • $city • ${PriceHelper.getFullLabel(price)}' 
            : '$categoryStr • $city', 
        style: const TextStyle(fontSize: 12)
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.orange, size: 16),
          const SizedBox(width: 4),
          Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      onTap: () {
        final cafeId = cafe['id']?.toString();
        if (cafeId == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CafeDetailPage(cafeId: cafeId)),
        );
      },
    );
  }
}

class _ListSearchTile extends StatelessWidget {
  final Map<String, dynamic> listData;
  const _ListSearchTile({required this.listData});

  @override
  Widget build(BuildContext context) {
    final covers = (listData['covers'] as List<dynamic>?) ?? [];
    final title = listData['title']?.toString() ?? 'List';
    final owner = listData['owner_username']?.toString() ?? 'user';
    final count = listData['cafe_count']?.toString() ?? '0';
    
    return ListTile(
      leading: _buildCollage(covers),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('oleh @$owner • $count cafe', style: const TextStyle(fontSize: 12)),
      onTap: () {
        final listId = listData['id']?.toString();
        if (listId == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ListDetailPage(listId: listId)),
        );
      },
    );
  }

  Widget _buildCollage(List<dynamic> covers) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: covers.isEmpty
          ? const Icon(Icons.list, color: Colors.grey)
          : covers.length == 1
              ? Image.network(covers[0].toString(), fit: BoxFit.cover)
              : GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 1,
                  ),
                  itemCount: covers.length > 4 ? 4 : covers.length,
                  itemBuilder: (context, i) => Image.network(covers[i].toString(), fit: BoxFit.cover),
                ),
    );
  }
}
