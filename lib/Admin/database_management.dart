// lib/Admin/database_management.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class DatabaseManagementPage extends StatefulWidget {
  const DatabaseManagementPage({super.key});

  @override
  State<DatabaseManagementPage> createState() => _DatabaseManagementPageState();
}

class _DatabaseManagementPageState extends State<DatabaseManagementPage> {
  bool _isLoading = false;

  // Create backup of all collections
  Future<void> _createBackup() async {
    setState(() => _isLoading = true);

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now();
      // Strongly type the collections map so we can safely add entries.
      final Map<String, List<Map<String, dynamic>>> collectionsData = {};

      final Map<String, dynamic> backupData = {
        'backupDate': timestamp.toIso8601String(),
        'backupBy': user.email,
        'collections': collectionsData,
      };

      // Backup all collections
      final collections = ['reports', 'ordinances', 'barangays', 'users'];

      for (String collectionName in collections) {
        final snapshot = await FirebaseFirestore.instance
            .collection(collectionName)
            .get();

        final data = snapshot.docs.map((doc) {
          final docData = doc.data();
          docData['_docId'] = doc.id; // Store document ID
          return docData;
        }).toList();

        // Store the documents for this collection in the typed map.
        collectionsData[collectionName] = data;
      }

      // Save backup to Firestore
      final backupRef = await FirebaseFirestore.instance
          .collection('backups')
          .add(backupData);

      // Log transaction
      await _logTransaction('BACKUP_CREATED', 'Full database backup created', {
        'backupId': backupRef.id,
        'collections': collections.length,
      });

      // Export to JSON file
      await _exportBackupToFile(backupData, timestamp);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Export backup to JSON file
  Future<void> _exportBackupToFile(
    Map<String, dynamic> backupData,
    DateTime timestamp,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'backup_${DateFormat('yyyyMMdd_HHmmss').format(timestamp)}.json';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(json.encode(backupData));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup saved to: ${file.path}')));
    } catch (e) {
      print('Error exporting backup: $e');
    }
  }

  // Restore from backup
  Future<void> _restoreBackup(String backupId) async {
    // Confirm restoration
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database'),
        content: const Text(
          'This will replace all current data with the backup. This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Get backup data
      final backupDoc = await FirebaseFirestore.instance
          .collection('backups')
          .doc(backupId)
          .get();

      if (!backupDoc.exists) throw Exception('Backup not found');

      final backupData = backupDoc.data()!;
      final rawCollections = backupData['collections'];
      if (rawCollections is! Map) {
        throw Exception('Invalid backup format: collections is not a map');
      }
      final collections = Map<String, dynamic>.from(rawCollections);

      // Restore each collection
      for (final entry in collections.entries) {
        final collectionName = entry.key;
        final value = entry.value;

        // Support both List and Map formats for stored documents
        final Iterable<dynamic> documents;
        if (value is List) {
          documents = value;
        } else if (value is Map) {
          documents = value.values;
        } else {
          // Unexpected structure – skip this collection
          continue;
        }

        // Clear existing collection
        final existingDocs = await FirebaseFirestore.instance
            .collection(collectionName)
            .get();

        for (var doc in existingDocs.docs) {
          await doc.reference.delete();
        }

        // Restore documents
        for (final docData in documents) {
          if (docData is! Map) continue;
          final data = Map<String, dynamic>.from(docData);
          final docId = data.remove('_docId'); // Remove and get the doc ID

          if (docId != null) {
            await FirebaseFirestore.instance
                .collection(collectionName)
                .doc(docId)
                .set(data);
          }
        }
      }

      // Log transaction
      await _logTransaction(
        'BACKUP_RESTORED',
        'Database restored from backup',
        {'backupId': backupId},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database restored successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Import backup from file
  Future<void> _importBackupFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return;

      setState(() => _isLoading = true);

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final backupData = json.decode(jsonString) as Map<String, dynamic>;

      // Save to backups collection
      await FirebaseFirestore.instance.collection('backups').add(backupData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup imported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Log transaction
  Future<void> _logTransaction(
    String action,
    String description,
    Map<String, dynamic>? metadata,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('transaction_logs').add({
      'action': action,
      'description': description,
      'userId': user?.uid,
      'userEmail': user?.email,
      'timestamp': FieldValue.serverTimestamp(),
      'metadata': metadata ?? {},
    });
  }

  // Delete old backups
  Future<void> _deleteBackup(String backupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: const Text('Are you sure you want to delete this backup?'),
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

    try {
      await FirebaseFirestore.instance
          .collection('backups')
          .doc(backupId)
          .delete();

      await _logTransaction('BACKUP_DELETED', 'Backup deleted', {
        'backupId': backupId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup deleted successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Database Management'),
          backgroundColor: const Color(0xFFFF9800),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.backup), text: 'Backups'),
              Tab(icon: Icon(Icons.history), text: 'Transaction Logs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildBackupsTab(), _buildTransactionLogsTab()],
        ),
      ),
    );
  }

  Widget _buildBackupsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createBackup,
                  icon: const Icon(Icons.backup),
                  label: const Text('Create Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _importBackupFromFile,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: LinearProgressIndicator(),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('backups')
                .orderBy('backupDate', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final backups = snapshot.data!.docs;

              if (backups.isEmpty) {
                return const Center(child: Text('No backups available'));
              }

              return ListView.builder(
                itemCount: backups.length,
                itemBuilder: (context, index) {
                  final backup = backups[index];
                  final data = backup.data() as Map<String, dynamic>;
                  final backupDate = DateTime.parse(data['backupDate']);
                  final backupBy = data['backupBy'] ?? 'Unknown';
                  final collections =
                      data['collections'] as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0A4D68),
                        child: Icon(Icons.storage, color: Colors.white),
                      ),
                      title: Text(
                        DateFormat('MMM dd, yyyy hh:mm a').format(backupDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('By: $backupBy'),
                          Text('Collections: ${collections.length}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore, color: Colors.blue),
                            tooltip: 'Restore',
                            onPressed: _isLoading
                                ? null
                                : () => _restoreBackup(backup.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: _isLoading
                                ? null
                                : () => _deleteBackup(backup.id),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionLogsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transaction_logs')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data!.docs;

        if (logs.isEmpty) {
          return const Center(child: Text('No transaction logs available'));
        }

        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final data = log.data() as Map<String, dynamic>;
            final action = data['action'] ?? 'UNKNOWN';
            final description = data['description'] ?? '';
            final userEmail = data['userEmail'] ?? 'Unknown';
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

            IconData icon;
            Color color;

            switch (action) {
              case 'BACKUP_CREATED':
                icon = Icons.backup;
                color = Colors.green;
                break;
              case 'BACKUP_RESTORED':
                icon = Icons.restore;
                color = Colors.blue;
                break;
              case 'BACKUP_DELETED':
                icon = Icons.delete;
                color = Colors.red;
                break;
              default:
                icon = Icons.info;
                color = Colors.grey;
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                child: Icon(icon, color: color),
              ),
              title: Text(
                action.replaceAll('_', ' '),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description),
                  if (timestamp != null)
                    Text(
                      DateFormat('MMM dd, yyyy hh:mm a').format(timestamp),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  Text(
                    'By: $userEmail',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }
}
