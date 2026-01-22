// Simple Firebase Test Page
// Use this to verify your Firebase connection works

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseTestPage extends StatefulWidget {
  const FirebaseTestPage({super.key});

  @override
  State<FirebaseTestPage> createState() => _FirebaseTestPageState();
}

class _FirebaseTestPageState extends State<FirebaseTestPage> {
  String _log = 'Ready to test...\n\n';
  bool _isLoading = false;

  void _addLog(String message) {
    setState(() {
      _log += '$message\n';
    });
    print(message);
  }

  // TEST 1: Check if Firebase is initialized
  void _testFirebaseInit() {
    _addLog('=== TEST 1: Firebase Initialization ===');
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      _addLog('✅ FirebaseAuth instance: ${auth != null}');
      _addLog('✅ Firestore instance: ${firestore != null}');
      _addLog('✅ Firebase is initialized!\n');
    } catch (e) {
      _addLog('❌ Firebase initialization error: $e\n');
    }
  }

  // TEST 2: Check user authentication
  void _testAuthentication() {
    _addLog('=== TEST 2: Authentication Check ===');
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _addLog('✅ User is logged in');
      _addLog('   UID: ${user.uid}');
      _addLog('   Email: ${user.email}');
      _addLog('   Display Name: ${user.displayName ?? "Not set"}\n');
    } else {
      _addLog('❌ No user logged in\n');
    }
  }

  // TEST 3: Read from Firestore
  Future<void> _testFirestoreRead() async {
    _addLog('=== TEST 3: Firestore Read Test ===');
    setState(() => _isLoading = true);

    try {
      _addLog('Reading from "reports" collection...');

      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      _addLog('✅ Read successful!');
      _addLog('   Documents found: ${snapshot.docs.length}');

      if (snapshot.docs.isNotEmpty) {
        _addLog('   First doc ID: ${snapshot.docs.first.id}');
      }
      _addLog('');
    } catch (e) {
      _addLog('❌ Read failed: $e\n');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // TEST 4: Write to Firestore
  Future<void> _testFirestoreWrite() async {
    _addLog('=== TEST 4: Firestore Write Test ===');
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ Cannot write: No user logged in\n');
        setState(() => _isLoading = false);
        return;
      }

      _addLog('Writing test document to "reports" collection...');

      final docRef = await FirebaseFirestore.instance
          .collection('reports')
          .add({
        'test': true,
        'message': 'Test from Firebase Connection Test',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
      })
          .timeout(const Duration(seconds: 10));

      _addLog('✅ Write successful!');
      _addLog('   Document ID: ${docRef.id}\n');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Success! Doc ID: ${docRef.id}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _addLog('❌ Write failed: $e\n');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Write failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // TEST 5: Full report simulation
  Future<void> _testFullReport() async {
    _addLog('=== TEST 5: Full Report Simulation ===');
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ Cannot create report: No user logged in\n');
        setState(() => _isLoading = false);
        return;
      }

      _addLog('Creating full report structure...');

      final reportData = {
        'userId': user.uid,
        'userName': 'Test User',
        'ordinance': 'Test Ordinance',
        'reportedPerson': 'Test Person',
        'address': 'Test Barangay',
        'dateTime': Timestamp.now(),
        'description': 'This is a test report',
        'photoUrl': 'https://via.placeholder.com/150',
        'status': 'Pending',
        'submittedAt': FieldValue.serverTimestamp(),
      };

      _addLog('Report data prepared with ${reportData.length} fields');
      _addLog('Submitting to Firestore...');

      final docRef = await FirebaseFirestore.instance
          .collection('reports')
          .add(reportData)
          .timeout(const Duration(seconds: 10));

      _addLog('✅ Full report created successfully!');
      _addLog('   Document ID: ${docRef.id}\n');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report created! ID: ${docRef.id}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      _addLog('❌ Report creation failed: $e\n');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _runAllTests() async {
    setState(() {
      _log = '';
      _isLoading = true;
    });

    _testFirebaseInit();
    await Future.delayed(const Duration(milliseconds: 500));

    _testAuthentication();
    await Future.delayed(const Duration(milliseconds: 500));

    await _testFirestoreRead();
    await Future.delayed(const Duration(milliseconds: 500));

    await _testFirestoreWrite();
    await Future.delayed(const Duration(milliseconds: 500));

    await _testFullReport();

    setState(() => _isLoading = false);
    _addLog('=== ALL TESTS COMPLETED ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Connection Test'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Log display
          Expanded(
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Text(
                  _log,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const LinearProgressIndicator(),

          // Test buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _testFirebaseInit,
                        child: const Text('1. Init'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _testAuthentication,
                        child: const Text('2. Auth'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _testFirestoreRead,
                        child: const Text('3. Read'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _testFirestoreWrite,
                        child: const Text('4. Write'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _testFullReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('5. Full Report Test'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _runAllTests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('🚀 RUN ALL TESTS'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() => _log = 'Logs cleared.\n\n');
                  },
                  child: const Text('Clear Logs'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}