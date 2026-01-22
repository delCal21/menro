import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Signup with approval status
  Future<String?> signup({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          );

      // Add user to Firestore with approved: false
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'role': role,
        'approved': false, // Initially not approved
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // No error
    } catch (e) {
      return e.toString();
    }
  }

  // Login with approval check
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Try to get Firestore user doc by UID first
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      // If not found by UID (older data may use random IDs), fall back to lookup by email
      if (!userDoc.exists) {
        final emailFromAuth = userCredential.user?.email?.trim().toLowerCase();
        if (emailFromAuth != null) {
          final querySnap = await _firestore
              .collection('users')
              .where('email', isEqualTo: emailFromAuth)
              .limit(1)
              .get();
          if (querySnap.docs.isNotEmpty) {
            userDoc = querySnap.docs.first;
          }
        }
      }

      if (!userDoc.exists) {
        await _auth.signOut();
        return 'User data not found';
      }

      // Normalize role (trim + case-insensitive, always return a consistent value)
      final String rawRole = (userDoc['role'] ?? '').toString();
      String roleLower = rawRole.trim().toLowerCase();

      // Special-case: force a known admin email to be treated as admin
      final String? emailFromAuth = userCredential.user?.email;
      if (emailFromAuth != null &&
          emailFromAuth.trim().toLowerCase() == 'admin@gmail.com') {
        roleLower = 'admin';
      }

      // ignore: avoid_print
      print('AuthService.login rawRole="$rawRole", normalized="$roleLower"');

      // Handle approved stored either as bool or string ("true"/"false")
      final dynamic rawApproved = userDoc['approved'];
      final bool isApproved =
          rawApproved == true ||
          rawApproved?.toString().toLowerCase() == 'true';

      // Skip approval check for admins and barangay officials (case-insensitive)
      // Only regular users must be approved.
      if (roleLower != 'admin' &&
          roleLower != 'barangay_official' &&
          !isApproved) {
        await _auth.signOut();
        return 'Account not approved';
      }

      // Map any role text to the 3 values used by the UI routing
      if (roleLower == 'admin') {
        return 'Admin';
      } else if (roleLower == 'barangay_official') {
        return 'barangay_official';
      } else {
        return 'User';
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
