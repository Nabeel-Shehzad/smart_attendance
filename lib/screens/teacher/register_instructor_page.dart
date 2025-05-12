import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:smart_attendance/providers/auth_provider.dart';

class RegisterInstructorPage extends StatefulWidget {
  const RegisterInstructorPage({super.key});

  @override
  State<RegisterInstructorPage> createState() => _RegisterInstructorPageState();
}

class _RegisterInstructorPageState extends State<RegisterInstructorPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _facultyIdController = TextEditingController();
  final _departmentController = TextEditingController();
  
  // Initialize animation controller and animations with default values
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation = const AlwaysStoppedAnimation(1.0);
  late Animation<Offset> _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(const AlwaysStoppedAnimation(0));
  
  List<String> _departments = [
    'Computer Science',
    'Engineering',
    'Business Administration',
    'Mathematics',
    'English',
    'Physics',
    'Chemistry',
    'Biology',
    'Others'
  ];
  String? _selectedDepartment;
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }
  
  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _animationsInitialized = true;
    if (mounted) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _facultyIdController.dispose();
    _departmentController.dispose();
    if (_animationsInitialized) {
      _animationController.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Add haptic feedback
    HapticFeedback.mediumImpact();
    
    try {
      await context.read<AuthProvider>().registerInstructor(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        facultyId: _facultyIdController.text.trim(),
        department: _selectedDepartment ?? _departmentController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Registration successful!', style: GoogleFonts.poppins()),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
          ),
        );
        Navigator.pop(context); // Return to login page
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.toString(), style: GoogleFonts.poppins())),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // If animations are not initialized yet, return a loading indicator
    if (!_animationsInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative background elements
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                height: 180,
                width: 180,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(90),
                ),
              ),
            ),
            Positioned(
              bottom: screenHeight * 0.6,
              left: -60,
              child: Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                ),
              ),
            ),
            
            // Main content
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 180,
                  floating: false,
                  pinned: true,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor,
                            const Color(0xFF5C6BC0),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Abstract shapes for background detail
                          Positioned(
                            top: 20,
                            left: 20,
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 30,
                            right: 40,
                            child: Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                          
                          // Main header content
                          Center(
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.person_rounded,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Instructor Registration',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Account',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Complete your profile to get started',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Personal Information',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    _buildTextField(
                                      controller: _fullNameController,
                                      label: 'Full Name',
                                      hint: 'Enter your full name',
                                      icon: Icons.person_outline_rounded,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your name';
                                        }
                                        return null;
                                      },
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    _buildTextField(
                                      controller: _facultyIdController,
                                      label: 'Faculty ID',
                                      hint: 'Enter your faculty ID',
                                      icon: Icons.badge_outlined,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your faculty ID';
                                        }
                                        return null;
                                      },
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Department',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedDepartment,
                                              isExpanded: true,
                                              hint: Text(
                                                'Select your department',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: Colors.grey[400],
                                                ),
                                              ),
                                              icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                                              items: _departments.map((String department) {
                                                return DropdownMenuItem<String>(
                                                  value: department,
                                                  child: Text(
                                                    department,
                                                    style: GoogleFonts.poppins(fontSize: 15),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedDepartment = value;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        if (_selectedDepartment == 'Others')
                                          Padding(
                                            padding: const EdgeInsets.only(top: 16),
                                            child: _buildTextField(
                                              controller: _departmentController,
                                              label: 'Specify Department',
                                              hint: 'Enter your department',
                                              icon: Icons.business_outlined,
                                              validator: (value) {
                                                if (_selectedDepartment == 'Others' && (value == null || value.isEmpty)) {
                                                  return 'Please specify your department';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Account Information',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    _buildTextField(
                                      controller: _emailController,
                                      label: 'Email',
                                      hint: 'Enter your email address',
                                      icon: Icons.email_rounded,
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
                                    
                                    const SizedBox(height: 20),
                                    
                                    _buildTextField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      hint: 'Enter your password',
                                      icon: Icons.lock_rounded,
                                      isPassword: true,
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
                                    ),
                                    
                                    const SizedBox(height: 8),
                                    
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Password must be at least 8 characters with uppercase, lowercase, number, and special character',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 40),
                              
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: authProvider.isLoading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    disabledBackgroundColor: Colors.transparent,
                                    disabledForegroundColor: Colors.white60,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: authProvider.isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Create Account',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                                          ],
                                        ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account? ',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pop(context);
                                      },
                                      child: Text(
                                        'Sign In',
                                        style: GoogleFonts.poppins(
                                          color: primaryColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            prefixIcon: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.grey[600],
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            errorStyle: GoogleFonts.poppins(
              fontSize: 12,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}