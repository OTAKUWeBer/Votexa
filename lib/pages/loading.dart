import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/poll_provider.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Initialize device ID and navigate
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        context.read<PollProvider>().initializeDeviceId().then((_) {
          Navigator.of(context).pushReplacementNamed('/home');
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
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
            colors: [Color(0xFF0A0E27), Color(0xFF141829)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              RotationTransition(
                turns: _animationController,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0DD9FF).withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Title
              const Text(
                'Votexa',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle
              const Text(
                'Real-time Offline Polling',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFd1d5db),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 60),
              // Loading indicator
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF0DD9FF).withOpacity(0.8),
                  ),
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Initializing...',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9ca3af),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
