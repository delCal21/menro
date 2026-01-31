import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:capstone/Service/auth_service.dart';
import 'package:capstone/View/login_page.dart';
import 'package:capstone/Barangay/barangay_ordinance_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class BarangayOfficialScreen extends StatefulWidget {
  const BarangayOfficialScreen({super.key});

  @override
  State<BarangayOfficialScreen> createState() => _BarangayOfficialScreenState();
}

class _BarangayOfficialScreenState extends State<BarangayOfficialScreen> {
  int _selectedIndex = 0;
  String? barangayName;

  final List<Widget> _pages = [
    const _BarangayDashboard(),
    const _BarangayReportsPage(),
    const _BarangayUsersPage(),
    const BarangayOrdinanceView(),
  ];

  final List<String> _pageTitles = [
    'Dashboard',
    'Reports',
    'Users',
    'Ordinances',
  ];

  @override
  void initState() {
    super.initState();
    _loadBarangayName();
  }

  Future<void> _loadBarangayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Try to load user doc by UID first
    DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .get();

    // Fall back to lookup by email if UID-based doc doesn't exist
    if (!userDoc.exists && user.email != null) {
      final querySnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (querySnap.docs.isNotEmpty) {
        userDoc = querySnap.docs.first;
      }
    }

    if (!userDoc.exists) {
      if (!mounted) return;
      setState(() {
        barangayName = 'Barangay Official';
      });
      return;
    }

    final barangayId = userDoc.data()?['barangayId'] as String?;
    if (barangayId == null) {
      if (!mounted) return;
      setState(() {
        barangayName = 'Barangay Official';
      });
      return;
    }

    final barangayDoc = await FirebaseFirestore.instance
        .collection('barangays')
        .doc(barangayId)
        .get();

    if (!mounted) return;
    if (barangayDoc.exists) {
      setState(() {
        barangayName =
            (barangayDoc.data()?['name'] as String?) ?? 'Barangay Official';
      });
    } else {
      setState(() {
        barangayName = 'Barangay Official';
      });
    }
  }

  void _logout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  void _onSelectMenu(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.of(context).pop(); // close drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          barangayName == null
              ? 'Loading...'
              : '$barangayName - ${_pageTitles[_selectedIndex]}',
        ),
        backgroundColor: const Color(0xFFFF9800), // Match Admin AppBar color
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Logout",
          ),
        ],
      ),
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero, // Sharp edges
        ),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF0A4D68), // Match Admin sidebar header color
                borderRadius: BorderRadius.zero, // Sharp edges
              ),
              accountName: Text(barangayName ?? "Barangay Official"),
              accountEmail: FirebaseAuth.instance.currentUser?.email != null
                  ? Text(FirebaseAuth.instance.currentUser!.email!)
                  : null,
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  barangayName != null && barangayName!.isNotEmpty
                      ? barangayName![0].toUpperCase()
                      : "B",
                  style: const TextStyle(fontSize: 40, color: Colors.blue),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Dashboard"),
              selected: _selectedIndex == 0,
              selectedTileColor: Colors.orange.withOpacity(0.1),
              onTap: () => _onSelectMenu(0),
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text("Reports"),
              selected: _selectedIndex == 1,
              selectedTileColor: Colors.orange.withOpacity(0.1),
              onTap: () => _onSelectMenu(1),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Users"),
              selected: _selectedIndex == 2,
              selectedTileColor: Colors.orange.withOpacity(0.1),
              onTap: () => _onSelectMenu(2),
            ),
            ListTile(
              leading: const Icon(Icons.gavel),
              title: const Text("Ordinances"),
              selected: _selectedIndex == 3,
              selectedTileColor: Colors.orange.withOpacity(0.1),
              onTap: () => _onSelectMenu(3),
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}

class _BarangayReportsPage extends StatefulWidget {
  const _BarangayReportsPage();

  @override
  State<_BarangayReportsPage> createState() => _BarangayReportsPageState();
}

class _BarangayReportsPageState extends State<_BarangayReportsPage> {
  String? userBarangayId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  bool _sortNewestFirst = true;

  static const List<String> _statusFilters = [
    'All',
    'On Progress',
    'Pending',
    'Sent',
    'Done',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserBarangayId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserBarangayId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Try by UID first
    DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .get();

    // Fall back to lookup by email if needed
    if (!userDoc.exists && user.email != null) {
      final querySnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (querySnap.docs.isNotEmpty) {
        userDoc = querySnap.docs.first;
      }
    }

    if (!mounted) return;
    final loadedBarangayId = userDoc.data()?['barangayId'] as String?;
    setState(() {
      userBarangayId = loadedBarangayId;
    });

    // Debug: Print barangay ID to help troubleshoot
    if (loadedBarangayId != null) {
      // ignore: avoid_print
      print('Barangay Official - Loaded barangayId: $loadedBarangayId');

      // Test query to see all reports with this assignedBarangayId
      FirebaseFirestore.instance
          .collection('reports')
          .where('assignedBarangayId', isEqualTo: loadedBarangayId)
          .get()
          .then((snapshot) {
            // ignore: avoid_print
            print(
              'Barangay Official - Test query found ${snapshot.docs.length} reports with assignedBarangayId=$loadedBarangayId',
            );
            for (final doc in snapshot.docs) {
              final data = doc.data();
              // ignore: avoid_print
              print(
                '  Test Report ${doc.id}: status=${data['status']}, assignedBarangayId=${data['assignedBarangayId']}',
              );
            }
          })
          .catchError((e) {
            // ignore: avoid_print
            print('Barangay Official - Test query error: $e');
          });
    } else {
      // ignore: avoid_print
      print('Barangay Official - WARNING: barangayId is null!');
      // ignore: avoid_print
      print('Barangay Official - User doc data: ${userDoc.data()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userBarangayId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading barangay information...'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('assignedBarangayId', isEqualTo: userBarangayId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  // ignore: avoid_print
                  print('Barangay Official - Query error: ${snapshot.error}');
                  final errorStr =
                      snapshot.error?.toString() ?? 'Unknown error';
                  final barangayIdStr = userBarangayId ?? 'Not set';
                  return _buildEmptyState(
                    'Error: $errorStr\n\nYour Barangay ID: $barangayIdStr',
                  );
                }

                final docs =
                    snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                // Debug: Print query results
                // ignore: avoid_print
                print(
                  'Barangay Official - Query returned ${docs.length} reports',
                );
                // ignore: avoid_print
                print(
                  'Barangay Official - Looking for reports with assignedBarangayId=$userBarangayId',
                );
                for (final doc in docs) {
                  final data = doc.data();
                  final assignedId = data['assignedBarangayId'];
                  final status = data['status'];
                  // ignore: avoid_print
                  print(
                    '  Report ${doc.id}: assignedBarangayId=$assignedId (type: ${assignedId.runtimeType}), status=$status',
                  );
                }

                // Also check if there are any reports with null or different assignedBarangayId
                if (docs.isEmpty && userBarangayId != null) {
                  // ignore: avoid_print
                  print(
                    'Barangay Official - No reports found! Checking all reports...',
                  );
                  FirebaseFirestore.instance
                      .collection('reports')
                      .limit(10)
                      .get()
                      .then((allReports) {
                        // ignore: avoid_print
                        print(
                          'Barangay Official - Found ${allReports.docs.length} sample reports:',
                        );
                        for (final report in allReports.docs) {
                          final data = report.data();
                          final assignedId = data['assignedBarangayId'];
                          final status = data['status'];
                          // ignore: avoid_print
                          print(
                            '  Report ${report.id}: assignedBarangayId=$assignedId (type: ${assignedId.runtimeType}), status=$status',
                          );
                          if (assignedId != null) {
                            // ignore: avoid_print
                            print(
                              '    Match? ${assignedId == userBarangayId} (assigned: "$assignedId" vs user: "$userBarangayId")',
                            );
                            // ignore: avoid_print
                            print(
                              '    String comparison: ${assignedId.toString() == userBarangayId.toString()}',
                            );
                          }
                        }
                      })
                      .catchError((e) {
                        // ignore: avoid_print
                        print(
                          'Barangay Official - Error checking all reports: $e',
                        );
                      });
                }

                final filteredDocs = _filterAndSortReports(docs);
                final summaryCounts = _buildSummaryCounts(docs);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned Reports',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryWrap(summaryCounts),
                    const SizedBox(height: 24),
                    _buildFilterBar(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? _buildEmptyState('No reports match your filters.')
                          : ListView.builder(
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                return _buildReportCard(doc.id, doc.data());
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterAndSortReports(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = _searchQuery.toLowerCase();
    final statusToMatch = _statusFilter.toLowerCase();

    final filtered = docs.where((doc) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();

      if (statusToMatch != 'all' && status != statusToMatch) {
        return false;
      }

      if (query.isNotEmpty) {
        final fields = [
          data['ordinance'],
          data['description'],
          data['reportedPerson'],
          data['userName'],
          data['address'],
        ];

        final matchesSearch = fields.any(
          (field) =>
              field != null && field.toString().toLowerCase().contains(query),
        );

        if (!matchesSearch) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final aDate =
          (a.data()['dateTime'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          (b.data()['dateTime'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return _sortNewestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });

    return filtered;
  }

  Map<String, int> _buildSummaryCounts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final counts = <String, int>{
      'total': docs.length,
      'onProgress': 0,
      'pending': 0,
      'sent': 0,
      'done': 0,
    };

    for (final doc in docs) {
      final status = (doc.data()['status'] ?? '').toString().toLowerCase();
      switch (status) {
        case 'on progress':
          counts['onProgress'] = (counts['onProgress'] ?? 0) + 1;
          break;
        case 'pending':
          counts['pending'] = (counts['pending'] ?? 0) + 1;
          break;
        case 'sent':
          counts['sent'] = (counts['sent'] ?? 0) + 1;
          break;
        case 'done':
          counts['done'] = (counts['done'] ?? 0) + 1;
          break;
        default:
          break;
      }
    }

    return counts;
  }

  Widget _buildSummaryWrap(Map<String, int> counts) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard(
          'Total Reports',
          counts['total'] ?? 0,
          Colors.blue,
          Icons.list_alt,
        ),
        _summaryCard(
          'On Progress',
          counts['onProgress'] ?? 0,
          Colors.purple,
          Icons.directions_walk,
        ),
        _summaryCard(
          'Pending',
          counts['pending'] ?? 0,
          Colors.orange,
          Icons.pending_actions,
        ),
        _summaryCard(
          'Sent',
          counts['sent'] ?? 0,
          Colors.amber.shade800,
          Icons.send,
        ),
        _summaryCard(
          'Done',
          counts['done'] ?? 0,
          Colors.green,
          Icons.check_circle,
        ),
      ],
    );
  }

  Widget _summaryCard(String title, int count, Color color, IconData icon) {
    return SizedBox(
      width: 170,
      child: Card(
        color: color,
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(title, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search by ordinance, reporter, address...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Status filter',
                  border: OutlineInputBorder(),
                ),
                value: _statusFilter,
                items: _statusFilters
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _statusFilter = value);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(_sortNewestFirst ? Icons.south : Icons.north),
                label: Text(_sortNewestFirst ? 'Newest first' : 'Oldest first'),
                onPressed: () =>
                    setState(() => _sortNewestFirst = !_sortNewestFirst),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportCard(String reportId, Map<String, dynamic> data) {
    final status = (data['status'] ?? 'Unknown').toString();
    final dateLabel = _formatTimestamp(data['dateTime']);
    final updatedLabel = _formatTimestamp(
      data['updatedAt'] ?? data['idSubmittedAt'] ?? data['dateTime'],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _statusColor(status).withOpacity(0.15),
                  child: Icon(Icons.assignment, color: _statusColor(status)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['ordinance'] ?? 'No Ordinance',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text('Reported by: ${data['userName'] ?? 'Unknown'}'),
                      Text(
                        'Person reported: ${data['reportedPerson'] ?? 'N/A'}',
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data['description'] ?? 'No description provided.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(data['address'] ?? 'No address'),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(dateLabel),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Updated $updatedLabel',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                _buildActions(status, reportId, data),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'on progress':
        return Colors.purple;
      case 'pending':
        return Colors.orange;
      case 'sent':
        return Colors.amber;
      case 'done':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildActions(
    String status,
    String reportId,
    Map<String, dynamic> data,
  ) {
    final loweredStatus = status.toLowerCase();
    if (loweredStatus == 'on progress') {
      return Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton(
            onPressed: () => _receiveReport(reportId),
            child: const Text('Receive'),
          ),
          TextButton(
            onPressed: () => _openReportDetails(reportId, data),
            child: const Text('Details'),
          ),
        ],
      );
    }

    if (loweredStatus == 'pending') {
      return Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => _sendReportWithActionTaken(context, reportId),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A4D68),
            ),
            child: const Text('Send Report'),
          ),
          TextButton(
            onPressed: () => _openReportDetails(reportId, data),
            child: const Text('Details'),
          ),
        ],
      );
    }

    if (loweredStatus == 'sent') {
      return Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(
            Icons.watch_later_outlined,
            size: 18,
            color: Colors.orange,
          ),
          const Text('Waiting for admin review'),
          TextButton(
            onPressed: () => _openReportDetails(reportId, data),
            child: const Text('Details'),
          ),
        ],
      );
    }

    if (loweredStatus == 'done') {
      return Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const Text('Completed'),
          TextButton(
            onPressed: () => _openReportDetails(reportId, data),
            child: const Text('Details'),
          ),
        ],
      );
    }

    return TextButton(
      onPressed: () => _openReportDetails(reportId, data),
      child: const Text('Details'),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _receiveReport(String reportId) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
            'status': 'Pending',
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report received.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to receive report: $e')));
      }
    }
  }

  Future<void> _sendReportWithActionTaken(
    BuildContext context,
    String reportId,
  ) async {
    final TextEditingController actionController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Action Taken'),
        content: TextField(
          controller: actionController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter action taken description',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final actionText = actionController.text.trim();
              if (actionText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter action taken')),
                );
                return;
              }
              Navigator.of(context).pop(actionText);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .update({
              'status': 'Sent',
              'actionTaken': result,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report sent for admin review')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to send report: $e')));
        }
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate());
    }
    if (timestamp is DateTime) {
      return DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp);
    }
    return 'Not available';
  }

  void _openReportDetails(String reportId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailsPage(reportId: reportId, data: data),
      ),
    );
  }
}

class _BarangayDashboard extends StatefulWidget {
  const _BarangayDashboard();

  @override
  State<_BarangayDashboard> createState() => _BarangayDashboardState();
}

class _BarangayDashboardState extends State<_BarangayDashboard> {
  String? selectedViolation; // Track selected violation
  String? userBarangayId;

  @override
  void initState() {
    super.initState();
    _loadUserBarangayId();
  }

  Future<void> _loadUserBarangayId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Try by UID first
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .get();

    // Fall back to lookup by email if needed
    if (!doc.exists && user.email != null) {
      final querySnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (querySnap.docs.isNotEmpty) {
        doc = querySnap.docs.first;
      }
    }

    if (!mounted) return;
    setState(() {
      userBarangayId = doc.data()?['barangayId'] as String?;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (userBarangayId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('assignedBarangayId', isEqualTo: userBarangayId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildDashboardEmptyState('Unable to load dashboard data.');
        }

        final docs = snapshot.data?.docs ?? [];

        // Debug: Print dashboard query results
        // ignore: avoid_print
        print(
          'Barangay Dashboard - Query returned ${docs.length} reports for barangayId=$userBarangayId',
        );
        for (final doc in docs) {
          final data = doc.data();
          final assignedId = data['assignedBarangayId'];
          // ignore: avoid_print
          print('  Dashboard Report ${doc.id}: assignedBarangayId=$assignedId');
        }

        if (docs.isEmpty) {
          return _buildDashboardEmptyState(
            'No reports assigned to your barangay yet.',
          );
        }

        final statusCounts = _statusCounts(docs);
        final topViolations = _topViolations(docs);
        final violatorEntries = _topViolators(docs);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A4D68),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Barangay Dashboard',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Overview of reports assigned to your barangay',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Status Overview Cards
              Text(
                'Report Status Overview',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0A4D68),
                ),
              ),
              const SizedBox(height: 16),
              _buildStatusGrid(statusCounts),
              const SizedBox(height: 24),

              // Charts Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildTopViolationsCard(topViolations),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildViolatorBarChart(violatorEntries),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Status Filter Controls
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.filter_alt,
                            color: Color(0xFF0A4D68),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Filter by Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A4D68),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: selectedViolation == null,
                            onSelected: (_) {
                              setState(() {
                                selectedViolation = null;
                              });
                            },
                            selectedColor: const Color(0xFF0A4D68),
                            checkmarkColor: Colors.white,
                          ),
                          FilterChip(
                            label: const Text('On Progress'),
                            selected: selectedViolation == 'on progress',
                            onSelected: (_) {
                              setState(() {
                                selectedViolation = 'on progress';
                              });
                            },
                            selectedColor: Colors.purple,
                            checkmarkColor: Colors.white,
                          ),
                          FilterChip(
                            label: const Text('Pending'),
                            selected: selectedViolation == 'pending',
                            onSelected: (_) {
                              setState(() {
                                selectedViolation = 'pending';
                              });
                            },
                            selectedColor: Colors.orange,
                            checkmarkColor: Colors.white,
                          ),
                          FilterChip(
                            label: const Text('Sent'),
                            selected: selectedViolation == 'sent',
                            onSelected: (_) {
                              setState(() {
                                selectedViolation = 'sent';
                              });
                            },
                            selectedColor: Colors.amber,
                            checkmarkColor: Colors.white,
                          ),
                          FilterChip(
                            label: const Text('Done'),
                            selected: selectedViolation == 'done',
                            onSelected: (_) {
                              setState(() {
                                selectedViolation = 'done';
                              });
                            },
                            selectedColor: Colors.green,
                            checkmarkColor: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Filtered Reports List if a status is selected
              if (selectedViolation != null)
                _buildFilteredReportsListByStatus(docs, selectedViolation!),
            ],
          ),
        );
      },
    );
  }

  Map<String, int> _statusCounts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final counts = {'on progress': 0, 'pending': 0, 'sent': 0, 'done': 0};

    for (final doc in docs) {
      final status = (doc.data()['status'] ?? '').toString().toLowerCase();
      if (counts.containsKey(status)) {
        counts[status] = (counts[status] ?? 0) + 1;
      }
    }

    return counts;
  }

  Widget _buildStatusGrid(Map<String, int> counts) {
    return Row(
      children: [
        Expanded(
          child: _statusCard(
            'On Progress',
            counts['on progress'] ?? 0,
            Colors.purple,
            Icons.run_circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statusCard(
            'Pending',
            counts['pending'] ?? 0,
            Colors.orange,
            Icons.pending_actions,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statusCard(
            'Sent',
            counts['sent'] ?? 0,
            Colors.amber.shade800,
            Icons.send,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statusCard(
            'Done',
            counts['done'] ?? 0,
            Colors.green,
            Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _statusCard(String title, int count, Color color, IconData icon) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<MapEntry<String, int>> _topViolations(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, int> counts = {};
    for (final doc in docs) {
      final name = (doc.data()['ordinance'] ?? 'Unspecified Violation')
          .toString();
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  List<MapEntry<String, int>> _topViolators(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, int> counts = {};
    for (final doc in docs) {
      final name = (doc.data()['reportedPerson'] ?? 'Unknown').toString();
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  Widget _buildTopViolationsCard(List<MapEntry<String, int>> entries) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Top 5 Most Reported Violations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A4D68),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No violation data yet.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...entries.map(
                  (entry) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry.value} report${entry.value == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      selected: selectedViolation == entry.key,
                      selectedTileColor: Colors.orange.shade50,
                      onTap: () {
                        setState(() {
                          selectedViolation = selectedViolation == entry.key ? null : entry.key;
                        });
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredReportsListByStatus(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, String status) {
    final filtered = docs.where((doc) {
      final docStatus = (doc.data()['status'] ?? '').toString().toLowerCase();
      if (status == 'on progress') {
        return docStatus.contains('on progress') || docStatus == 'onprogress';
      }
      return docStatus == status;
    }).toList();

    if (filtered.isEmpty) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey.shade50,
                Colors.white,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No reports with status "$status".',
                style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(status),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text('Reports with status "$status"',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _getStatusColor(status),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...filtered.map((doc) {
                final data = doc.data();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getStatusIcon(status),
                        color: _getStatusColor(status),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      data['reportedPerson'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Ordinance: ${data['ordinance'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    trailing: Text(
                      'Date: ${_formatTimestampForList(data['dateTime'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'on progress':
        return Colors.purple;
      case 'pending':
        return Colors.orange;
      case 'sent':
        return Colors.amber;
      case 'done':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'on progress':
        return Icons.run_circle;
      case 'pending':
        return Icons.pending_actions;
      case 'sent':
        return Icons.send;
      case 'done':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _formatTimestampForList(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MM/dd').format(timestamp.toDate());
    }
    if (timestamp is DateTime) {
      return DateFormat('MM/dd').format(timestamp);
    }
    return 'N/A';
  }

  Widget _buildViolatorBarChart(List<MapEntry<String, int>> entries) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: entries.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No violator data yet.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Top Reported Individuals',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D68),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: BarChart(
                        BarChartData(
                          barGroups: _buildBarGroups(entries),
                          gridData: FlGridData(
                            show: true,
                            drawHorizontalLine: true,
                            horizontalInterval: 1,
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                interval: _barInterval(entries),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 120,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 || index >= entries.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final label = entries[index].key;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Transform.rotate(
                                      angle: -0.6,
                                      alignment: Alignment.center,
                                      child: Text(
                                        label,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 10),
                                        maxLines: 2,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  double _barInterval(List<MapEntry<String, int>> entries) {
    final maxValue = entries.isEmpty
        ? 1
        : entries.map((e) => e.value).reduce(math.max).toDouble();
    if (maxValue <= 5) return 1;
    return (maxValue / 5).ceilToDouble();
  }

  List<BarChartGroupData> _buildBarGroups(List<MapEntry<String, int>> entries) {
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value.value.toDouble();
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade900],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ],
        showingTooltipIndicators: const [0],
      );
    }).toList();
  }

  Widget _buildDashboardEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarangayUsersPage extends StatefulWidget {
  const _BarangayUsersPage();

  @override
  State<_BarangayUsersPage> createState() => _BarangayUsersPageState();
}

class _BarangayUsersPageState extends State<_BarangayUsersPage> {
  String? userBarangayId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUserBarangayId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserBarangayId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Try by UID first
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .get();

    // Fall back to lookup by email if needed
    if (!doc.exists && user.email != null) {
      final querySnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (querySnap.docs.isNotEmpty) {
        doc = querySnap.docs.first;
      }
    }

    if (!mounted) return;
    setState(() {
      userBarangayId = doc.data()?['barangayId'] as String?;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (userBarangayId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registered Users',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search by name or email',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) =>
                setState(() => _searchQuery = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('barangayId', isEqualTo: userBarangayId)
                  .where('role', isEqualTo: 'User')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildUsersEmptyState(
                    'Unable to load users. Please try again later.',
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final filtered =
                    docs.where((doc) {
                      final data = doc.data();
                      final name = (data['name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final email = (data['email'] ?? '')
                          .toString()
                          .toLowerCase();
                      if (_searchQuery.isEmpty) return true;
                      return name.contains(_searchQuery) ||
                          email.contains(_searchQuery);
                    }).toList()..sort((a, b) {
                      final aTime =
                          (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final bTime =
                          (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return bTime.compareTo(aTime);
                    });

                if (filtered.isEmpty) {
                  return _buildUsersEmptyState(
                    'No registered users found for this barangay.',
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = filtered[index].data();
                    return _buildUserCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> data) {
    final name = (data['name'] ?? 'Unnamed User').toString();
    final email = (data['email'] ?? 'No email').toString();
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final createdAt = _formatUserTimestamp(data['createdAt']);
    final barangayName = (data['barangayName'] ?? 'Not set').toString();

    final Color statusColor;
    final String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusLabel = 'Approved';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusLabel = 'Pending';
        break;
    }

    return Card(
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.15),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: statusColor),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email),
            Text('Barangay: $barangayName'),
            if (createdAt != null) Text('Joined: $createdAt'),
          ],
        ),
        trailing: Chip(
          label: Text(statusLabel, style: const TextStyle(color: Colors.white)),
          backgroundColor: statusColor,
        ),
      ),
    );
  }

  String? _formatUserTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
    }
    if (timestamp is DateTime) {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
    return null;
  }

  Widget _buildUsersEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportDetailsPage extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> data;

  const ReportDetailsPage({
    super.key,
    required this.reportId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final Timestamp? dateTimeStamp = data['dateTime'] as Timestamp?;
    final dateTime = dateTimeStamp?.toDate() ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Details"),
        backgroundColor: const Color(0xFFFF9800),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Ordinance: ${data['ordinance'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Reported by: ${data['userName'] ?? 'Unknown'}'),
            Text('Person reported: ${data['reportedPerson'] ?? 'N/A'}'),
            Text('Address: ${data['address'] ?? 'N/A'}'),
            Text(
              'Date & Time: ${DateFormat('yyyy-MM-dd hh:mm a').format(dateTime)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Description:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(data['description'] ?? 'N/A'),
            const SizedBox(height: 12),
            if (data['photoUrl'] != null &&
                data['photoUrl'].toString().isNotEmpty) ...[
              const Text(
                'Uploaded Photo:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  data['photoUrl'].toString(),
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  headers: const {"Connection": "keep-alive"},
                  errorBuilder: (context, error, stackTrace) => const Text(
                    'Unable to load image',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: const [
                  Icon(Icons.image_not_supported, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'No photo uploaded',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
            if (data['actionTaken'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Action Taken:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(data['actionTaken']),
            ],
            const SizedBox(height: 8),
            Text('Status: ${data['status'] ?? 'Pending'}'),
          ],
        ),
      ),
    );
  }
}
