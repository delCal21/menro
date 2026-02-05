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
  String _sortField = 'dateAdded'; // Default sort field
  bool _sortAscending = false; // Default sort order (newest first)

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All fields are required')),
        );
      }
      return;
    }

    if (_editingDocId == null) {
      await FirebaseFirestore.instance.collection('ordinances').add({
        'title': title,
        'description': description,
        'dateAdded': Timestamp.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ordinance added successfully!')),
        );
      }
    } else {
      await FirebaseFirestore.instance.collection('ordinances').doc(_editingDocId).update({
        'title': title,
        'description': description,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ordinance updated successfully!')),
        );
      }
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
        contentPadding: const EdgeInsets.symmetric(vertical: 28, horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.gavel, color: Colors.orange.shade700, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data['title'] ?? 'No Title',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.description, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                data['description'] ?? 'No description available.',
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Added on: $formattedDate',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ordinance deleted')),
        );
      }
      _clearForm();
    }
  }

  // Sort function
  void _sortData(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = field == 'dateAdded' ? false : true; // Default to descending for dateAdded
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Bar and Controls
            Row(
              children: [
                Expanded(
                  child: TextField(
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
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort by',
                  onSelected: (String? value) {
                    if (value != null) {
                      _sortData(value);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'title',
                      child: Text('Sort by Title'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'dateAdded',
                      child: Text('Sort by Date Added'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Single Card Containing the Entire Table
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4472C4), // Excel-style header color
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade600),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: InkWell(
                                  onTap: () => _sortData('title'),
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Title',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Icon(
                                          _sortField == 'title'
                                              ? _sortAscending
                                                  ? Icons.arrow_upward
                                                  : Icons.arrow_downward
                                              : Icons.swap_vert,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  child: const Text(
                                    'Description',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () => _sortData('dateAdded'),
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Date Added',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Icon(
                                          _sortField == 'dateAdded'
                                              ? _sortAscending
                                                  ? Icons.arrow_upward
                                                  : Icons.arrow_downward
                                              : Icons.swap_vert,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  child: const Text(
                                    'Actions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Ordinance Table
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('ordinances')
                              .orderBy(_sortField, descending: !_sortAscending)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Center(child: Text('Error loading ordinances'));
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
                              return const Center(child: Text('No ordinances found.'));
                            }

                            return Scrollbar(
                              thumbVisibility: true,
                              child: ListView.builder(
                                itemCount: filteredDocs.length,
                                itemBuilder: (context, index) {
                                  final doc = filteredDocs[index];
                                  final data = doc.data() as Map<String, dynamic>;

                                  final timestamp = data['dateAdded'] as Timestamp?;
                                  final formattedDate = timestamp != null
                                      ? DateFormat('MMM dd, yyyy').format(timestamp.toDate())
                                      : 'Not available';

                                  // Alternate row colors for Excel-like appearance
                                  Color rowColor = index % 2 == 0
                                      ? const Color(0xFFFFFFFF) // White
                                      : const Color(0xFFFCFCFC); // Light gray

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: rowColor,
                                      border: Border(
                                        left: BorderSide(color: Colors.grey.shade300),
                                        right: BorderSide(color: Colors.grey.shade300),
                                        top: BorderSide(color: Colors.grey.shade300),
                                        bottom: index == filteredDocs.length - 1
                                            ? BorderSide(color: Colors.grey.shade300)
                                            : BorderSide.none,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Container(
                                              padding: const EdgeInsets.all(8.0),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  right: BorderSide(color: Colors.grey.shade300),
                                                ),
                                              ),
                                              child: Text(
                                                data['title'] ?? 'No Title',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(8.0),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  right: BorderSide(color: Colors.grey.shade300),
                                                ),
                                              ),
                                              child: Text(
                                                data['description'] ?? 'No description',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(8.0),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  right: BorderSide(color: Colors.grey.shade300),
                                                ),
                                              ),
                                              child: Text(
                                                formattedDate,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.visibility, size: 18, color: Colors.blue),
                                                    tooltip: 'View Details',
                                                    onPressed: () => _showOrdinanceDetails(context, data),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, size: 18, color: Colors.orange),
                                                    tooltip: 'Edit',
                                                    onPressed: () => _showAddOrUpdateDialog(data: data, docId: doc.id),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                                    tooltip: 'Delete',
                                                    onPressed: () => _deleteOrdinance(doc.id),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
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
