import 'package:flutter/material.dart';
import 'package:capstone/Service/auth_service.dart';
import 'package:capstone/View/login_page.dart';
import 'package:capstone/Admin/ordinances_add.dart';
import 'package:capstone/Admin/barangays_add.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:capstone/Admin/accept_users.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;
  bool _isSidebarOpen = false; // Track sidebar state

  String? _selectedBarangayFilter = 'All Barangays';
  String _searchTerm = '';
  bool _sortNewestFirst = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _lastBackupPath;
  String? _selectedDashboardBarangay = 'All Barangays';
  final List<int> _yearOptions = List.generate(
    6,
    (index) => DateTime.now().year - index,
  );
  int _selectedYear = DateTime.now().year;

  String? userRole;
  String? userBarangayId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
  }

  Future<void> _exportReportsToPDF() async {
    try {
      final pdf = pw.Document();
      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .get();

      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context context) {
            final docs = reportsSnapshot.docs;
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Summary Report',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Total Reports: ${docs.length}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey500,
                  width: 0.8,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2), // Ordinance
                  1: pw.FlexColumnWidth(2), // Reported By
                  2: pw.FlexColumnWidth(2), // Person Reported
                  3: pw.FlexColumnWidth(2), // Address
                  4: pw.FlexColumnWidth(3), // Description
                  5: pw.FlexColumnWidth(1.5), // Status
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Ordinance',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Reported By',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Person Reported',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Address',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Status',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['ordinance'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['userName'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['reportedPerson'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['address'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['description'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['status'] ?? 'Pending'}'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  Future<void> _exportReportsByBarangay() async {
    try {
      // Show dialog to select barangay
      final barangaysSnapshot = await FirebaseFirestore.instance
          .collection('barangays')
          .orderBy('name')
          .get();

      if (!mounted) return;

      String? selectedBarangay;
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Select Barangay'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: barangaysSnapshot.docs.map((doc) {
                  final name = (doc['name'] ?? 'Unnamed Barangay').toString();
                  return ListTile(
                    title: Text(name),
                    onTap: () {
                      selectedBarangay = name;
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ),
          );
        },
      );

      if (selectedBarangay == null) return;

      final pdf = pw.Document();
      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('address', isEqualTo: selectedBarangay)
          .get();

      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context context) {
            final docs = reportsSnapshot.docs;
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Reports for $selectedBarangay',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Total Reports: ${docs.length}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey500,
                  width: 0.8,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(3),
                  4: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Ordinance',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Reported By',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Person Reported',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Status',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['ordinance'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['userName'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['reportedPerson'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['description'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['status'] ?? 'Pending'}'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report for $selectedBarangay exported successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  Future<void> _exportPendingReports() async {
    try {
      final pdf = pw.Document();
      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .get();

      final pendingReports = reportsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString().toLowerCase();
        return status == 'pending';
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context context) {
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Pending Reports',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Total Pending Reports: ${pendingReports.length}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey500,
                  width: 0.8,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Ordinance',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Reported By',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Person Reported',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Address',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ...pendingReports.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['ordinance'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['userName'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['reportedPerson'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['address'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['description'] ?? 'N/A'}'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pending reports exported successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  Future<void> _exportReportsByOrdinance() async {
    try {
      // Show dialog to select ordinance
      final ordinancesSnapshot = await FirebaseFirestore.instance
          .collection('ordinances')
          .orderBy('title')
          .get();

      if (!mounted) return;

      String? selectedOrdinance;
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Select Ordinance'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: ordinancesSnapshot.docs.map((doc) {
                  final title = (doc['title'] ?? 'Unnamed Ordinance')
                      .toString();
                  return ListTile(
                    title: Text(title),
                    onTap: () {
                      selectedOrdinance = title;
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ),
          );
        },
      );

      if (selectedOrdinance == null) return;

      final pdf = pw.Document();
      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('ordinance', isEqualTo: selectedOrdinance)
          .get();

      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context context) {
            final docs = reportsSnapshot.docs;
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Reports for $selectedOrdinance',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Total Reports: ${docs.length}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey500,
                  width: 0.8,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(3),
                  5: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Reported By',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Person Reported',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Address',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Date & Time',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Status',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final dateTime = (data['dateTime'] as Timestamp?)?.toDate();
                    final dateTimeStr = dateTime != null
                        ? DateFormat('yyyy-MM-dd HH:mm').format(dateTime)
                        : 'N/A';
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['userName'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['reportedPerson'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['address'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(dateTimeStr),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['description'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['status'] ?? 'Pending'}'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report for $selectedOrdinance exported successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  Future<void> _exportCompletedReports() async {
    try {
      final pdf = pw.Document();
      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .get();

      final completedReports = reportsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString().toLowerCase();
        return status == 'done';
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context context) {
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Completed Reports',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Total Completed Reports: ${completedReports.length}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey500,
                  width: 0.8,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(3),
                  5: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Ordinance',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Reported By',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Person Reported',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Address',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Action Taken',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ...completedReports.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['ordinance'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['userName'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['reportedPerson'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['address'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['description'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('${data['actionTaken'] ?? 'N/A'}'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completed reports exported successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  Future<void> _loadCurrentUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          userRole = userDoc['role'] as String?;
          userBarangayId = userDoc['barangayId'] as String?;
        });
      }
    } catch (e) {
      // Handle error if needed
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Opens a dialog to select a backup from the `backups` collection and then
  /// restores the database from the chosen backup.
  Future<void> _showRestoreDialog() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('backups')
          .orderBy('backupDate', descending: true)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No backups available to restore.')),
        );
        return;
      }

      String? selectedBackupId;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Select Backup to Restore'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.docs[index];
                  final data = doc.data();
                  final backupDate = DateTime.parse(data['backupDate']);
                  final backupBy = data['backupBy'] ?? 'Unknown';
                  return ListTile(
                    leading: const Icon(Icons.storage),
                    title: Text(
                      DateFormat('MMM dd, yyyy hh:mm a').format(backupDate),
                    ),
                    subtitle: Text('By: $backupBy'),
                    onTap: () {
                      selectedBackupId = doc.id;
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          );
        },
      );

      if (selectedBackupId != null) {
        await _restoreFromBackup(selectedBackupId!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load backups: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Restores the Firestore collections from the specified backup document
  /// in the `backups` collection. This mirrors the behavior of the
  /// DatabaseManagementPage but is surfaced directly in System Settings.
  Future<void> _restoreFromBackup(String backupId) async {
    // Confirm restoration
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database'),
        content: const Text(
          'This will replace all current data with the backup. '
          'This action cannot be undone. Continue?',
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

    setState(() {
      _isRestoring = true;
    });

    try {
      final backupDoc = await FirebaseFirestore.instance
          .collection('backups')
          .doc(backupId)
          .get();

      if (!backupDoc.exists) {
        throw Exception('Backup not found');
      }

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

        for (final doc in existingDocs.docs) {
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

      // Log the restoration in transaction_logs so it appears in both
      // System Settings and any other log viewers.
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('transaction_logs').add({
        'action': 'BACKUP_RESTORED',
        'description':
            'Database restored from backup via Admin System Settings',
        'userId': user?.uid,
        'userEmail': user?.email,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {'backupId': backupId},
      });

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
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _triggerBackup() async {
    if (_isBackingUp || _isRestoring) return;
    setState(() => _isBackingUp = true);

    try {
      // Mirror the backup behavior from DatabaseManagementPage so we don't rely
      // on Cloud Functions for admin backups.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final timestamp = DateTime.now();
      final Map<String, List<Map<String, dynamic>>> collectionsData = {};

      final Map<String, dynamic> backupData = {
        'backupDate': timestamp.toIso8601String(),
        'backupBy': user.email,
        'collections': collectionsData,
      };

      // Backup the same core collections used in DatabaseManagementPage.
      const collections = ['reports', 'ordinances', 'barangays', 'users'];

      for (final collectionName in collections) {
        final snapshot = await FirebaseFirestore.instance
            .collection(collectionName)
            .get();

        final data = snapshot.docs.map((doc) {
          final docData = doc.data();
          docData['_docId'] = doc.id;
          return docData;
        }).toList();

        collectionsData[collectionName] = data;
      }

      final backupRef = await FirebaseFirestore.instance
          .collection('backups')
          .add(backupData);

      // Track a simple identifier for the last backup so admins have context.
      setState(() {
        _lastBackupPath =
            'Firestore backup ${DateFormat('yyyy-MM-dd HH:mm').format(timestamp)} (id: ${backupRef.id})';
      });

      // Log this backup so it appears in transaction logs alongside
      // backups created from the Database Management screen.
      await FirebaseFirestore.instance.collection('transaction_logs').add({
        'action': 'BACKUP_CREATED',
        'description':
            'Full database backup created from Admin System Settings',
        'userId': user.uid,
        'userEmail': user.email,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'backupId': backupRef.id,
          'collections': collections.length,
        },
      });

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
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  String _formatMeta(dynamic meta) {
    if (meta == null) return '';
    if (meta is String) return meta;
    if (meta is Map) {
      return meta.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
    return meta.toString();
  }

  bool _matchesDashboardBarangay(String address) {
    if (_selectedDashboardBarangay == null ||
        _selectedDashboardBarangay == 'All Barangays') {
      return true;
    }
    return address == _selectedDashboardBarangay;
  }

  Future<void> _exportSingleReportToPDF(
    Map<String, dynamic> data,
    String reportId,
  ) async {
    try {
      final pdf = pw.Document();
      final Timestamp? ts = data['dateTime'] as Timestamp?;
      final date = ts?.toDate();
      pw.ImageProvider? proofImage;
      if (data['photoUrl'] != null && (data['photoUrl'] as String).isNotEmpty) {
        try {
          final bytes = await networkImage(data['photoUrl']);
          proofImage = bytes;
        } catch (_) {
          proofImage = null;
        }
      }

      pdf.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Text(
              'Report Details',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Report ID: $reportId'),
            pw.SizedBox(height: 8),
            pw.Text('Submitted By: ${data['userName'] ?? 'Unknown'}'),
            pw.Text('User ID: ${data['userId'] ?? 'N/A'}'),
            pw.Text('Ordinance: ${data['ordinance'] ?? 'N/A'}'),
            pw.SizedBox(height: 8),
            pw.Text('Reported Person: ${data['reportedPerson'] ?? 'N/A'}'),
            pw.Text('Address: ${data['address'] ?? 'N/A'}'),
            pw.Text(
              'Date & Time: ${date != null ? DateFormat('yyyy-MM-dd hh:mm a').format(date) : 'N/A'}',
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Description:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(data['description'] ?? 'N/A'),
            pw.SizedBox(height: 12),
            if (data['actionTaken'] != null) ...[
              pw.Text(
                'Action Taken:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(data['actionTaken']),
              pw.SizedBox(height: 12),
            ],
            pw.Text('Status: ${data['status'] ?? 'Pending'}'),
            if (proofImage != null) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                'Proof Photo',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Container(
                  width: 400,
                  height: 250,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey500),
                  ),
                  child: pw.FittedBox(
                    fit: pw.BoxFit.contain,
                    child: pw.Image(proofImage),
                  ),
                ),
              ),
            ] else if (data['photoUrl'] != null) ...[
              pw.SizedBox(height: 12),
              pw.Text('Photo URL: ${data['photoUrl']}'),
            ],
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'report_$reportId.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
    }
  }

  Future<String?> _selectBarangayDialog() async {
    String? selectedBarangayId;
    final barangaysSnapshot = await FirebaseFirestore.instance
        .collection('barangays')
        .orderBy('name')
        .get();

    if (!mounted) return null;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Barangay'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: barangaysSnapshot.docs.map((doc) {
                final data = doc.data();
                final name = data['name'] ?? 'Unnamed Barangay';
                final barangayId = doc.id;
                return ListTile(
                  title: Text(name),
                  subtitle: Text(
                    'ID: $barangayId',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  onTap: () {
                    selectedBarangayId = barangayId;
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    return selectedBarangayId;
  }

  Future<void> _deleteReportRecord(
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      final photoUrl = (data['photoUrl'] ?? '').toString();
      if (photoUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(photoUrl).delete();
        } catch (_) {
          // Ignore storage deletion errors, continue deleting Firestore doc.
        }
      }

      await FirebaseFirestore.instance
          .collection('reports')
          .doc(docId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete report: $e')));
    }
  }

  void _logout() async {
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  Widget _buildStatusCard(String title, Color color, int count, IconData icon) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 32),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  static const List<Color> _pieColors = [
    Color(0xFF0A4D68),
    Color(0xFFE6871A),
    Color(0xFF1ABC9C),
    Color(0xFF9B59B6),
    Color(0xFFF39C12),
    Color(0xFF2ECC71),
    Color(0xFFE74C3C),
  ];
  static const double _chartHeight = 280;

  Widget _buildBarangayVerticalBars(List<MapEntry<String, int>> entries) {
    if (entries.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Reports per District',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'No district data available yet.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final maxCount = entries.fold<int>(
      0,
      (max, entry) => entry.value > max ? entry.value : max,
    );
    final barGroups = entries.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final color = _pieColors[index % _pieColors.length];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: item.value.toDouble(),
            color: color,
            width: 18,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports per District',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _chartHeight,
              child: BarChart(
                BarChartData(
                  maxY: maxCount == 0 ? 5 : maxCount + 1,
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      left: BorderSide(color: Colors.black12),
                      bottom: BorderSide(color: Colors.black12),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
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
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Transform.rotate(
                              angle: -0.6,
                              alignment: Alignment.center,
                              child: Text(
                                entries[index].key,
                                style: const TextStyle(fontSize: 13),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${userRole == 'barangay_official' ? "Barangay Official" : "Admin"}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('barangays')
                          .orderBy('name')
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LinearProgressIndicator(minHeight: 4);
                        }

                        final barangayNames = <String>['All Barangays'];
                        if (snapshot.hasData) {
                          barangayNames.addAll(
                            snapshot.data!.docs.map(
                              (doc) => (doc['name'] ?? 'Unnamed Barangay')
                                  .toString(),
                            ),
                          );
                        }
                        if (_selectedDashboardBarangay != null &&
                            !barangayNames.contains(
                              _selectedDashboardBarangay,
                            )) {
                          barangayNames.add(_selectedDashboardBarangay!);
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final isStacked = constraints.maxWidth < 640;
                            final barangayDropdown =
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Barangay',
                                    border: OutlineInputBorder(),
                                  ),
                                  value: _selectedDashboardBarangay,
                                  items: barangayNames
                                      .map(
                                        (name) => DropdownMenuItem(
                                          value: name,
                                          child: Text(name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedDashboardBarangay = value;
                                    });
                                  },
                                );
                            final yearDropdown = DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'Year',
                                border: OutlineInputBorder(),
                              ),
                              value: _selectedYear,
                              items: _yearOptions
                                  .map(
                                    (year) => DropdownMenuItem(
                                      value: year,
                                      child: Text(year.toString()),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedYear = value);
                              },
                            );

                            if (isStacked) {
                              return Column(
                                children: [
                                  barangayDropdown,
                                  const SizedBox(height: 12),
                                  yearDropdown,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: barangayDropdown),
                                const SizedBox(width: 16),
                                Expanded(child: yearDropdown),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Error loading dashboard data: ${snapshot.error}',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                final filteredDocsIterable =
                    (userRole == 'barangay_official' && userBarangayId != null)
                    ? docs.where(
                        (d) =>
                            (d.data()
                                as Map<
                                  String,
                                  dynamic
                                >)['assignedBarangayId'] ==
                            userBarangayId,
                      )
                    : docs;

                final filteredDocs = filteredDocsIterable.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final address = (data['address'] ?? '').toString();
                  final date = (data['dateTime'] as Timestamp?)?.toDate();
                  if (date == null) return false;
                  final matchesBarangay = _matchesDashboardBarangay(address);
                  final matchesYear = date.year == _selectedYear;
                  return matchesBarangay && matchesYear;
                }).toList();

                final pendingCount = filteredDocs
                    .where(
                      (d) =>
                          ((d.data() as Map<String, dynamic>)['status'] ?? '')
                              .toString()
                              .toLowerCase() ==
                          'pending',
                    )
                    .length;
                final onProgressCount = filteredDocs
                    .where(
                      (d) =>
                          ((d.data() as Map<String, dynamic>)['status'] ?? '')
                              .toString()
                              .toLowerCase() ==
                          'on progress',
                    )
                    .length;
                final receivedCount = filteredDocs
                    .where(
                      (d) =>
                          ((d.data() as Map<String, dynamic>)['status'] ?? '')
                              .toString()
                              .toLowerCase() ==
                          'sent',
                    )
                    .length;
                final doneCount = filteredDocs
                    .where(
                      (d) =>
                          ((d.data() as Map<String, dynamic>)['status'] ?? '')
                              .toString()
                              .toLowerCase() ==
                          'done',
                    )
                    .length;

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('barangays')
                      .get(),
                  builder: (context, barangaysSnapshot) {
                    if (barangaysSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Build barangay ID to district mapping
                    final barangayIdToDistrict = <String, String>{};
                    if (barangaysSnapshot.hasData) {
                      for (final barangayDoc in barangaysSnapshot.data!.docs) {
                        final barangayData = barangayDoc.data() as Map<String, dynamic>;
                        final district = (barangayData['district'] ??
                            barangayData['name'] ??
                            'Unknown District').toString();
                        barangayIdToDistrict[barangayDoc.id] = district;
                      }
                    }

                    final districtCounts = <String, int>{};
                    final violationTotals = <String, int>{};

                    for (final doc in filteredDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final assignedBarangayId = data['assignedBarangayId'] as String?;

                      // Get district from barangay mapping, or use address as fallback
                      String district = 'Unassigned District';
                      if (assignedBarangayId != null &&
                          barangayIdToDistrict.containsKey(assignedBarangayId)) {
                        district = barangayIdToDistrict[assignedBarangayId]!;
                      } else {
                        // Fallback: try to extract district from address
                        final address = (data['address'] ?? '').toString();
                        if (address.isNotEmpty) {
                          district = address;
                        }
                      }

                      final ordinance =
                          (data['ordinance'] ?? 'Unspecified Ordinance').toString();
                      districtCounts[district] =
                          (districtCounts[district] ?? 0) + 1;
                      violationTotals[ordinance] =
                          (violationTotals[ordinance] ?? 0) + 1;
                    }

                    final topDistricts = districtCounts.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));

                    return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Report Status Overview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatusCard(
                                    'Pending',
                                    Colors.orange,
                                    pendingCount,
                                    Icons.pending_actions,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatusCard(
                                    'On Progress',
                                    Colors.blue,
                                    onProgressCount,
                                    Icons.sync,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatusCard(
                                    'Received',
                                    Colors.purple,
                                    receivedCount,
                                    Icons.inbox,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatusCard(
                                    'Completed',
                                    Colors.green,
                                    doneCount,
                                    Icons.check_circle,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [_buildBarangayVerticalBars(topDistricts)],
                        );
                      },
                    ),
                  ],
                );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSettings() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Backup & Restore Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backup & Restore',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: (_isBackingUp || _isRestoring)
                              ? null
                              : _triggerBackup,
                          icon: _isBackingUp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.backup),
                          label: Text(
                            _isBackingUp ? 'Backing up...' : 'Backup Now',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A4D68),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _lastBackupPath == null
                              ? const Text(
                                  'Weekly backups run automatically every Monday.',
                                  style: TextStyle(color: Colors.grey),
                                )
                              : Text(
                                  'Last backup: $_lastBackupPath',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: (_isBackingUp || _isRestoring)
                          ? null
                          : _showRestoreDialog,
                      icon: _isRestoring
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore),
                      label: Text(
                        _isRestoring ? 'Restoring...' : 'Restore from Backup',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Audit Trail Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Audit Trail',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _selectedIndex = 6);
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('transaction_logs')
                          .orderBy('timestamp', descending: true)
                          .limit(10)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No audit trail entries yet.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        final logs = snapshot.data!.docs;
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: logs.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            final data = log.data() as Map<String, dynamic>;
                            final action = data['action'] ?? 'UNKNOWN';
                            final description = data['description'] ?? '';
                            final userEmail = data['userEmail'] ?? 'Unknown';
                            final timestamp = (data['timestamp'] as Timestamp?)
                                ?.toDate();

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
                              case 'USER_APPROVED':
                                icon = Icons.person_add;
                                color = Colors.green;
                                break;
                              case 'USER_REJECTED':
                                icon = Icons.person_remove;
                                color = Colors.red;
                                break;
                              default:
                                icon = Icons.info;
                                color = Colors.grey;
                            }

                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.1),
                                child: Icon(icon, size: 18, color: color),
                              ),
                              title: Text(
                                description,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                '${userEmail} • ${timestamp != null ? DateFormat('MMM dd, yyyy HH:mm').format(timestamp) : 'N/A'}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Barangay Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Barangays',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _selectedIndex = 3);
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Manage'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('barangays')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No barangays found.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        final barangays = snapshot.data!.docs;
                        final displayBarangays = barangays.length > 5
                            ? barangays.take(5).toList()
                            : barangays;

                        return Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_city,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Total Barangays: ${barangays.length}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor:
                                      MaterialStateProperty.all(Colors.grey[200]),
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'Barangay Name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Official Email',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: displayBarangays.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final name =
                                        data['name'] ?? 'Unnamed Barangay';

                                    String email = 'No email';
                                    if (data['officials'] != null &&
                                        (data['officials'] as List).isNotEmpty) {
                                      final official =
                                          (data['officials'] as List).first;
                                      email = official['email'] ?? 'No email';
                                    }

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            name,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            email,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            if (barangays.length > 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const BarangaysPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'View all ${barangays.length} barangays',
                                    ),
                                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildReportsPage() {
    Query reportsQuery = FirebaseFirestore.instance.collection('reports');

    if (userRole == 'barangay_official' && userBarangayId != null) {
      reportsQuery = reportsQuery.where(
        'assignedBarangayId',
        isEqualTo: userBarangayId,
      );
    }

    if (_selectedBarangayFilter != null &&
        _selectedBarangayFilter!.isNotEmpty &&
        _selectedBarangayFilter != 'All Barangays' &&
        _selectedBarangayFilter != 'Bacnotan (All Reports)') {
      reportsQuery = reportsQuery.where(
        'address',
        isEqualTo: _selectedBarangayFilter,
      );
    }

    reportsQuery = reportsQuery.orderBy(
      'submittedAt',
      descending: _sortNewestFirst,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All Reports',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('barangays')
                .orderBy('name')
                .get(),
            builder: (context, barangaySnapshot) {
              final barangayNames = <String>[
                'All Barangays',
                'Bacnotan (All Reports)',
              ];

              if (barangaySnapshot.hasData) {
                barangayNames.addAll(
                  barangaySnapshot.data!.docs.map(
                    (doc) => (doc['name'] ?? 'Unnamed Barangay').toString(),
                  ),
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Filter by Barangay',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedBarangayFilter,
                      items: barangayNames
                          .map(
                            (name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBarangayFilter = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      decoration: const InputDecoration(
                        labelText: 'Sort by Date',
                        border: OutlineInputBorder(),
                      ),
                      value: _sortNewestFirst,
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Text('Newest First'),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text('Oldest First'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortNewestFirst = value ?? true;
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search by ordinance or person',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchTerm = value.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _exportReportsToPDF,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export All Reports'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4D68),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _exportReportsByBarangay,
                icon: const Icon(Icons.location_city),
                label: const Text('Report by Barangay'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
              ElevatedButton.icon(
                onPressed: _exportPendingReports,
                icon: const Icon(Icons.pending_actions),
                label: const Text('Pending Reports'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
              ElevatedButton.icon(
                onPressed: _exportCompletedReports,
                icon: const Icon(Icons.check_circle),
                label: const Text('Completed Reports'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              ElevatedButton.icon(
                onPressed: _exportReportsByOrdinance,
                icon: const Icon(Icons.gavel),
                label: const Text('Report by Ordinance'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: reportsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading reports: ${snapshot.error}'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allReports = snapshot.data!.docs;
                final filteredReports = allReports.where((doc) {
                  final data = doc.data()! as Map<String, dynamic>;
                  final reportedPerson = (data['reportedPerson'] ?? '')
                      .toString()
                      .toLowerCase();
                  final ordinance = (data['ordinance'] ?? '')
                      .toString()
                      .toLowerCase();
                  final address = (data['address'] ?? '').toString();

                  if (_selectedBarangayFilter != null &&
                      _selectedBarangayFilter != 'All Barangays' &&
                      _selectedBarangayFilter != 'Bacnotan (All Reports)' &&
                      _selectedBarangayFilter!.isNotEmpty &&
                      address != _selectedBarangayFilter) {
                    return false;
                  }

                  if (_selectedBarangayFilter == 'Bacnotan (All Reports)' &&
                      !address.toLowerCase().contains('bacnotan')) {
                    return false;
                  }

                  if (_searchTerm.isEmpty) return true;

                  return reportedPerson.contains(_searchTerm) ||
                      ordinance.contains(_searchTerm);
                }).toList();

                if (filteredReports.isEmpty) {
                  return const Center(child: Text('No reports found.'));
                }

                return ListView.separated(
                  itemCount: filteredReports.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final doc = filteredReports[index];
                    final data = doc.data()! as Map<String, dynamic>;

                    final userName = data['userName'] ?? 'Unknown';
                    final ordinance = data['ordinance'] ?? 'N/A';
                    final reportedPerson = data['reportedPerson'] ?? 'N/A';
                    final address = data['address'] ?? 'N/A';
                    final description = data['description'] ?? 'N/A';
                    final Timestamp dateTimeStamp =
                        data['dateTime'] ?? Timestamp.now();
                    final dateTime = dateTimeStamp.toDate();
                    final status = (data['status'] ?? 'Pending').toString();

                    return ListTile(
                      title: Text('Ordinance: $ordinance'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reported by: $userName'),
                          Text('Person reported: $reportedPerson'),
                          Text('Address: $address'),
                          Text(
                            'Date & Time: ${DateFormat('yyyy-MM-dd hh:mm a').format(dateTime)}',
                          ),
                          Text('Description: $description'),
                          if (data['actionTaken'] != null)
                            Text(
                              'Action Taken: ${data['actionTaken']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Status: $status',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: status.toLowerCase() == 'pending'
                                  ? Colors.orange
                                  : status.toLowerCase() == 'on progress'
                                  ? Colors.blue
                                  : status.toLowerCase() == 'sent'
                                  ? Colors.purple
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: status.toLowerCase() == 'done'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.deepPurple,
                                  ),
                                  tooltip: 'Export PDF',
                                  onPressed: () =>
                                      _exportSingleReportToPDF(data, doc.id),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Delete Report',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Report'),
                                        content: const Text(
                                          'Are you sure you want to delete this report? This action cannot be undone.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await _deleteReportRecord(doc.id, data);
                                    }
                                  },
                                ),
                              ],
                            )
                          : status.toLowerCase() == 'sent'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('reports')
                                        .doc(doc.id)
                                        .update({'status': 'Done'});

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Report approved and marked Done.',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Approve'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final result = await showDialog<String>(
                                      context: context,
                                      builder: (context) {
                                        String selectedStatus = 'On Progress';
                                        return AlertDialog(
                                          title: const Text('Reject Report'),
                                          content: StatefulBuilder(
                                            builder: (context, setState) {
                                              return DropdownButtonFormField<
                                                String
                                              >(
                                                decoration: const InputDecoration(
                                                  labelText:
                                                      'Select status to send back',
                                                ),
                                                value: selectedStatus,
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: 'Pending',
                                                    child: Text('Pending'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'On Progress',
                                                    child: Text('On Progress'),
                                                  ),
                                                ],
                                                onChanged: (value) {
                                                  setState(() {
                                                    selectedStatus =
                                                        value ?? 'On Progress';
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(null),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(selectedStatus),
                                              child: const Text('Submit'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (result != null) {
                                      await FirebaseFirestore.instance
                                          .collection('reports')
                                          .doc(doc.id)
                                          .update({'status': result});

                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Report status changed to $result.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Reject'),
                                ),
                              ],
                            )
                          : PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'On Progress') {
                                  final selectedBarangayId =
                                      await _selectBarangayDialog();
                                  if (selectedBarangayId == null) return;

                                  // Get barangay name for confirmation message
                                  String barangayName = 'the selected barangay';
                                  try {
                                    final barangayDoc = await FirebaseFirestore
                                        .instance
                                        .collection('barangays')
                                        .doc(selectedBarangayId)
                                        .get();
                                    if (barangayDoc.exists) {
                                      barangayName =
                                          barangayDoc.data()?['name'] ??
                                          barangayName;
                                    }
                                  } catch (e) {
                                    // Continue even if we can't get the name
                                  }

                                  try {
                                    // Debug: Print assignment details
                                    // ignore: avoid_print
                                    print(
                                      'Admin - Assigning report ${doc.id} to barangayId: $selectedBarangayId ($barangayName)',
                                    );

                                    await FirebaseFirestore.instance
                                        .collection('reports')
                                        .doc(doc.id)
                                        .update({
                                          'status': value,
                                          'assignedBarangayId':
                                              selectedBarangayId,
                                          'assignedAt':
                                              FieldValue.serverTimestamp(),
                                        });

                                    // Verify the update
                                    final updatedDoc = await FirebaseFirestore
                                        .instance
                                        .collection('reports')
                                        .doc(doc.id)
                                        .get();
                                    final updatedAssignedId = updatedDoc
                                        .data()?['assignedBarangayId'];
                                    // ignore: avoid_print
                                    print(
                                      'Admin - Verification: Report ${doc.id} now has assignedBarangayId: $updatedAssignedId',
                                    );

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Report assigned to $barangayName successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to assign report: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } else {
                                  Map<String, dynamic> updateData = {
                                    'status': value,
                                  };
                                  if (value != 'On Progress') {
                                    updateData['assignedBarangayId'] =
                                        FieldValue.delete();
                                    updateData['assignedAt'] =
                                        FieldValue.delete();
                                  }
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('reports')
                                        .doc(doc.id)
                                        .update(updateData);

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Report status updated successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to update report: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                if (status != 'On Progress')
                                  const PopupMenuItem(
                                    value: 'On Progress',
                                    child: Text('Send to Barangay'),
                                  ),
                              ],
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'Change Status',
                            ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ReportDetailsPage(reportId: doc.id, data: data),
                          ),
                        );
                      },
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

  Widget _buildTransactionLogsPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaction Logs',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transaction_logs')
                  .orderBy('timestamp', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading logs: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No transaction logs yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                final logs = snapshot.data!.docs;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final data = logs[index].data()! as Map<String, dynamic>;
                    final timestamp = (data['timestamp'] as Timestamp?)
                        ?.toDate();
                    final formatted = timestamp != null
                        ? DateFormat('MMM d, yyyy • hh:mm a').format(timestamp)
                        : 'No date';
                    // Derive display values that support both the
                    // DatabaseManagementPage schema (action/description/metadata)
                    // and any older type/message/meta schema.
                    final action = (data['action'] ?? data['type'] ?? 'LOG')
                        .toString();
                    Color iconColor;
                    switch (action) {
                      case 'BACKUP_CREATED':
                      case 'BACKUP_CREATED_CLOUD':
                        iconColor = Colors.blue;
                        break;
                      case 'BACKUP_RESTORED':
                        iconColor = Colors.green;
                        break;
                      case 'BACKUP_DELETED':
                        iconColor = Colors.red;
                        break;
                      default:
                        iconColor = Colors.deepOrange;
                    }

                    final titleText =
                        (data['description'] ?? data['message'] ?? action)
                            .toString();
                    final metaValue = data['metadata'] ?? data['meta'];
                    final userEmail = data['userEmail'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      child: ListTile(
                        leading: Icon(Icons.receipt_long, color: iconColor),
                        title: Text(
                          titleText,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              formatted,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (userEmail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'By: $userEmail',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: metaValue != null
                            ? SizedBox(
                                width: 140,
                                child: Text(
                                  _formatMeta(metaValue),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              )
                            : null,
                        isThreeLine: userEmail.isNotEmpty || metaValue != null,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const OrdinanceAddScreen();
      case 2:
        return const BarangaysPage();
      case 3:
        return const AcceptUsersPage();
      case 4:
        return _buildReportsPage();
      case 5:
        return _buildSystemSettings();
      case 6:
        return _buildTransactionLogsPage();
      default:
        return _buildDashboard();
    }
  }

  // Build permanent sidebar
  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFF0A4D68)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 40,
                        color: Color(0xFF0A4D68),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isSidebarOpen = false;
                        });
                      },
                      tooltip: 'Close Sidebar',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Admin Panel',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Dashboard'),
                  selected: _selectedIndex == 0,
                  selectedTileColor: Colors.orange.withOpacity(0.1),
                  onTap: () {
                    setState(() => _selectedIndex = 0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('Complaints'),
                  selected: _selectedIndex == 4,
                  selectedTileColor: Colors.orange.withOpacity(0.1),
                  onTap: () {
                    setState(() => _selectedIndex = 4);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.book),
                  title: const Text('Ordinances'),
                  selected: _selectedIndex == 1,
                  selectedTileColor: Colors.orange.withOpacity(0.1),
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('System Settings'),
                  selected: _selectedIndex == 5,
                  selectedTileColor: Colors.orange.withOpacity(0.1),
                  onTap: () {
                    setState(() => _selectedIndex = 5);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Transaction Log'),
                  selected: _selectedIndex == 6,
                  selectedTileColor: Colors.orange.withOpacity(0.1),
                  onTap: () {
                    setState(() => _selectedIndex = 6);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.location_city),
                  title: const Text('Barangay'),
                  selected: _selectedIndex == 2,
                  selectedTileColor: Colors.orange.withOpacity(0.1),
                  onTap: () {
                    setState(() => _selectedIndex = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('User'),
                  selected: _selectedIndex == 3,
                  selectedTileColor: Colors.orange.withOpacity(0.1),
                  onTap: () {
                    setState(() => _selectedIndex = 3);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFFFF9800),
        leading: _isSidebarOpen
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  setState(() {
                    _isSidebarOpen = true;
                  });
                },
                tooltip: 'Open Sidebar',
              ),
        automaticallyImplyLeading: false,
      ),
      body: Row(
        children: [
          if (_isSidebarOpen) _buildSidebar(),
          Expanded(child: _getBody()),
        ],
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
    final Timestamp dateTimeStamp = data['dateTime'] ?? Timestamp.now();
    final dateTime = dateTimeStamp.toDate();

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

            const SizedBox(height: 12),
            Text(
              'Description:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(data['description'] ?? 'N/A'),

            // IMAGE DISPLAY
            if (data['photoUrl'] != null &&
                data['photoUrl'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Uploaded Photo:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                  errorBuilder: (context, error, stackTrace) {
                    final photoUrl = data['photoUrl'].toString();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, size: 50, color: Colors.red),
                        const SizedBox(height: 8),
                        const Text(
                          "Failed to load image",
                          style: TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          photoUrl,
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Row(
                children: const [
                  Icon(Icons.image_not_supported, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'No photo available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],

            // ... existing code below ...
            const SizedBox(height: 12),

            if (data['actionTaken'] != null) ...[
              const Text(
                'Action Taken:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(data['actionTaken']),
              const SizedBox(height: 12),
            ],

            Text(
              'Status: ${data['status'] ?? 'Pending'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
