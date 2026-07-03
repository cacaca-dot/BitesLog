import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'list_detail_page.dart';
import 'create_list_page.dart';

// ---- Model dummy ----
class CafeList {
  final String title;
  final List<String> coverPhotos;
  final int cafeCount;
  final int likeCount;
  final bool isPublic;

  const CafeList({
    required this.title,
    required this.coverPhotos,
    required this.cafeCount,
    required this.likeCount,
    required this.isPublic,
  });
}

const _photoA =
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=300';
const _photoB =
    'https://images.unsplash.com/photo-1515823662972-da6a2e4d3002?w=300';
const _photoC =
    'https://images.unsplash.com/photo-1442512595331-e89e73853f31?w=300';
const _photoD =
    'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=300';

// Data dummy: list punya sendiri
const _myLists = <CafeList>[
  CafeList(
    title: 'Cafe Matcha Terbaik Jakarta',
    coverPhotos: [_photoB, _photoA, _photoC],
    cafeCount: 12,
    likeCount: 48,
    isPublic: true,
  ),
  CafeList(
    title: 'Spot WFC Cozy',
    coverPhotos: [_photoA, _photoC],
    cafeCount: 7,
    likeCount: 15,
    isPublic: true,
  ),
  CafeList(
    title: 'Wishlist Pribadi',
    coverPhotos: [_photoD],
    cafeCount: 3,
    likeCount: 0,
    isPublic: false,
  ),
];

// Data dummy: list yang disimpan dari orang lain
const _savedLists = <CafeList>[
  CafeList(
    title: 'Hidden Gems Bandung',
    coverPhotos: [_photoC, _photoD, _photoA],
    cafeCount: 20,
    likeCount: 132,
    isPublic: true,
  ),
  CafeList(
    title: 'Cafe Buka 24 Jam',
    coverPhotos: [_photoA, _photoB],
    cafeCount: 9,
    likeCount: 67,
    isPublic: true,
  ),
];

class ListsPage extends StatelessWidget {
  const ListsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Lists',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'My lists'),
              Tab(text: 'Saved'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ListGrid(
              lists: _myLists,
              emptyText: 'Belum ada list. Bikin yang pertama! ✨',
            ),
            _ListGrid(
              lists: _savedLists,
              emptyText: 'Belum ada list yang kamu simpan.',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New list'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateListPage()),
            );
          },
        ),
      ),
    );
  }
}

class _ListGrid extends StatelessWidget {
  final List<CafeList> lists;
  final String emptyText;
  const _ListGrid({required this.lists, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) {
      return Center(
        child: Text(emptyText, style: const TextStyle(color: Colors.grey)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: lists.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => _ListCard(list: lists[i]),
    );
  }
}

class _ListCard extends StatelessWidget {
  final CafeList list;
  const _ListCard({required this.list});

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ListDetailPage(listTitle: list.title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Cover collage + badge public/private ----
            Stack(
              children: [
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: _CoverCollage(photos: list.coverPhotos),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _Badge(isPublic: list.isPublic),
                ),
              ],
            ),
            // ---- Info: judul, jumlah cafe, jumlah like ----
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_cafe_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${list.cafeCount} cafe',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.favorite,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${list.likeCount}',
                        style: const TextStyle(color: Colors.grey),
                      ),
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

// Kolase cover: susun 1–3 foto cafe jadi 1 gambar sampul
class _CoverCollage extends StatelessWidget {
  final List<String> photos;
  const _CoverCollage({required this.photos});

  Widget _img(String url) => Image.network(
    url,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Container(
      color: AppColors.accent,
      child: const Icon(Icons.local_cafe, color: Colors.white),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Container(
        color: AppColors.accent,
        child: const Icon(
          Icons.photo_library_outlined,
          color: Colors.white,
          size: 40,
        ),
      );
    }
    if (photos.length == 1) {
      return _img(photos[0]);
    }
    // 2+ foto: kiri besar, kanan tumpukan
    return Row(
      children: [
        Expanded(flex: 2, child: _img(photos[0])),
        const SizedBox(width: 2),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(child: _img(photos[1])),
              if (photos.length > 2) ...[
                const SizedBox(height: 2),
                Expanded(child: _img(photos[2])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Badge public / private
class _Badge extends StatelessWidget {
  final bool isPublic;
  const _Badge({required this.isPublic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public : Icons.lock,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isPublic ? 'Public' : 'Private',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
