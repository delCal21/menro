import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _formKey = GlobalKey<FormState>();

  String? _userName;
  String? _selectedOrdinance;
  // Selected barangay (both id and display name)
  String? _selectedBarangayId;
  String? _selectedBarangay;

  List<String> _ordinances = [];
  // Each barangay item will contain: {'id': doc.id, 'name': 'Barangay Name'}
  List<Map<String, String>> _barangays = [];

  final TextEditingController _personController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final DateTime _selectedDateTime = DateTime.now();

File? _imageFile;
XFile? _pickedWebImage;
Uint8List? _webImageBytes;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadOrdinances();
    _loadBarangays();
  }

  // Load User Name
  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userData.exists) {
        setState(() {
          _userName = userData['name'];
        });
      }
    }
  }

  // Load Ordinances
  Future<void> _loadOrdinances() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('ordinances').get();
      setState(() {
        _ordinances = snapshot.docs.map((doc) => doc['title'] as String).toList();
      });
    } catch (e) {
    }
  }

  // Load Barangays
  Future<void> _loadBarangays() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('barangays').get();
      setState(() {
        _barangays = snapshot.docs.map((doc) {
          final data = doc.data();
          final name = (data['name'] as String?) ?? '';
          return {
            'id': doc.id,
            'name': name,
          };
        }).toList();
      });
    } catch (e) {
    }
  }

  // Image Picker
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile =
    await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      return;
    }

    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedWebImage = pickedFile;
        _webImageBytes = bytes;
      });
    } else {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  // Upload Image
  Future<String?> _uploadImage() async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('report_proofs/proof_${DateTime.now().millisecondsSinceEpoch}.jpg');

      if (kIsWeb && _webImageBytes != null) {
        final uploadTask = ref.putData(
          _webImageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        await uploadTask;
      } else if (_imageFile != null) {
        final uploadTask = ref.putFile(_imageFile!);
        await uploadTask;

      } else {
        return null;
      }

      final url = await ref.getDownloadURL();
      return url;

    } catch (e) {
      return null;
    }
  }

  // Submit Report
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Image required
    if (_pickedWebImage == null && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a proof image.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Upload image with timeout
      String? imageUrl = await _uploadImage().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          return null;
        },
      );

      if (imageUrl == null) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image upload failed. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      // Prepare data
      final reportData = {
        'userId': currentUser.uid,
        'userName': _userName ?? 'Unknown',
        'ordinance': _selectedOrdinance,
        'reportedPerson': _personController.text.trim(),
        // Human‑readable address (barangay name)
        'address': _selectedBarangay,
        // Technical field used by barangay dashboards to filter reports
        'assignedBarangayId': _selectedBarangayId,
        'dateTime': Timestamp.fromDate(_selectedDateTime),
        'description': _descriptionController.text.trim(),
        'photoUrl': imageUrl,
        'status': 'Pending',
        'submittedAt': FieldValue.serverTimestamp(),
      };

      // Submit to Firestore with timeout
      await FirebaseFirestore.instance
          .collection('reports')
          .add(reportData)
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Firestore write timed out');
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Clear form
      _personController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedOrdinance = null;
        _selectedBarangay = null;
        _imageFile = null;
        _pickedWebImage = null;
        _webImageBytes = null;
      });

      // Go back to previous screen
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
    DateFormat('yyyy-MM-dd   hh:mm a').format(_selectedDateTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Report'),
        backgroundColor: const Color(0xFF0A4D68),
      ),
      body: _userName == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
                    // NAME
                    TextFormField(
                      initialValue: _userName,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ORDINANCE
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Ordinance Violated',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedOrdinance,
                      items: _ordinances
                          .map((ord) => DropdownMenuItem(
                        value: ord,
                        child: Text(ord),
                      ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedOrdinance = value),
                      validator: (value) =>
                      value == null ? 'Please select an ordinance' : null,
                    ),
                    const SizedBox(height: 16),

                    // BARANGAY
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Barangay / Address',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedBarangayId,
                      items: _barangays
                          .map(
                            (b) => DropdownMenuItem<String>(
                              value: b['id'],
                              child: Text(b['name'] ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBarangayId = value;
                          // Also keep the barangay name for display / address field
                          _selectedBarangay = _barangays
                              .firstWhere(
                                (b) => b['id'] == value,
                                orElse: () => {'name': ''},
                              )['name'];
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a barangay' : null,
                    ),
                    const SizedBox(height: 16),

                    // PERSON (optional)
                    TextFormField(
                      controller: _personController,
                      decoration: const InputDecoration(
                        labelText: 'Person to Complain (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // DATE
                    TextFormField(
                      readOnly: true,
                      initialValue: formattedDate,
                      decoration: const InputDecoration(
                        labelText: 'Date & Time of Incident',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // DESCRIPTION
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description (Required)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value!.isEmpty ? 'Please provide a description' : null,
                    ),
                    const SizedBox(height: 20),

                    // IMAGE PICKER
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Proof Photo (Required)",
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),

                        // IMAGE PREVIEW
                        if (_webImageBytes != null)
                          Image.memory(_webImageBytes!, height: 200)
                        else if (_imageFile != null)
                          Image.file(_imageFile!, height: 200)
                        else
                          const Text("No image selected."),

                        const SizedBox(height: 8),

                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text("Upload Proof Image"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // SUBMIT BTN
                    ElevatedButton(
                      onPressed: _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A4D68),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Submit Report'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}