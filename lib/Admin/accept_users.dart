import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class AcceptUsersPage extends StatefulWidget {
  const AcceptUsersPage({super.key});

  @override
  State<AcceptUsersPage> createState() => _AcceptUsersPageState();
}

class _AcceptUsersPageState extends State<AcceptUsersPage> {
  String _searchQuery = '';
  String _filterRole = 'All'; // 'All', 'User', 'Barangay'
  String? _selectedBarangayId;
  String? _selectedBarangayName;
  bool _isCreatingBarangayAccount = false;

  final List<String> _denyReasons = const [
    'Unreadable or invalid ID',
    'ID does not match provided details',
    'Incomplete registration information',
    'Duplicate or existing account',
    'Outside jurisdiction',
    'Other (please specify)',
  ];

  List<QueryDocumentSnapshot> _filterUsers(List<QueryDocumentSnapshot> users) {
    return users.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final role = (data['role'] ?? '').toString().toLowerCase();

      // Search filter
      final matchesSearch =
          _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());

      // Role filter
      bool matchesRole = true;
      if (_filterRole == 'User') {
        matchesRole = role == 'user';
      } else if (_filterRole == 'Barangay') {
        // Match barangay_official role
        matchesRole =
            role == 'barangay_official' ||
            role == 'barangay' ||
            role.contains('barangay');
      }

      return matchesSearch && matchesRole;
    }).toList();
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF0A4D68)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF0A4D68),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Filter Chips
          Row(
            children: [
              const Text(
                'Filter by Role:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _filterRole == 'All',
                      onSelected: (selected) {
                        setState(() {
                          _filterRole = 'All';
                        });
                      },
                      selectedColor: const Color(0xFF0A4D68).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF0A4D68),
                      labelStyle: TextStyle(
                        color: _filterRole == 'All'
                            ? const Color(0xFF0A4D68)
                            : Colors.black87,
                        fontWeight: _filterRole == 'All'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    FilterChip(
                      label: const Text('User'),
                      selected: _filterRole == 'User',
                      onSelected: (selected) {
                        setState(() {
                          _filterRole = 'User';
                        });
                      },
                      selectedColor: const Color(0xFF0A4D68).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF0A4D68),
                      labelStyle: TextStyle(
                        color: _filterRole == 'User'
                            ? const Color(0xFF0A4D68)
                            : Colors.black87,
                        fontWeight: _filterRole == 'User'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    FilterChip(
                      label: const Text('Barangay'),
                      selected: _filterRole == 'Barangay',
                      onSelected: (selected) {
                        setState(() {
                          _filterRole = 'Barangay';
                        });
                      },
                      selectedColor: const Color(0xFF0A4D68).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF0A4D68),
                      labelStyle: TextStyle(
                        color: _filterRole == 'Barangay'
                            ? const Color(0xFF0A4D68)
                            : Colors.black87,
                        fontWeight: _filterRole == 'Barangay'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarangayAccountCreator() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [const Color(0xFF0A4D68).withOpacity(0.05), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A4D68).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_business,
                  color: Color(0xFF0A4D68),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Barangay Account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A4D68),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select a barangay and create an official account',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('barangays')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const SizedBox(
                      width: 200,
                      child: Text(
                        'Unable to load barangays.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 200,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const SizedBox(
                      width: 200,
                      child: Text(
                        'No barangays available',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    );
                  }

                  final items = docs
                      .map(
                        (doc) => DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(
                            doc['name'] ?? 'Unnamed Barangay',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList();

                  return Row(
                    children: [
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            hintText: 'Select Barangay',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF0A4D68),
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                          value: _selectedBarangayId,
                          items: items,
                          isExpanded: true,
                          onChanged: (value) {
                            if (value == null) return;
                            final selectedDoc = docs.firstWhere(
                              (doc) => doc.id == value,
                              orElse: () => docs.first,
                            );
                            setState(() {
                              _selectedBarangayId = value;
                              _selectedBarangayName =
                                  selectedDoc['name'] ?? 'Barangay';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed:
                            (_selectedBarangayId == null ||
                                _isCreatingBarangayAccount)
                            ? null
                            : () => _showCreateBarangayAccountDialog(),
                        icon: _isCreatingBarangayAccount
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add, size: 18),
                        label: const Text('Create Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A4D68),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createBarangayAccount({
    required String barangayId,
    required String barangayName,
    required String officialName,
    required String email,
    required String password,
  }) async {
    setState(() => _isCreatingBarangayAccount = true);
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await firestore.collection('users').doc(credential.user!.uid).set({
        'name': officialName,
        'email': email,
        'role': 'barangay_official',
        'barangayId': barangayId,
        'barangayName': barangayName,
        'status': 'approved',
        'approved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await firestore.collection('barangays').doc(barangayId).update({
        'officials': FieldValue.arrayUnion([
          {'name': officialName, 'email': email},
        ]),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Barangay account for $barangayName created successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to create barangay account.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create barangay account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingBarangayAccount = false);
      }
    }
  }

  Future<void> _fixBarangayOfficialId(
    QueryDocumentSnapshot userDoc,
    String email,
    BuildContext context,
  ) async {
    try {
      // Find the barangay document that contains this official's email
      final barangaysSnapshot = await FirebaseFirestore.instance
          .collection('barangays')
          .get();

      String? correctBarangayId;
      String? barangayName;

      for (final barangayDoc in barangaysSnapshot.docs) {
        final data = barangayDoc.data();
        final officials = data['officials'];

        if (officials is List) {
          for (final official in officials) {
            if (official is Map && official['email'] == email) {
              correctBarangayId = barangayDoc.id;
              barangayName = data['name'] as String?;
              break;
            }
          }
        }

        if (correctBarangayId != null) break;
      }

      if (correctBarangayId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not find barangay for this official. Please check the barangays collection.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Update the user's barangayId
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .update({
            'barangayId': correctBarangayId,
            'barangayName': barangayName ?? 'Unknown',
          });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Barangay ID fixed! Updated to: $correctBarangayId ($barangayName)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fix barangay ID: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCreateBarangayAccountDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: Text(
              'New Account for ${_selectedBarangayName ?? 'Barangay'}',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Official Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setStateDialog(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: obscurePassword,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isCreatingBarangayAccount
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isCreatingBarangayAccount
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final email = emailController.text.trim();
                        final password = passwordController.text.trim();
                        if (name.isEmpty || email.isEmpty || password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in all fields.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pop();
                        await _createBarangayAccount(
                          barangayId: _selectedBarangayId!,
                          barangayName: _selectedBarangayName ?? 'Barangay',
                          officialName: name,
                          email: email,
                          password: password,
                        );
                      },
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Future<void> approveUser(
    String docId,
    String name,
    String email,
    BuildContext context,
  ) async {
    try {
      // Update user status to approved
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'status': 'approved',
        'approved': true, // Keep for backward compatibility if needed
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Note: Email will be sent automatically by Cloud Function
      // If you're using the Cloud Function I provided earlier

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name has been approved. Notification email will be sent.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving $name: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteUserIdImage(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // ignore cleanup failures
    }
  }

  Future<void> rejectUser(
    QueryDocumentSnapshot doc,
    BuildContext context,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? 'User').toString();
    final formKey = GlobalKey<FormState>();
    final TextEditingController notesController = TextEditingController();
    String? selectedReason;

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Deny User Application'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Reason for denial',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedReason,
                    isExpanded: true,
                    items: _denyReasons
                        .map(
                          (reason) => DropdownMenuItem<String>(
                            value: reason,
                            child: Text(reason),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setStateDialog(() => selectedReason = value),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please select a reason'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    enabled: selectedReason == _denyReasons.last,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Additional details (required for Other)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (selectedReason == _denyReasons.last) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please provide details for "Other"';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  Navigator.pop(dialogContext, {
                    'reason': selectedReason!,
                    'notes': notesController.text.trim(),
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Deny'),
              ),
            ],
          ),
        );
      },
    );

    notesController.dispose();

    if (result == null) return;

    try {
      await doc.reference.update({
        'status': 'denied',
        'deniedAt': FieldValue.serverTimestamp(),
        'deniedReason': result['reason'],
        'deniedNotes': result['notes'],
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name has been denied.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error denying $name: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> deleteUser(
    QueryDocumentSnapshot doc,
    BuildContext context,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? 'User').toString();
    final idImageUrl = (data['idImageUrl'] ?? '').toString();

    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete User'),
          content: Text(
            'Are you sure you want to delete $name? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      await _deleteUserIdImage(idImageUrl);
      await doc.reference.delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name has been deleted'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting $name: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUserDetails(
    QueryDocumentSnapshot doc,
    BuildContext scaffoldContext,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? 'No name').toString();
    final email = (data['email'] ?? 'No email').toString();
    final barangayName = (data['barangayName'] ?? 'Not set').toString();
    final idType = (data['idType'] ?? 'Not provided').toString();
    final idFileName = (data['idFileName'] ?? 'N/A').toString();
    final role = (data['role'] ?? 'User').toString();
    final idImageUrl = (data['idImageUrl'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;
    final idSubmittedAt = data['idSubmittedAt'] is Timestamp
        ? (data['idSubmittedAt'] as Timestamp).toDate()
        : null;
    final deniedReason = (data['deniedReason'] ?? '').toString();
    final deniedNotes = (data['deniedNotes'] ?? '').toString();

    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final statusLabel = status == 'approved'
        ? 'Approved'
        : status == 'denied'
        ? 'Denied'
        : 'Pending Review';
    final createdAtLabel = createdAt != null
        ? dateFormat.format(createdAt)
        : 'Not available';
    final idSubmittedLabel = idSubmittedAt != null
        ? dateFormat.format(idSubmittedAt)
        : 'Not available';

    final canApprove = status != 'approved';
    final canDeny = status == 'pending';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Registration',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verify the applicant\'s details before approving or denying their account.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Name', name),
                    _buildDetailRow('Email', email),
                    _buildDetailRow('Role', role),
                    _buildDetailRow('Barangay', barangayName),
                    _buildDetailRow(
                      'ID Type',
                      idType.isEmpty ? 'Not provided' : idType,
                    ),
                    _buildDetailRow('ID File', idFileName),
                    _buildDetailRow('Status', statusLabel),
                    if (deniedReason.isNotEmpty)
                      _buildDetailRow('Denial Reason', deniedReason),
                    if (deniedNotes.isNotEmpty)
                      _buildDetailRow('Denial Notes', deniedNotes),
                    _buildDetailRow('Registered', createdAtLabel),
                    _buildDetailRow('ID Submitted', idSubmittedLabel),
                    const SizedBox(height: 16),
                    const Text(
                      'Uploaded ID',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (idImageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: Colors.black12,
                          height: 300,
                          width: double.infinity,
                          child: InteractiveViewer(
                            maxScale: 4,
                            child: Image.network(
                              idImageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Text('Unable to load ID image'),
                                  ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text('No ID image uploaded.'),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: canApprove
                                ? () async {
                                    Navigator.of(dialogContext).pop();
                                    await approveUser(
                                      doc.id,
                                      name,
                                      email,
                                      scaffoldContext,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              disabledBackgroundColor: Colors.green.shade200,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (canDeny) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            await rejectUser(doc, scaffoldContext);
                          },
                          icon: const Icon(Icons.block, color: Colors.red),
                          label: const Text(
                            'Deny Application',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersListWithCreator(
    List<QueryDocumentSnapshot> users,
    bool showActions,
    BuildContext context,
  ) {
    return Column(
      children: [
        // Barangay Account Creator integrated at top of table
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _buildBarangayAccountCreator(),
        ),
        // Users Table
        _buildUsersList(users, showActions, context),
      ],
    );
  }

  Widget _buildUsersList(
    List<QueryDocumentSnapshot> users,
    bool showActions,
    BuildContext context,
  ) {
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  showActions
                      ? Icons.check_circle_outline
                      : Icons.people_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                showActions
                    ? 'No Users Waiting for Approval'
                    : 'No Users Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                showActions
                    ? 'All pending registrations have been reviewed'
                    : 'Try adjusting your search or filter criteria',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Card(
          elevation: 2,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFF0A4D68)),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            dataRowMinHeight: 60,
            dataRowMaxHeight: 80,
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Barangay')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: users.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? 'No name').toString();
              final email = (data['email'] ?? '').toString();
              final role = (data['role'] ?? '').toString();
              String status = (data['status'] ?? '').toString().toLowerCase();

              if (status.isEmpty && data.containsKey('approved')) {
                final approvedValue = data['approved'];
                if (approvedValue is bool && approvedValue) {
                  status = 'approved';
                } else if (approvedValue is String &&
                    approvedValue.toLowerCase() == 'true') {
                  status = 'approved';
                }
              }

              final isApproved = status == 'approved';
              final isDenied = status == 'denied';
              final statusColor = isApproved
                  ? Colors.green
                  : isDenied
                  ? Colors.red
                  : Colors.orange;
              final statusIcon = isApproved
                  ? Icons.check_circle
                  : isDenied
                  ? Icons.block
                  : Icons.pending;
              final statusLabel = isApproved
                  ? 'Approved'
                  : isDenied
                  ? 'Denied'
                  : 'Pending';

              final barangayName = (data['barangayName'] ?? 'Not set')
                  .toString();
              final isAdmin = role.toLowerCase() == 'admin';
              final isBarangay = role.toLowerCase().contains('barangay');

              String roleDisplay = role;
              if (isAdmin) {
                roleDisplay = 'Admin';
              } else if (isBarangay) {
                roleDisplay = 'Barangay Official';
              } else {
                roleDisplay = 'User';
              }

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: statusColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Tooltip(
                      message: email,
                      child: Text(
                        email,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? Colors.blue.withOpacity(0.1)
                            : isBarangay
                            ? Colors.purple.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAdmin
                              ? Colors.blue.withOpacity(0.3)
                              : isBarangay
                              ? Colors.purple.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        roleDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isAdmin
                              ? Colors.blue
                              : isBarangay
                              ? Colors.purple
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Tooltip(
                      message: barangayName,
                      child: Text(
                        barangayName,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'View Details',
                          child: IconButton(
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 20,
                            ),
                            color: const Color(0xFF0A4D68),
                            onPressed: () => _showUserDetails(doc, context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        if (isBarangay) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Fix Barangay ID',
                            child: IconButton(
                              icon: const Icon(Icons.sync, size: 20),
                              color: Colors.orange,
                              onPressed: () =>
                                  _fixBarangayOfficialId(doc, email, context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                        if (!isAdmin) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Delete User',
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.red,
                              onPressed: () => deleteUser(doc, context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(QuerySnapshot? allUsersSnapshot) {
    if (allUsersSnapshot == null) {
      return const SizedBox.shrink();
    }

    final allUsers = allUsersSnapshot.docs;
    final totalUsers = allUsers.length;
    final pendingCount = allUsers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['status'] ?? '').toString().toLowerCase() == 'pending';
    }).length;
    final approvedCount = allUsers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['status'] ?? '').toString().toLowerCase() == 'approved';
    }).length;
    final deniedCount = allUsers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['status'] ?? '').toString().toLowerCase() == 'denied';
    }).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Users',
              totalUsers.toString(),
              Icons.people,
              const Color(0xFF0A4D68),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Pending',
              pendingCount.toString(),
              Icons.pending_actions,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Approved',
              approvedCount.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Denied',
              deniedCount.toString(),
              Icons.block,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            Container(
              color: const Color(0xFF0A4D68),
              child: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: TextStyle(fontWeight: FontWeight.w600),
                tabs: [
                  Tab(icon: Icon(Icons.people), text: 'All Users'),
                  Tab(
                    icon: Icon(Icons.pending_actions),
                    text: 'Pending Approval',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // All Users Tab
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .snapshots(),
                          builder: (context, snapshot) {
                            return _buildStatsCards(snapshot.data);
                          },
                        ),
                        _buildSearchAndFilter(),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Error: ${snapshot.error}'),
                                  ],
                                ),
                              );
                            }
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final allUsers = _filterUsers(snapshot.data!.docs);
                            return _buildUsersListWithCreator(
                              allUsers,
                              false,
                              context,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Pending Approval Tab
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final pendingCount = snapshot.data!.docs.where((
                                doc,
                              ) {
                                final data = doc.data() as Map<String, dynamic>;
                                return (data['status'] ?? '')
                                        .toString()
                                        .toLowerCase() ==
                                    'pending';
                              }).length;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                color: Colors.orange.shade50,
                                width: double.infinity,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '$pendingCount user${pendingCount != 1 ? 's' : ''} waiting for approval',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        _buildSearchAndFilter(),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .where('status', isEqualTo: 'pending')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Error: ${snapshot.error}'),
                                  ],
                                ),
                              );
                            }
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final pendingUsers = snapshot.data!.docs;
                            return _buildUsersList(pendingUsers, true, context);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
