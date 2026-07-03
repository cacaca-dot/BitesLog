import 'package:flutter/material.dart';
import '../../core/theme.dart';

class VisitDetailPlaceholder extends StatelessWidget {
  final String cafeName;
  final String userName;
  const VisitDetailPlaceholder({
    super.key,
    required this.cafeName,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Detail Kunjungan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_cafe, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                cafeName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('Kunjungan oleh $userName',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              const Text(
                'Halaman Visit Detail (S-12) masih dikerjakan Dev A 🚧\n'
                'Nanti di sini ada foto, review lengkap, dan komentar.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}