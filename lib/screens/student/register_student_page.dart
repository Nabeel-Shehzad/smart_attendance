import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_attendance/providers/auth_provider.dart';

class RegisterStudentPage extends StatefulWidget {
  const RegisterStudentPage({super.key});

  @override
  State<RegisterStudentPage> createState() => _RegisterStudentPageState();
}

class _RegisterStudentPageState extends State<RegisterStudentPage> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().registerStudent(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        studentId: _studentIdController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registration successful! Please log in.'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context); // Return to login page
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: colorScheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Student Registration',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -50,
                      top: -50,
                      child: CircleAvatar(
                        radius: 100,
                        backgroundColor: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Account',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Sign up to start your academic journey',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildRegistrationForm(colorScheme),
                    const SizedBox(height: 24),
                    _buildSignInOption(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationForm(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildInputField(
              controller: _fullNameController,
              icon: Icons.person_rounded,
              label: 'Full Name',
              hint: 'Enter your full name',
              colorScheme: colorScheme,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _studentIdController,
              icon: Icons.badge_rounded,
              label: 'Student ID',
              hint: 'Enter your student ID',
              colorScheme: colorScheme,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your student ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _emailController,
              icon: Icons.email_rounded,
              label: 'Email',
              hint: 'Enter your email address',
              colorScheme: colorScheme,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(colorScheme),
            const SizedBox(height: 32),
            _buildRegisterButton(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    required ColorScheme colorScheme,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
        hintStyle: GoogleFonts.poppins(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: Icon(
          icon,
          color: colorScheme.primary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade300, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      style: GoogleFonts.poppins(),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildPasswordField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
        hintStyle: GoogleFonts.poppins(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: Icon(
          Icons.lock_rounded,
          color: colorScheme.primary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.grey[600],
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade300, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      style: GoogleFonts.poppins(),
      obscureText: _obscurePassword,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a password';
        }
        if (value.length < 8) {
          return 'Password must be at least 8 characters';
        }
        if (!RegExp(r'[A-Z]').hasMatch(value)) {
          return 'Password must contain at least one uppercase letter';
        }
        if (!RegExp(r'[a-z]').hasMatch(value)) {
          return 'Password must contain at least one lowercase letter';
        }
        if (!RegExp(r'[0-9]').hasMatch(value)) {
          return 'Password must contain at least one number';
        }
        if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
          return 'Password must contain at least one special character';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Register',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildSignInOption(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account?',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Sign In',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
