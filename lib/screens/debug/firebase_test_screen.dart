import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  String _status = 'Testing Firebase connection...';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _testFirebase();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toIso8601String().substring(11, 19)}: $message');
    });
  debugPrint(message);
  }

  Future<void> _testFirebase() async {
    try {
      _addLog('🔍 Starting Firebase tests...');

      // Test 1: Firebase Core
      _addLog('📦 Testing Firebase Core initialization...');
      final app = Firebase.app();
      _addLog('✅ Firebase Core: ${app.name} (${app.options.projectId})');

      // Test 2: Firebase Auth
      _addLog('🔐 Testing Firebase Auth...');
      final auth = FirebaseAuth.instance;
      _addLog('✅ Auth instance: ${auth.app.name}');
      _addLog('👤 Current user: ${auth.currentUser?.email ?? "Not logged in"}');

      // Test 3: Check Auth Providers
      _addLog('🔍 Checking available auth methods...');
      try {
        await auth.fetchSignInMethodsForEmail('test@example.com');
        _addLog('✅ Auth methods check successful (Email/Password seems enabled)');
      } catch (e) {
        if (e.toString().contains('CONFIGURATION_NOT_FOUND')) {
          _addLog('❌ Email/Password authentication is NOT ENABLED in Firebase Console!');
          _addLog('⚠️  Go to: Firebase Console → Authentication → Sign-in method');
          _addLog('⚠️  Enable Email/Password provider');
        } else {
          _addLog('⚠️  Auth methods check: ${e.toString()}');
        }
      }

      // Test 4: Firestore
      _addLog('📊 Testing Firestore...');
      final firestore = FirebaseFirestore.instance;
      _addLog('✅ Firestore instance: ${firestore.app.name}');

      // Try to read from Firestore
      try {
        await firestore.collection('test').limit(1).get();
        _addLog('✅ Firestore read permission: OK');
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          _addLog('⚠️  Firestore permissions: Limited (expected for production)');
        } else {
          _addLog('❌ Firestore error: $e');
        }
      }

      // Test 5: Network connectivity
      _addLog('🌐 Testing network connectivity...');
      try {
        await firestore.enableNetwork();
        _addLog('✅ Network: Connected');
      } catch (e) {
        _addLog('❌ Network error: $e');
      }

      setState(() {
        _status = '✅ Tests Complete!';
      });
      
      _addLog('');
      _addLog('=== SUMMARY ===');
      if (_logs.any((log) => log.contains('NOT ENABLED'))) {
        _addLog('⚠️  ACTION REQUIRED: Enable Email/Password in Firebase Console');
        _addLog('📍 URL: https://console.firebase.google.com');
      } else {
        _addLog('✅ Firebase is properly configured!');
      }
    } catch (e) {
      _addLog('❌ Critical error: $e');
      setState(() {
        _status = '❌ Tests Failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Connection Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _logs.clear();
                _status = 'Testing Firebase connection...';
              });
              _testFirebase();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.science, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _status,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Test Logs:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      Color textColor = Colors.black87;
                      if (log.contains('✅')) textColor = Colors.green;
                      if (log.contains('❌')) textColor = Colors.red;
                      if (log.contains('⚠️')) textColor = Colors.orange;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: textColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_logs.any((log) => log.contains('NOT ENABLED')))
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Action Required',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Open Firebase Console\n'
                        '2. Go to Authentication → Sign-in method\n'
                        '3. Enable Email/Password provider\n'
                        '4. Click Save\n'
                        '5. Refresh this screen',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
