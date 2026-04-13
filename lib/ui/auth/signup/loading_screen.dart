import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  int _currentStep = 0;
  final List<String> _steps = [
    "Getting things ready...",
    "Creating Account...",
    "Your next memory is one event away",
  ];

  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  Future<void> _startSequence() async {
    for (int i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentStep = i;
      });
      // Simulate fake loading time for each step.
      // In a real app we'd await Firebase Account creation here as well.
      await Future.delayed(const Duration(seconds: 2));
    }
    
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Darken background to black
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _steps[_currentStep],
                key: ValueKey<int>(_currentStep),
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
