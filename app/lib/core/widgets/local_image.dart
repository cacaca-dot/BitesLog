import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/local_repository.dart';

class LocalImageProvider {
  static ImageProvider getProvider(String? url) {
    if (url == null || url.isEmpty) {
      return const AssetImage('assets/placeholder.png'); // fallback
    }
    if (url.startsWith('http') || url.startsWith('data:')) {
      return NetworkImage(url);
    }
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    // Asumsikan path sudah absolut jika mengandung slash, atau butuh getFullImagePath
    if (url.contains('/')) {
      return FileImage(File(url));
    }
    // Jika tidak, kita harus me-resolve secara asynchronous (tidak bisa langsung di Provider synchronous).
    // Tapi karena widget yang butuh, kita pakai helper Widget saja untuk amannya.
    return FileImage(File(url)); // Placeholder, should use LocalImageBuilder
  }
}

class LocalImage extends StatefulWidget {
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const LocalImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<LocalImage> createState() => _LocalImageState();
}

class _LocalImageState extends State<LocalImage> {
  String? _resolvedPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolvePath();
  }

  @override
  void didUpdateWidget(covariant LocalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolvePath();
    }
  }

  Future<void> _resolvePath() async {
    if (widget.url == null || widget.url!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _resolvedPath = null;
        });
      }
      return;
    }
    
    if (widget.url!.startsWith('http') || widget.url!.startsWith('data:') || widget.url!.contains('/')) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _resolvedPath = widget.url;
        });
      }
      return;
    }
    
    final path = await LocalRepository.getFullImagePath(widget.url!);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _resolvedPath = path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder ?? const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_resolvedPath == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorWidget ?? const Icon(Icons.image_not_supported),
      );
    }
    
    if (_resolvedPath!.startsWith('http') || _resolvedPath!.startsWith('data:')) {
      return Image.network(
        _resolvedPath!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => widget.errorWidget ?? const Icon(Icons.broken_image),
      );
    }
    
    if (_resolvedPath!.startsWith('assets/')) {
      return Image.asset(
        _resolvedPath!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => widget.errorWidget ?? const Icon(Icons.broken_image),
      );
    }
    
    return Image.file(
      File(_resolvedPath!),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) => widget.errorWidget ?? const Icon(Icons.broken_image),
    );
  }
}
