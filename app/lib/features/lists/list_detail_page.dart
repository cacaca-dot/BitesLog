import 'package:flutter/material.dart';
import '../../core/theme.dart';

class ListDetailPage extends StatelessWidget {
  final String listTitle;
  const ListDetailPage({super.key, required this.listTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(listTitle)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.list_alt, size: 64, color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Layar List Detail (S-16) belum dibikin 🚧\n'
                'Nanti di sini ada daftar cafe di dalam list ini.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}