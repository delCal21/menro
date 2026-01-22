import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrdinanceAddScreen extends StatefulWidget {
  const OrdinanceAddScreen({super.key});

  @override
  State<OrdinanceAddScreen> createState() => _OrdinanceAddScreenState();
}

class _OrdinanceAddScreenState extends State<OrdinanceAddScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String searchQuery = '';
  String? _editingDocId;

  Future<void> _showAddOrUpdateDialog({Map<String, dynamic>? data, String? docId}) async {
    if (data != null) {
      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _editingDocId = docId;
    } else {
      _titleController.clear();
      _descriptionController.clear();
      _editingDocId = null;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_editingDocId == null ? 'Add Ordinance' : 'Edit Ordinance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Ordinance Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearForm();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _addOrUpdateOrdinance();
              if (context.mounted) Navigator.pop(ctx);
            },
            child: Text(_editingDocId == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _addOrUpdateOrdinance() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required')),
      );
      return;
    }

    if (_editingDocId == null) {
      await FirebaseFirestore.instance.collection('ordinances').add({
        'title': title,
        'description': description,
        'dateAdded': Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordinance added successfully!')),
      );
    } else {
      await FirebaseFirestore.instance.collection('ordinances').doc(_editingDocId).update({
        'title': title,
        'description': description,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordinance updated successfully!')),
      );
    }

    _clearForm();
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _editingDocId = null;
  }

  void _showOrdinanceDetails(BuildContext context, Map<String, dynamic> data) {
    final timestamp = data['dateAdded'] as Timestamp?;
    final formattedDate = timestamp != null
        ? DateFormat('MMMM dd, yyyy').format(timestamp.toDate())
        : 'Not available';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(data['title'] ?? 'No Title'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                data['description'] ?? 'No description available.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                'Added on: $formattedDate',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrdinance(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this ordinance?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('ordinances').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordinance deleted')),
      );
      _clearForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ordinances...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),

            // Ordinance List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ordinances')
                    .orderBy('dateAdded', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Error loading ordinances');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  // Filter based on search query
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? '').toString().toLowerCase();
                    final description = (data['description'] ?? '').toString().toLowerCase();
                    return title.contains(searchQuery) || description.contains(searchQuery);
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Text('No ordinances found.');
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            data['title'] ?? 'No Title',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _showOrdinanceDetails(context, data),
                                icon: const Icon(Icons.visibility, size: 18),
                                label: const Text('View'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showAddOrUpdateDialog(data: data, docId: doc.id);
                                  } else if (value == 'delete') {
                                    _deleteOrdinance(doc.id);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrdinanceDialog(),
        label: const Text('Add Ordinance'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFFFF9800),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showAddOrdinanceDialog() {
    _showAddOrUpdateDialog();
  }
}
