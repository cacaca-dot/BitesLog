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
    String? rawAddress = json['address'] as String?;
    String? rawArea = json['area'] as String?;
    String? rawCity = json['city'] as String?;

    if (rawAddress != null && rawAddress.isNotEmpty) {
      if (rawArea == null || rawArea.isEmpty || rawArea == 'Unknown Area') {
        final kecMatch = RegExp(r'Kecamatan\s+([A-Za-z\s]+)(?:,|$)').firstMatch(rawAddress);
        if (kecMatch != null) rawArea = kecMatch.group(1)!.trim();
      }
      if (rawCity == null || rawCity.isEmpty || rawCity == 'Unknown City') {
        final kotaMatch = RegExp(r'(Kota|Kabupaten)\s+([A-Za-z\s]+)(?:,|$)').firstMatch(rawAddress);
        if (kotaMatch != null) rawCity = '${kotaMatch.group(1)} ${kotaMatch.group(2)!.trim()}';
      }
    }

    return Cafe(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown Cafe',
      categories: (json['categories'] as List?)?.map((e) => e.toString()).toList() ?? [],
      area: rawArea,
      city: rawCity ?? 'Unknown City',
      address: rawAddress,
      priceRange: json['price_range'] as String?,
      imageUrl: json['image_url'] as String? ?? 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400',
      rating: (json['avg_rating'] != null) ? double.tryParse(json['avg_rating'].toString()) ?? 0.0 : ((json['rating'] != null) ? double.tryParse(json['rating'].toString()) ?? 0.0 : 0.0),
      visitCount: json['visit_count'] as int? ?? 0,
    );
  }
}
