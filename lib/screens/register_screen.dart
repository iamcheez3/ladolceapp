import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const Color _brandNavy = Color(0xFF0D1565);
  static const Color _brandNavy2 = Color(0xFF142B8C);
  static const Color _brandSurface = Color(0xFFF6F7FB);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedRole = 'customer'; // Default role
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.registerUser(
        name: _nameController.text,
        login: _loginController.text,
        password: _passwordController.text,
        role: _selectedRole,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      );

      if (!mounted) return;
      
      // Show success and pop back to login
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Registration successful'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context); // Go back to login screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration Failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_brandNavy, _brandNavy2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  decoration: BoxDecoration(
                    color: _brandSurface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 20,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded),
                              color: _brandNavy,
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: _brandNavy,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              alignment: Alignment.center,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/ladolce_bear_logo.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) {
                                    return const Icon(
                                      Icons.pets_rounded,
                                      size: 48,
                                      color: Colors.white,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _brandNavy,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Join LaDolce and start ordering',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _nameController,
                            decoration: _inputDecoration('Full Name', Icons.badge_outlined),
                            validator: (value) => value!.isEmpty ? 'Please enter name' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration: _inputDecoration(
                              _selectedRole == 'customer'
                                  ? 'Phone Number (Required for Customers)'
                                  : 'Phone Number (Optional)',
                              Icons.phone_outlined,
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (_selectedRole == 'customer' && value!.isEmpty) {
                                return 'Phone number is required for customers';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _loginController,
                            decoration: _inputDecoration('Email / Login', Icons.email_outlined),
                            validator: (value) => value!.isEmpty ? 'Please enter login/email' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            validator: (value) => value!.isEmpty ? 'Please enter password' : null,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Role',
                            style: TextStyle(
                              color: _brandNavy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            children: [
                              ChoiceChip(
                                label: const Text('Customer'),
                                selected: _selectedRole == 'customer',
                                selectedColor: _brandNavy,
                                labelStyle: TextStyle(
                                  color: _selectedRole == 'customer' ? Colors.white : _brandNavy,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: const BorderSide(color: Color(0xFFDCE5FF)),
                                onSelected: (_) => setState(() => _selectedRole = 'customer'),
                              ),
                              ChoiceChip(
                                label: const Text('Cashier'),
                                selected: _selectedRole == 'cashier',
                                selectedColor: _brandNavy,
                                labelStyle: TextStyle(
                                  color: _selectedRole == 'cashier' ? Colors.white : _brandNavy,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: const BorderSide(color: Color(0xFFDCE5FF)),
                                onSelected: (_) => setState(() => _selectedRole = 'cashier'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandNavy,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : const Text(
                                      'REGISTER',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: _brandNavy),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE5FF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE5FF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brandNavy, width: 1.5),
      ),
    );
  }
}
