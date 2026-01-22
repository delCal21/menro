import 'dart:typed_data';

import 'package:capstone/View/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;

  String? _selectedBarangayId;
  String? _selectedBarangayName;
  List<Map<String, String>> _barangays = [];
  bool _isLoadingBarangays = true;

  final List<String> _idTypes = const [
    'National ID',
    'Postal ID',
    'Voter\'s ID',
    'Driver\'s License',
  ];
  String? _selectedIdType;
  PlatformFile? _selectedIdFile;
  Uint8List? _selectedIdBytes;

  @override
  void initState() {
    super.initState();
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('barangays')
          .orderBy('name')
          .get();

      final seen = <String>{};
      final normalizedBarangays = <Map<String, String>>[];

      for (final doc in snapshot.docs) {
        final rawName = doc.data()['name'];
        final normalizedName = _normalizeBarangayName(rawName?.toString());
        final key = normalizedName.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);
        normalizedBarangays.add({'id': doc.id, 'name': normalizedName});
      }

      setState(() {
        _barangays = normalizedBarangays;
        _isLoadingBarangays = false;
      });
    } catch (e) {
      setState(() => _isLoadingBarangays = false);
      _showErrorDialog('Failed to load barangays: $e');
    }
  }

  String _normalizeBarangayName(String? rawName) {
    final trimmed = (rawName ?? '').trim();
    if (trimmed.isEmpty) return 'Unnamed Barangay';
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  Map<String, String>? _getBarangayById(String? id) {
    if (id == null) return null;
    for (final barangay in _barangays) {
      if (barangay['id'] == id) return barangay;
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Name is required';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!value.contains('@') || !value.contains('.')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  String? _validateBarangay(String? value) {
    if (_selectedBarangayId == null) return 'Please select a barangay';
    return null;
  }

  String? _validateIdType(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select an ID type';
    }
    return null;
  }

  String? _validateIdUpload(PlatformFile? value) {
    if (value == null) return 'Please upload a valid ID';
    return null;
  }

  Future<void> _selectIdFile(FormFieldState<PlatformFile?> fieldState) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      const maxBytes = 5 * 1024 * 1024; // 5MB limit
      if (file.size > maxBytes) {
        _showErrorDialog('Please upload an image that is 5MB or smaller.');
        return;
      }

      if (file.bytes == null) {
        _showErrorDialog(
          'Unable to read the selected file. Please try a different image.',
        );
        return;
      }

      setState(() {
        _selectedIdFile = file;
        _selectedIdBytes = file.bytes;
      });
      fieldState.didChange(file);
    } catch (e) {
      _showErrorDialog('Unable to pick ID image: $e');
    }
  }

  String _formatFileSize(int bytes) {
    final sizeInMb = bytes / (1024 * 1024);
    if (sizeInMb >= 1) {
      return '${sizeInMb.toStringAsFixed(2)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _inferMimeType(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String> _uploadIdImage(String userId) async {
    if (_selectedIdBytes == null || _selectedIdFile == null) {
      throw Exception('No ID image selected.');
    }

    final sanitizedFileName = _selectedIdFile!.name.replaceAll(
      RegExp(r'[^a-zA-Z0-9_.-]'),
      '_',
    );
    final storagePath =
        'user_ids/$userId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';

    final ref = FirebaseStorage.instance.ref().child(storagePath);
    final metadata = SettableMetadata(
      contentType: _inferMimeType(_selectedIdFile!.extension),
    );

    final uploadTask = ref.putData(_selectedIdBytes!, metadata);
    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  Future<void> _cleanupPartialSignup(UserCredential? credential) async {
    try {
      await credential?.user?.delete();
    } catch (_) {
      // Best-effort cleanup; ignore failures.
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _selectedBarangayId = null;
      _selectedBarangayName = null;
      _selectedIdType = null;
      _selectedIdFile = null;
      _selectedIdBytes = null;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signup Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPendingApprovalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registration Submitted'),
        content: const Text(
          'Your account has been submitted for approval. You will receive an email once approved by the admin.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _signup() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    if (!formState.validate()) return;

    if (_selectedBarangayId == null) {
      _showErrorDialog('Please select a barangay');
      return;
    }

    if (_selectedIdFile == null || _selectedIdBytes == null) {
      _showErrorDialog('Please upload a valid ID to continue.');
      return;
    }

    setState(() => _isLoading = true);

    UserCredential? userCred;

    try {
      userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = userCred.user!.uid;
      final barangay = _getBarangayById(_selectedBarangayId);
      final barangayName =
          barangay?['name'] ?? _selectedBarangayName ?? 'Unknown Barangay';
      final idImageUrl = await _uploadIdImage(userId);

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'User',
        // Use the same approval flags as the rest of the app so login/admin flows work properly.
        'status': 'pending', // For admin UI filters
        'approved': false, // For AuthService.login approval check
        'barangayId': _selectedBarangayId,
        'barangayName': barangayName,
        'idType': _selectedIdType,
        'idFileName': _selectedIdFile?.name,
        'idImageUrl': idImageUrl,
        'idSubmittedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _resetForm();
      _showPendingApprovalDialog();
    } on FirebaseAuthException catch (e) {
      await _cleanupPartialSignup(userCred);
      _showErrorDialog(e.message ?? 'An error occurred');
    } catch (e) {
      await _cleanupPartialSignup(userCred);
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),

          // Semi-transparent overlay
          Container(color: Colors.black.withOpacity(0.4)),

          // Signup container
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Sign Up",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: _validateName,
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 16),

                        // Barangay Dropdown
                        _isLoadingBarangays
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Select Barangay',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.location_city),
                                ),
                                isExpanded: true,
                                value: _selectedBarangayId,
                                items: _barangays.map((barangay) {
                                  final name =
                                      barangay['name'] ?? 'Unnamed Barangay';
                                  return DropdownMenuItem<String>(
                                    value: barangay['id'],
                                    child: Text(name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBarangayId = value;
                                    _selectedBarangayName = _getBarangayById(
                                      value,
                                    )?['name'];
                                  });
                                },
                                validator: _validateBarangay,
                              ),
                        const SizedBox(height: 16),

                        // ID Type Dropdown
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select ID Type',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          isExpanded: true,
                          value: _selectedIdType,
                          items: _idTypes
                              .map(
                                (type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedIdType = value),
                          validator: _validateIdType,
                        ),
                        const SizedBox(height: 16),

                        // ID Upload Field
                        FormField<PlatformFile?>(
                          validator: _validateIdUpload,
                          builder: (field) {
                            final hasError = field.hasError;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: hasError
                                          ? Colors.red
                                          : Colors.grey.shade400,
                                    ),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.verified_user,
                                            color: Color(0xFF0A4D68),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Upload Valid ID (JPG/PNG, max 5MB)',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: hasError
                                                    ? Colors.red
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () => _selectIdFile(field),
                                        icon: const Icon(
                                          Icons.cloud_upload_outlined,
                                        ),
                                        label: Text(
                                          _selectedIdFile == null
                                              ? 'Choose ID Image'
                                              : 'Change Selected ID',
                                        ),
                                      ),
                                      if (_selectedIdFile != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.image_outlined,
                                                color: Color(0xFF0A4D68),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _selectedIdFile!.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      _formatFileSize(
                                                        _selectedIdFile!.size,
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Remove',
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedIdFile = null;
                                                    _selectedIdBytes = null;
                                                  });
                                                  field.didChange(null);
                                                },
                                                icon: const Icon(Icons.close),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_selectedIdBytes != null) ...[
                                          const SizedBox(height: 12),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.memory(
                                              _selectedIdBytes!,
                                              height: 180,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                                if (hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      field.errorText ?? '',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordHidden
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordHidden = !_isPasswordHidden;
                                });
                              },
                            ),
                          ),
                          obscureText: _isPasswordHidden,
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordHidden
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isConfirmPasswordHidden =
                                      !_isConfirmPasswordHidden;
                                });
                              },
                            ),
                          ),
                          obscureText: _isConfirmPasswordHidden,
                          validator: _validateConfirmPassword,
                        ),
                        const SizedBox(height: 24),

                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          ElevatedButton(
                            onPressed: _signup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A4D68),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account? ",
                              style: TextStyle(fontSize: 16),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
