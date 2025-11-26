import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class QuickFirebaseCheckScreen extends StatefulWidget {
  const QuickFirebaseCheckScreen({super.key});

  @override
  State<QuickFirebaseCheckScreen> createState() => _QuickFirebaseCheckScreenState();
}

class _QuickFirebaseCheckScreenState extends State<QuickFirebaseCheckScreen> {
  String _status = 'Checking...';
  Color _statusColor = Colors.orange;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkFirebase();
  }

  Future<void> _checkFirebase() async {
    setState(() {
      _isChecking = true;
      _status = 'Testing Firebase Authentication...';
      _statusColor = Colors.orange;
    });

    try {
      final auth = FirebaseAuth.instance;
      
      // Try to check if we can access auth methods for a dummy email
      try {
        await auth.fetchSignInMethodsForEmail('test@example.com');
        setState(() {
          _status = '✅ Firebase Authentication is ENABLED!\n\nYou can now register and login.';
          _statusColor = Colors.green;
          _isChecking = false;
        });
      } catch (e) {
        if (e.toString().contains('CONFIGURATION_NOT_FOUND') ||
            e.toString().contains('recaptcha') ||
            e.toString().contains('not enabled')) {
          setState(() {
            _status = '❌ Email/Password Authentication is NOT ENABLED\n\n'
                'To fix this:\n'
                '1. Go to Firebase Console\n'
                '2. Open Authentication\n'
                '3. Go to Sign-in method tab\n'
                '4. Enable Email/Password\n'
                '5. Click Save\n'
                '6. Come back and try again';
            _statusColor = Colors.red;
            _isChecking = false;
          });
        } else {
          setState(() {
            _status = '✅ Firebase seems OK!\n\nError was expected: ${e.toString().substring(0, 100)}';
            _statusColor = Colors.green;
            _isChecking = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: ${e.toString()}';
        _statusColor = Colors.red;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Check'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkFirebase,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isChecking)
                const CircularProgressIndicator()
              else
                Icon(
                  _statusColor == Colors.green ? Icons.check_circle : Icons.error,
                  size: 80,
                  color: _statusColor,
                ),
              const SizedBox(height: 24),
              Card(
                color: _statusColor.withAlpha((0.1 * 255).round()),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    _status,
                    style: TextStyle(
                      fontSize: 16,
                      color: _statusColor.withAlpha((0.9 * 255).round()),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (!_isChecking && _statusColor == Colors.green)
                ElevatedButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Go to Login'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _checkFirebase,
                child: const Text('Check Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
