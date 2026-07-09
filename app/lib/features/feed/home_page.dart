import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../visit/visit_detail_placeholder.dart';

// ---- Model dummy ----
class FeedItem {
  final String userName;
  final String avatarLetter;
  final String timeAgo;
  final String cafeName;
  final double rating;
  final String reviewText;
  final String photoUrl;
  final int likes;
  final int comments;

  const FeedItem({
    required this.userName,
    required this.avatarLetter,
    required this.timeAgo,
    required this.cafeName,
    required this.rating,
    required this.reviewText,
    required this.photoUrl,
    required this.likes,
    required this.comments,
  });
}

const _feed = <FeedItem>[
  FeedItem(
    userName: 'Alex J.',
    avatarLetter: 'A',
    timeAgo: '2H AGO',
    cafeName: 'The Daily Grind',
    rating: 4.5,
    reviewText:
        'The oat milk latte here is consistently smooth. Perfect atmosphere for a morning deep-work session. Love the minimal jazz playlist. ☕✨',
    photoUrl:
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600',
    likes: 12,
    comments: 4,
  ),
  FeedItem(
    userName: 'Sarah M.',
    avatarLetter: 'S',
    timeAgo: '5H AGO',
    cafeName: 'Matcha House',
    rating: 5.0,
    reviewText:
        'Best ceremonial matcha in town! The latte art is beautiful and the space is so calming. 🍵',
    photoUrl:
        'https://images.unsplash.com/photo-1515823662972-da6a2e4d3002?w=600',
    likes: 28,
    comments: 7,
  ),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _feed.length,
        itemBuilder: (_, i) => _FeedCard(item: _feed[i]),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final FeedItem item;
  const _FeedCard({required this.item});

  // Buka halaman detail (sementara)
  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitDetailPlaceholder(
          cafeName: item.cafeName,
          userName: item.userName,
        ),
      ),
    );
  }

  // Aksi menu titik tiga
  void _onMenu(BuildContext context, String value) {
    final label = {
      'save': 'Disimpan',
      'share': 'Dibagikan',
      'report': 'Dilaporkan',
      'hide': 'Disembunyikan',
    }[value]!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label: ${item.cafeName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context), // 👈 kartu bisa diklik
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Header: avatar, nama, waktu, titik tiga ----
              Row(
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
                  // 👇 titik tiga sekarang jadi menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (v) => _onMenu(context, v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'save',
                        child: ListTile(
                          leading: Icon(Icons.bookmark_border),
                          title: Text('Simpan'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: ListTile(
                          leading: Icon(Icons.share_outlined),
                          title: Text('Bagikan'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'report',
                        child: ListTile(
                          leading: Icon(Icons.flag_outlined),
                          title: Text('Laporkan'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'hide',
                        child: ListTile(
                          leading: Icon(Icons.visibility_off_outlined),
                          title: Text('Sembunyikan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ---- Nama cafe ----
              Row(
                children: [
                  Icon(Icons.place, size: 18, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(item.cafeName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 6),
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
              Text(item.reviewText, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 12),
              // ---- Foto ----
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    item.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.accent,
                      child: const Icon(Icons.local_cafe,
                          color: Colors.white, size: 40),
                    ),
                  ),
                ),
              ),
              const Divider(height: 24),
              // ---- Like & komentar ----
              Row(
                children: [
                  const Icon(Icons.favorite_border, size: 20),
                  const SizedBox(width: 4),
                  Text('${item.likes}'),
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