import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BarangaysPage extends StatefulWidget {
  const BarangaysPage({super.key});

  @override
  State<BarangaysPage> createState() => _BarangaysPageState();
}

class _BarangaysPageState extends State<BarangaysPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isAdding = false;
  bool _obscurePassword = true;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  Future<void> _addBarangayAndOfficial() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      // Add barangay with officials array
      DocumentReference barangayDoc = await _firestore
          .collection('barangays')
          .add({
            'name': name,
            'dateAdded': FieldValue.serverTimestamp(),
            'officials': [
              {
                'name': name,
                'email': email,
                'password': password, // ⚠️ For demo only (insecure)
              },
            ],
          });

      // Create Firebase Auth account
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save official info in users collection - AUTOMATICALLY APPROVED
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': email,
        'role': 'barangay_official',
        'barangayId': barangayDoc.id,
        'barangayName': name,
        'status': 'approved', // ✅ Auto-approved
        'approved': true, // ✅ Auto-approved
        'approvedAt': FieldValue.serverTimestamp(), // ✅ Set approval timestamp
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();

      setState(() => _isAdding = false);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barangay & Official created successfully'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to create account')),
      );
    } catch (e) {
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Barangay & Official'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Barangay Name',
                  hintText: 'Enter barangay name',
                ),
              ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Official Email',
                  hintText: 'Enter email',
                ),
              ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Official Password',
                  hintText: 'Enter password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isAdding
                ? null
                : () {
                    Navigator.of(context).pop();
                    _nameController.clear();
                    _emailController.clear();
                    _passwordController.clear();
                  },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isAdding ? null : _addBarangayAndOfficial,
            child: _isAdding
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showBarangayInfo(Map<String, dynamic> data) {
    final officials = (data['officials'] ?? []) as List<dynamic>;
    final official = officials.isNotEmpty
        ? officials.first as Map<String, dynamic>
        : {};

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['name'] ?? 'Barangay Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${official['name'] ?? 'N/A'}'),
            Text('Email: ${official['email'] ?? 'N/A'}'),
            Text('Password: ${official['password'] ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barangay Management'),
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('barangays')
            .orderBy('dateAdded', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading barangays'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final totalItems = docs.length;
          final totalPages = (totalItems / _itemsPerPage).ceil();

          // Reset to last valid page if current page is out of bounds
          if (totalPages > 0 && _currentPage >= totalPages) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _currentPage = totalPages - 1;
              });
            });
          }

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No barangays found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Barangay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Calculate pagination
          final startIndex = _currentPage * _itemsPerPage;
          final endIndex = (startIndex + _itemsPerPage < totalItems)
              ? startIndex + _itemsPerPage
              : totalItems;
          final paginatedDocs = docs.sublist(startIndex, endIndex);

          return Column(
            children: [
              // Header with Add Button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey,
                      spreadRadius: 0,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Barangay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Table
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: SizedBox(
                            width: constraints.maxWidth > 0
                                ? constraints.maxWidth - 32
                                : double.infinity,
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(
                                const Color(0xFF0A4D68),
                              ),
                              headingTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              dataRowMinHeight: 60,
                              dataRowMaxHeight: 80,
                              columnSpacing: 20,
                              horizontalMargin: 0,
                              columns: const [
                                DataColumn(label: Text('Barangay Name')),
                                DataColumn(label: Text('Official Email')),
                                DataColumn(label: Text('Official Name')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: paginatedDocs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final name = data['name'] ?? 'Unnamed Barangay';

                                // Get email and official name from first official if available
                                String email = 'No email';
                                String officialName = 'No name';
                                if (data['officials'] != null &&
                                    (data['officials'] as List).isNotEmpty) {
                                  final official =
                                      (data['officials'] as List).first;
                                  email = official['email'] ?? 'No email';
                                  officialName = official['name'] ?? 'No name';
                                }

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        email,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        officialName,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(
                                          Icons.info_outline,
                                          size: 20,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () =>
                                            _showBarangayInfo(data),
                                        tooltip: 'View Details',
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Pagination Controls
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${startIndex + 1}-$endIndex of $totalItems barangays',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 0
                              ? () {
                                  setState(() {
                                    _currentPage--;
                                  });
                                }
                              : null,
                          tooltip: 'Previous Page',
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            'Page ${_currentPage + 1} of $totalPages',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _currentPage < totalPages - 1
                              ? () {
                                  setState(() {
                                    _currentPage++;
                                  });
                                }
                              : null,
                          tooltip: 'Next Page',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
