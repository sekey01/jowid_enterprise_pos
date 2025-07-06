import 'package:flutter/material.dart';
import 'dart:async';

import 'package:jowid/pages/nav/index.dart';
import 'package:jowid/provider/functions.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;

  String _loadingText = 'Initializing...';
  Timer? _textTimer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    // Initialize animation controllers
    _progressController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create animations
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // Start animations
    _startAnimations();
    _updateLoadingText();
    _scheduleNavigation();
  }

  void _startAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _progressController.forward();
    });
  }

  void _updateLoadingText() {
    _textTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) return;

      setState(() {
        double progress = _progressAnimation.value;
        if (progress < 0.3) {
          _loadingText = 'Loading application...';
        } else if (progress < 0.6) {
          _loadingText = 'Setting up database...';
        } else if (progress < 0.9) {
          _loadingText = 'Preparing workspace...';
        } else {
          _loadingText = 'Almost ready...';
        }
      });
    });
  }

  void _scheduleNavigation() {
    _navigationTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        // Navigate to main app screen
        Navigator.pushReplacement(
           context,
         MaterialPageRoute(builder: (context) => const HomePage()),
        );

        // For demo purposes, just show a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading complete! Ready to navigate to main app.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fadeController.dispose();
    _textTimer?.cancel();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A), // Blue-900
              Color(0xFF1E40AF), // Blue-800
              Color(0xFF1E3A8A), // Blue-900
            ],
          ),
        ),
        child: Stack(
          children: [
            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo/Icon Section
                      _buildLogoSection(),

                      const SizedBox(height: 32),

                      // Company Name Section
                      _buildCompanyNameSection(),

                      const SizedBox(height: 32),

                      // Loading Section
                      _buildLoadingSection(),

                      const SizedBox(height: 16),

                      // Version Info
                      _buildVersionInfo(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.blue.shade100,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child:
            // Replace this with your actual logo
            // Image.asset(
            //   'assets/images/logo.png',
            //   width: 64,
            //   height: 64,
            //   fit: BoxFit.contain,
            // ),

            // Placeholder - replace with your logo
            Text(
              'JE',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyNameSection() {
    return Column(
      children: [
        const Text(
          'JOWID',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937), // Gray-800
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ENTERPRISE',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Retail & Wholesale Management System',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      children: [
        // Progress Bar
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // Loading Text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _loadingText,
            key: ValueKey(_loadingText),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfo() {
    return Text(
      'Version 1.0.0',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildFooter() {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          '© 2025 JOWID Enterprise. All rights reserved.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.75),
          ),
        ),
      ),
    );
  }
}