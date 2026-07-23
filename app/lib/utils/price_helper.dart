class PriceHelper {
  static String getPriceLabel(String? priceRange) {
    switch (priceRange) {
      case r'$':
        return '< Rp25rb';
      case r'$$':
        return 'Rp25–75rb';
      case r'$$$':
        return 'Rp75–150rb';
      case r'$$$$':
        return '> Rp150rb';
      default:
        return 'Harga tidak diketahui';
    }
  }

  static const List<String> availableRanges = [r'$', r'$$', r'$$$', r'$$$$'];
}
