import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../shell/main_shell.dart';
import 'auth_screen.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });

    final stopwatch = Stopwatch()..start();
    
    try {
      final isLoggedIn = await AuthService.isLoggedIn();

      if (isLoggedIn) {
        // Verifikasi token/session valid dengan timeout 10 detik
        await ApiService.getMyProfile().timeout(const Duration(seconds: 10));
        await _ensureMinimumDuration(stopwatch, 1500);
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainShell()),
          );
        }
      } else {
        await _ensureMinimumDuration(stopwatch, 1500);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
          );
        }
      }
    } catch (e) {
      // 401 sudah di-handle oleh _check401 di ApiService (otomatis logout & route ke Login)
      // Jadi exception yang masuk ke sini adalah Network Error atau Timeout
      final errorMsg = e is TimeoutException 
          ? 'Koneksi ke server timeout'
          : 'Gagal konek ke server';

      await _ensureMinimumDuration(stopwatch, 1500);
      if (mounted) {
        // Karena ini exception selain 401 (atau 401 yg ter-throw setelah route), 
        // pastikan token tidak dihapus, kasih opsi Coba Lagi.
        // Jika e.toString() mengandung 'Sesi berakhir', maka navigator otomatis jalan dari ApiService.
        // Namun kita tangkap saja semuanya yang tersisa.
        if (e.toString().contains('Sesi berakhir')) {
           // Sudah dihandle oleh ApiService _check401
           return;
        }

        setState(() {
          _hasError = true;
          _errorMessage = errorMsg;
        });
      }
    }
  }

  Future<void> _ensureMinimumDuration(Stopwatch stopwatch, int minMs) async {
    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < minMs) {
      await Future.delayed(Duration(milliseconds: minMs - elapsed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: _hasError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(_errorMessage, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _checkSession,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'BitesLog',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ],
              ),
      ),
    );
  }
}
