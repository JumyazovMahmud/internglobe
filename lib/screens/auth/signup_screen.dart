import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../profile_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final ref = FirebaseDatabase.instance.ref('users/${cred.user!.uid}');
      await ref.set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'age': 0,
        'education': '',
        'favorites': ['', '', '', '', ''],
        'profilePic': '',
        'applications': [],
        'createdAt': ServerValue.timestamp,
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen(forceComplete: true)),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Check your connection';
          break;
        default:
          errorMessage = e.message ?? 'Signup failed';
      }
      if (mounted) setState(() => _error = errorMessage);
    } catch (e) {
      if (mounted)
        setState(() => _error = 'An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top gradient header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 70, 24, 48),
              child: Column(
                children: [
                  // Back button row
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Logo
                  Image.asset('assets/internglobe_logo.png', width: 90, height: 90),
                  const SizedBox(height: 20),
                  const Text(
                    'Join InternGlobe!',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign up to find internships worldwide',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Form section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fill in the details to get started',
                      style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),

                    // Name field
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter your name';
                        if (value.length < 2)
                          return 'Name must be at least 2 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email field
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter your email';
                        if (!value.contains('@') || !value.contains('.'))
                          return 'Please enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signup(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey[600],
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter a password';
                        if (value.length < 6)
                          return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),

                    // Error message
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Sign up button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Text(
                          'Sign Up',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account? ',
                            style: TextStyle(color: Colors.grey[600])),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? suffixIcon,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue[700]),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}