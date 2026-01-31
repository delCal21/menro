import 'package:flutter/material.dart';
import 'package:capstone/Service/auth_service.dart';
import 'package:capstone/View/login_page.dart';
import 'package:capstone/User/ordinance_user_view.dart';
import 'package:capstone/User/report_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class UserBaseScreen extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onMenuTap;
  final Widget body;

  const UserBaseScreen({
    super.key,
    required this.selectedIndex,
    required this.onMenuTap,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Dashboard'),
        backgroundColor: const Color(0xFFFF9800),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => onMenuTap(-1),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFFF9800)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Color(0xFF0A4D68)),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'User Panel',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
            ),
            _drawerItem(Icons.dashboard, 'Dashboard', 0),
            _drawerItem(Icons.add_box, '+ Report', 1),
            _drawerItem(Icons.book, 'Ordinances', 2),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => onMenuTap(-1),
            ),
          ],
        ),
      ),
      body: body,
    );
  }

  ListTile _drawerItem(IconData icon, String text, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      selected: selectedIndex == index,
      onTap: () => onMenuTap(index),
    );
  }
}

class _UserScreenState extends State<UserScreen> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  void _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _onMenuTap(int index) {
    if (index == -1) {
      _logout();
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Widget _buildStatusCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReports() {
    if (_currentUser == null) {
      return const Center(child: Text('Please log in.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('userId', isEqualTo: _currentUser!.uid)
          .orderBy('dateTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs;
        final pending = reports.where((d) => (d['status'] ?? '').toLowerCase() == 'pending').length;
        final progress = reports.where((d) => (d['status'] ?? '').toLowerCase() == 'on progress').length;
        final done = reports.where((d) => (d['status'] ?? '').toLowerCase() == 'done').length;

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status cards row
                  Row(
                    children: [
                      _buildStatusCard('Pending', pending, Colors.orange),
                      const SizedBox(width: 8),
                      _buildStatusCard('On Progress', progress, Colors.blue),
                      const SizedBox(width: 8),
                      _buildStatusCard('Done', done, Colors.green),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('My Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: reports.isEmpty
                        ? const Center(child: Text('No reports found.'))
                        : ListView.builder(
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final data = reports[index].data() as Map<String, dynamic>;
                        final ordinance = data['ordinance'] ?? 'Unknown';
                        final desc = data['description'] ?? '';
                        final date = (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now();
                        final status = (data['status'] ?? 'Pending').toString();

                        Color statusColor;
                        switch (status.toLowerCase()) {
                          case 'done':
                            statusColor = Colors.green;
                            break;
                          case 'on progress':
                            statusColor = Colors.blue;
                            break;
                          default:
                            statusColor = Colors.orange;
                        }

                        return Card(
                          child: ListTile(
                            title: Text(ordinance, overflow: TextOverflow.ellipsis),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(
                                  "Status: $status",
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(DateFormat('yyyy-MM-dd').format(date)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReportDetailsPage(reportData: data),
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
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportPage()));
                },
                icon: const Icon(Icons.report),
                label: const Text('Report'),
                backgroundColor: const Color(0xFFE6871A),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboard() {
    if (_currentUser == null) {
      return const Center(child: Text('Please log in.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('userId', isEqualTo: _currentUser!.uid)
          .orderBy('dateTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs;

        // Calculate status counts
        final pending = reports.where((d) => (d['status'] ?? '').toLowerCase() == 'pending').length;
        final progress = reports.where((d) => (d['status'] ?? '').toLowerCase() == 'on progress').length;
        final done = reports.where((d) => (d['status'] ?? '').toLowerCase() == 'done').length;

        // Calculate most reported ordinances
        final ordinanceCounts = <String, int>{};
        for (final report in reports) {
          final data = report.data() as Map<String, dynamic>;
          final ordinance = data['ordinance'] ?? 'Unknown';
          ordinanceCounts[ordinance] = (ordinanceCounts[ordinance] ?? 0) + 1;
        }

        // Sort ordinances by count (descending)
        final sortedOrdinances = ordinanceCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have ${reports.length} reports',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Status cards row
              Text(
                'Report Status Overview',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D68),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              pending.toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Pending',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              progress.toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'On Progress',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              done.toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Done',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Most Reported Ordinances Bar Chart
              Text(
                'Most Reported Ordinances',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D68),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    height: 240,
                    child: sortedOrdinances.isEmpty
                        ? Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'No reports yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : BarChart(
                            BarChartData(
                              barGroups: sortedOrdinances.take(5).map((entry) {
                                return BarChartGroupData(
                                  x: sortedOrdinances.indexOf(entry),
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.toDouble(),
                                      color: const Color(0xFF0A4D68),
                                      width: 18,
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(color: Colors.white, width: 1),
                                    ),
                                  ],
                                );
                              }).toList(),
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    final ordinance = sortedOrdinances[group.x].key;
                                    final count = sortedOrdinances[group.x].value;
                                    return BarTooltipItem(
                                      '$ordinance\n$count reports',
                                      const TextStyle(color: Colors.white),
                                    );
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40, // Reserve space for the labels
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index < 0 || index >= sortedOrdinances.length) {
                                        return const Text('');
                                      }
                                      final ordinance = sortedOrdinances[index].key;
                                      // Truncate long ordinance names to prevent overcrowding
                                      String displayName = ordinance.length > 10
                                          ? '${ordinance.substring(0, 10)}...'
                                          : ordinance;
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        child: Text(
                                          displayName,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(show: false),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdinances() => const OrdinanceUserView();

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_selectedIndex) {
      case 0:
        body = _buildDashboard();
        break;
      case 1:
        body = _buildReports();
        break;
      case 2:
        body = _buildOrdinances();
        break;
      default:
        body = _buildDashboard();
    }
    return UserBaseScreen(
      selectedIndex: _selectedIndex,
      onMenuTap: _onMenuTap,
      body: body,
    );
  }
}

class ReportDetailsPage extends StatelessWidget {
  final Map<String, dynamic> reportData;
  const ReportDetailsPage({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final date = (reportData['dateTime'] as Timestamp?)?.toDate();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        backgroundColor: const Color(0xFFFF9800),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _detailRow('Ordinance', reportData['ordinance']),
            _detailRow('Description', reportData['description']),
            _detailRow('Address', reportData['address']),
            _detailRow('Reported Person', reportData['reportedPerson']),
            _detailRow('Status', reportData['status']),
            if (date != null) _detailRow('Date', DateFormat('yyyy-MM-dd HH:mm').format(date)),
            const SizedBox(height: 12),
            if (reportData['photoUrl'] != null &&
                reportData['photoUrl'].toString().isNotEmpty) ...[
              const Text(
                'Uploaded Photo:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  reportData['photoUrl'].toString(),
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  headers: const {"Connection": "keep-alive"},
                  errorBuilder: (context, error, stackTrace) =>
                      const Text('Unable to load image', style: TextStyle(color: Colors.red)),
                ),
              ),
            ] else ...[
              Row(
                children: const [
                  Icon(Icons.image_not_supported, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('No photo uploaded', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text("$title: ${value ?? ''}", style: const TextStyle(fontSize: 16)),
    );
  }
}
