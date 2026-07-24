import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets/local_image.dart';
import '../../services/api_service.dart';
import 'create_edit_list_page.dart';
import 'list_detail_page.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({super.key});

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
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

  Future<void> _openCreateList(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateEditListPage()),
    );
    if (result == true) {
      fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton.icon(
            onPressed: () => _openCreateList(context),
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text('Buat List', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
              'Belum ada daftar.\nBuat koleksi kafe favoritmu!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openCreateList(context),
              icon: const Icon(Icons.add),
              label: const Text('Buat Daftar'),
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

class ListCard extends StatelessWidget {
  final Map<String, dynamic> list;
  final VoidCallback onRefresh;

  const ListCard({super.key, required this.list, required this.onRefresh});

  Widget _buildFallbackTile() {
    return Container(
      color: AppColors.primary.withOpacity(0.8),
      child: const Center(
        child: Icon(Icons.coffee, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildImageTile(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildFallbackTile();
    }
    return LocalImage(
      imageUrl,
      fit: BoxFit.cover,
      errorWidget: _buildFallbackTile(),
      placeholder: Container(
        color: AppColors.accent.withOpacity(0.3),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: AppColors.accent.withOpacity(0.1),
      child: const Center(
        child: Icon(Icons.bookmark_outline, size: 48, color: Colors.grey),
      ),
    );
  }

  Widget _buildMosaic(List<dynamic> covers, int cafeCount) {
    if (cafeCount == 0) return _buildEmptyState();

    final int tileCount = cafeCount > 4 ? 4 : cafeCount;
    
    String? getCover(int index) {
      if (index < covers.length) return covers[index]?.toString();
      return null;
    }

    if (tileCount == 1) {
      return _buildImageTile(getCover(0));
    } else if (tileCount == 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildImageTile(getCover(0))),
          const SizedBox(width: 2),
          Expanded(child: _buildImageTile(getCover(1))),
        ],
      );
    } else if (tileCount == 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: _buildImageTile(getCover(0))),
          const SizedBox(width: 2),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildImageTile(getCover(1))),
                const SizedBox(height: 2),
                Expanded(child: _buildImageTile(getCover(2))),
              ],
            ),
          ),
        ],
      );
    } else { // 4+
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildImageTile(getCover(0))),
                const SizedBox(width: 2),
                Expanded(child: _buildImageTile(getCover(1))),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildImageTile(getCover(2))),
                const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImageTile(getCover(3)),
                      if (cafeCount > 4)
                        Container(
                          color: Colors.black45,
                          child: Center(
                            child: Text(
                              '+${cafeCount - 4}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int cafeCount = int.tryParse(list['cafe_count']?.toString() ?? '0') ?? 0;
    final List<dynamic> covers = list['covers'] ?? [];

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
            MaterialPageRoute(builder: (_) => ListDetailPage(listId: list['id'].toString())),
          );
          if (result == true) onRefresh();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // COVER COLLAGE
            SizedBox(
              height: 140,
              child: (list['cover_image'] != null && list['cover_image'].toString().isNotEmpty)
                  ? LocalImage(list['cover_image'], fit: BoxFit.cover, width: double.infinity)
                  : _buildMosaic(covers, cafeCount),
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  // META ROW
                  Row(
                    children: [
                      const Icon(Icons.restaurant, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Text('${list['cafe_count'] ?? 0} cafes', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
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
