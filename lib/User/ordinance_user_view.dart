import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrdinanceUserView extends StatefulWidget {
  const OrdinanceUserView({super.key});

  @override
  State<OrdinanceUserView> createState() => _OrdinanceUserViewState();
}

class _OrdinanceUserViewState extends State<OrdinanceUserView> {
  String searchQuery = '';

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
                data['title'] ?? 'Untitled',
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
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

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final title = data['title'] ?? 'Untitled';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _showOrdinanceDetails(context, data),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('View'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
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
    );
  }
}
