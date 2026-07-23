class Cafe {
  final String id;
  final String name;
  final List<String> categories;
  final String? area;
  final String city;
  final String? address;
  final String? priceRange;
  final String imageUrl;
  final double rating;
  final int visitCount;

  const Cafe({
    required this.id,
    required this.name,
    required this.categories,
    this.area,
    required this.city,
    this.address,
    this.priceRange,
    required this.imageUrl,
    required this.rating,
    required this.visitCount,
  });

  factory Cafe.fromJson(Map<String, dynamic> json) {
    return Cafe(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown Cafe',
      categories: (json['categories'] as List?)?.map((e) => e.toString()).toList() ?? [],
      area: json['area'] as String?,
      city: json['city'] as String? ?? 'Unknown City',
      address: json['address'] as String?,
      priceRange: json['price_range'] as String?,
      imageUrl: json['image_url'] as String? ?? 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400',
      rating: (json['avg_rating'] != null) ? double.parse(json['avg_rating'].toString()) : 0.0,
      visitCount: json['visit_count'] as int? ?? 0,
    );
  }
}
