import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../shell/main_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Colors based on the UI design
  static const Color bgColor = Color(0xFFFFF7F9);
  static const Color fieldBgColor = Color(0xFFFCF0F5);
  static const Color labelColor = Color(0xFF5D5154);
  static const Color textColor = Color(0xFF2D2230);
  // Using AppColors.primary for button/logo to match the main app theme
  static const Color primaryColor = AppColors.primary;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      if (_isLogin) {
        final result = await ApiService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if ((result['status'] as String?) == 'success') {
          final data = result['data'] as Map<String, dynamic>?;
          final token = data?['token'] as String?;
          final user = data?['user'] as Map<String, dynamic>?;
          
          if (token != null && user != null) {
            await AuthService.saveToken(
              token, 
              user['username']?.toString() ?? '', 
              user['id']?.toString() ?? ''
            );
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainShell()),
            );
          }
        } else {
          _showMessage(result['error']?['message'] ?? 'Login gagal');
        }
      } else {
        final result = await ApiService.register({
          'full_name': _fullNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'confirm_password': _confirmPasswordController.text,
        });
        if ((result['status'] as String?) == 'success') {
          _showMessage('Akun berhasil dibuat. Silakan login.');
          setState(() => _isLogin = true);
        } else {
          _showMessage(result['error']?['message'] ?? 'Registrasi gagal');
        }
      }
    } catch (e) {
      _showMessage('Tidak dapat terhubung ke server');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Handle
            Positioned(
              right: -6,
              child: Container(
                width: 14,
                height: 18,
                decoration: BoxDecoration(
                  border: Border.all(color: primaryColor, width: 2.5),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
              ),
            ),
            // Cup body
            Container(
              width: 30,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border.all(color: primaryColor, width: 2.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            // String (Tea bag string)
            Positioned(
              top: -6,
              child: Container(
                width: 2.5,
                height: 8,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // String knot
            Positioned(
              top: -8,
              child: Container(
                width: 6,
                height: 4,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )
          ],
        ),
        const SizedBox(width: 16),
        const Text(
          'BitesLog',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: labelColor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: labelColor, fontSize: 16),
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: labelColor.withOpacity(0.5), fontSize: 16),
            filled: true,
            fillColor: fieldBgColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: labelColor,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 40),
                
                Text(
                  _isLogin 
                    ? 'Welcome back to your\ncafe journal'
                    : 'Create your\ncafe journal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 40),
                
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: primaryColor.withOpacity(0.03),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_isLogin) ...[
                          _buildTextField(
                            label: 'Full Name',
                            controller: _fullNameController,
                            hintText: 'John Doe',
                            validator: (v) => (v == null || v.trim().length < 2) ? 'Minimal 2 karakter' : null,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            label: 'Username',
                            controller: _usernameController,
                            hintText: 'johndoe',
                            validator: (v) => (v == null || !RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(v)) ? 'Username tidak valid' : null,
                          ),
                          const SizedBox(height: 20),
                        ],
                        
                        _buildTextField(
                          label: _isLogin ? 'Email or Username' : 'Email',
                          controller: _emailController,
                          hintText: 'hello@example.com',
                          keyboardType: _isLogin ? TextInputType.text : TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                            if (!_isLogin && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
                              return 'Email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        _buildTextField(
                          label: 'Password',
                          controller: _passwordController,
                          isPassword: true,
                          obscureText: _obscurePassword,
                          onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                          validator: (v) => (v == null || v.length < 8) ? 'Password minimal 8 karakter' : null,
                        ),
                        
                        if (!_isLogin) ...[
                          const SizedBox(height: 20),
                          _buildTextField(
                            label: 'Confirm Password',
                            controller: _confirmPasswordController,
                            isPassword: true,
                            obscureText: _obscureConfirmPassword,
                            onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            validator: (v) => (v == null || v != _passwordController.text) ? 'Password tidak sama' : null,
                          ),
                        ],
                        
                        // Per request: "gak usah ada forgot password"
                        // Therefore, skipping the Forgot Password link entirely.
                        
                        const SizedBox(height: 32),
                        
                        ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _loading 
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
                              : Text(
                                  _isLogin ? 'Log in' : 'Sign up',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin ? "Don't have an account?" : "Already have an account?",
                      style: const TextStyle(color: labelColor, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _formKey.currentState?.reset();
                        });
                      },
                      child: Text(
                        _isLogin ? "Sign up" : "Log in",
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
