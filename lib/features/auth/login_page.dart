import 'package:flutter/material.dart';
import 'dart:async';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Dummy Credentials
  final String _dummyUser = "admin@maintainx.ai";
  final String _dummyPass = "factory2026";

  void _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate authentication delay
    await Future.delayed(const Duration(seconds: 2));

    if (_emailController.text == _dummyUser &&
        _passwordController.text == _dummyPass) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("SYSTEM ACCESS GRANTED: Initializing Dashboard..."),
          backgroundColor: Color(0xFF2E7D32), // Industrial Green
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _isLoading = false;
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text("ACCESS DENIED: Invalid Credentials"),
            ],
          ),
          backgroundColor: Color(0xFFC62828), // Industrial Red
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C), // Deep background matching dashboard
      body: Stack(
        children: [
          // Background Grid Overlay (blueprint/technical aesthetic)
          Opacity(
            opacity: 0.03,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 12,
              ),
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 0.5),
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: const Color(0xFF161618), // Card color used in dashboard
                  borderRadius: BorderRadius.circular(4), // Sharp corners for industrial look
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // System Brand Header
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: Colors.blueAccent, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "MAINTAINX AI",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              "PREDICTIVE OPERATOR TERMINAL",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blueAccent.withOpacity(0.8),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      "System Login",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Authorization required for fleet telemetry access.",
                      style: TextStyle(fontSize: 13, color: Colors.white38),
                    ),
                    const SizedBox(height: 40),

                    // Inputs with Uppercase Labels
                    _buildLabel("TECHNICIAN ID"),
                    _buildTextField(
                      controller: _emailController,
                      hint: "admin@maintainx.ai",
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 24),
                    _buildLabel("ACCESS KEY"),
                    _buildTextField(
                      controller: _passwordController,
                      hint: "••••••••",
                      icon: Icons.lock_outline,
                      isObscure: true,
                    ),
                    const SizedBox(height: 48),

                    // Authenticate Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white10,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text(
                                "INITIALIZE SESSION",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Security Footer
                    const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 12, color: Colors.white10),
                          SizedBox(width: 8),
                          const Text(
                            "ENCRYPTED NODE: CONNECTION SECURE",
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white10,
                              letterSpacing: 1.5,
                            ),
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
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isObscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: Colors.blueAccent,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white10, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white24, size: 18),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}