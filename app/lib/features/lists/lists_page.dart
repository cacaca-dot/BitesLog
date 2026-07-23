import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import 'create_edit_list_page.dart';
import 'list_detail_page.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({super.key});

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  final GlobalKey<_MyListsTabState> _myListsKey = GlobalKey();
  final GlobalKey<_SavedListsTabState> _savedListsKey = GlobalKey();

  Future<void> _openCreateList(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateEditListPage()),
    );
    if (result == true) {
      _myListsKey.currentState?.fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lists', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
          actions: [
            TextButton.icon(
              onPressed: () => _openCreateList(context),
              icon: const Icon(Icons.add, color: AppColors.primary),
              label: const Text('Buat List', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'List Saya'),
              Tab(text: 'Tersimpan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MyListsTab(key: _myListsKey, onCreateList: () => _openCreateList(context)),
            _SavedListsTab(key: _savedListsKey),
          ],
        ),
      ),
    );
  }
}

class _MyListsTab extends StatefulWidget {
  final VoidCallback onCreateList;
  const _MyListsTab({super.key, required this.onCreateList});
  
  @override
  State<_MyListsTab> createState() => _MyListsTabState();
}

class _MyListsTabState extends State<_MyListsTab> {
  List<dynamic> _lists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    fetch();
  }

  Future<void> fetch() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getMyLists();
      if (mounted) setState(() { _lists = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.format_list_bulleted, size: 64, color: AppColors.secondary),
            const SizedBox(height: 16),
            const Text(
              'Belum ada list.\nBuat koleksi kafe favoritmu!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onCreateList,
              icon: const Icon(Icons.add),
              label: const Text('Buat List'),
            )
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetch,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _lists.length,
        itemBuilder: (context, index) {
          final list = _lists[index];
          return ListCard(list: list, onRefresh: fetch);
        },
      ),
    );
  }
}

class _SavedListsTab extends StatefulWidget {
  const _SavedListsTab({super.key});
  @override
  State<_SavedListsTab> createState() => _SavedListsTabState();
}

class _SavedListsTabState extends State<_SavedListsTab> {
  List<dynamic> _lists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    fetch();
  }

  Future<void> fetch() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getSavedLists();
      if (mounted) setState(() { _lists = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_lists.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: AppColors.secondary),
            SizedBox(height: 16),
            Text(
              'Belum ada list tersimpan.',
              style: TextStyle(color: AppColors.secondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetch,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _lists.length,
        itemBuilder: (context, index) {
          final list = _lists[index];
          return ListCard(list: list, onRefresh: fetch);
        },
      ),
    );
  }
}

class ListCard extends StatelessWidget {
  final Map<String, dynamic> list;
  final VoidCallback onRefresh;

  const ListCard({super.key, required this.list, required this.onRefresh});

  Widget _buildCollageSlot(String emoji, double fontSize) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.accent, // fallback if gradient not used
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: fontSize)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black12,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.card,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ListDetailPage(listId: list['id'])),
          );
          if (result == true) onRefresh();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // COVER COLLAGE
            SizedBox(
              height: 140,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildCollageSlot('☕', 48),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildCollageSlot('🍵', 24)),
                        const SizedBox(height: 2),
                        Expanded(child: _buildCollageSlot('🥐', 24)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // CONTENT
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          list['title'] ?? 'Untitled', 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // BADGE PUBLIC/PRIVATE
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          list['is_public'] == true ? 'PUBLIC' : 'PRIVATE',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // META ROW
                  Row(
                    children: [
                      const Icon(Icons.restaurant, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Text('${list['cafe_count'] ?? 0} cafes', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 16),
                      const Icon(Icons.favorite, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Text('${list['like_count'] ?? 0} likes', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
