import 'package:flutter/material.dart';
import '../../core/theme.dart';

class CreateListPage extends StatelessWidget {
  const CreateListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New List')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_add, size: 64, color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Layar Create/Edit List (S-17) belum dibikin 🚧\n'
                'Nanti di sini ada form: judul, deskripsi, toggle public/private, tambah cafe.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}