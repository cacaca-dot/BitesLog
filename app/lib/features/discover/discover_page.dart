import 'package:flutter/material.dart';
import '../../core/theme.dart';

// ---- Model dummy ----
class Cafe {
  final String name;
  final String category;
  final String imageUrl;
  final double rating; // 0 - 5

  const Cafe({
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.rating,
  });
}

// ---- Data dummy (nanti diganti data dari server) ----
const _popular = <Cafe>[
  Cafe(name: 'Kopi Senja', category: 'Coffee', rating: 4.5,
      imageUrl: 'https://images.unsplash.com/photo-1445116572660-236099ec97a0?w=400'),
  Cafe(name: 'Matcha House', category: 'Matcha', rating: 5.0,
      imageUrl: 'https://images.unsplash.com/photo-1515823662972-da6a2e4d3002?w=400'),
  Cafe(name: 'Roti & Co', category: 'Bakery', rating: 4.0,
      imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400'),
];

const _matcha = <Cafe>[
  Cafe(name: 'Ippudo Matcha', category: 'Matcha', rating: 4.5,
      imageUrl: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?w=400'),
  Cafe(name: 'Greenery', category: 'Matcha', rating: 4.0,
      imageUrl: 'https://images.unsplash.com/photo-1464347601390-9a9e0b96d5f?w=400'),
  Cafe(name: 'Zen Cup', category: 'Matcha', rating: 5.0,
      imageUrl: 'https://images.unsplash.com/photo-1515442261605-65987783cb6a?w=400'),
];

const _followed = <Cafe>[
  Cafe(name: 'Brew Bros', category: 'Coffee', rating: 4.5,
      imageUrl: 'https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=400'),
  Cafe(name: 'Sunny Side', category: 'Brunch', rating: 4.0,
      imageUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=400'),
];

const _catalog = <Cafe>[
  ..._popular, ..._matcha, ..._followed,
];

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Discover',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            ),
            const _SearchBar(),
            const _RowSection(title: 'Popular this week', cafes: _popular),
            const _RowSection(title: 'Because you like matcha', cafes: _matcha),
            const _RowSection(title: 'Loved by people you follow', cafes: _followed),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('Browse catalog',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const _CatalogGrid(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---- Search bar (dummy, belum berfungsi) ----
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Cari cafe...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ---- Baris tema (horizontal) ----
class _RowSection extends StatelessWidget {
  final String title;
  final List<Cafe> cafes;
  const _RowSection({required this.title, required this.cafes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cafes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _CafeCard(cafe: cafes[i], width: 160),
          ),
        ),
      ],
    );
  }
}

// ---- Grid katalog ----
class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _catalog.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (_, i) => _CafeCard(cafe: _catalog[i]),
    );
  }
}

// ---- Kartu cafe (dipakai baris & grid) ----
class _CafeCard extends StatelessWidget {
  final Cafe cafe;
  final double? width;
  const _CafeCard({required this.cafe, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.network(
              cafe.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.accent,
                child: const Icon(Icons.local_cafe, color: Colors.white),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cafe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                _StarRow(rating: cafe.rating),
                const SizedBox(height: 6),
                _CategoryChip(label: cafe.category),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Bintang setengah ----
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
        return Icon(icon, size: 16, color: AppColors.primary);
      }),
    );
  }
}

// ---- Chip kategori ----
class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.text)),
    );
  }
}