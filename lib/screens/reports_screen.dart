import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/entry_provider.dart';
import '../models/entry_model.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateFilter _reportFilter = DateFilter.last30Days;
  DateTimeRange? _reportCustomRange;
  int _currentPage = 0;
  final int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EntryProvider>(context);
    final allEntries = provider.allEntries;
    
    // Independent filtering for Reports tab
    List<Entry> reportEntries = _applyIndependentFilter(allEntries);
    
    // Pagination logic
    final totalEntries = reportEntries.length;
    final totalPages = (totalEntries / _pageSize).ceil();
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize > totalEntries) ? totalEntries : startIndex + _pageSize;
    final paginatedEntries = reportEntries.isEmpty ? [] : reportEntries.sublist(startIndex, endIndex);

    return Column(
      children: [
        _buildFilterChips(),
        _buildExportButtons(context, reportEntries),
        Expanded(
          child: totalEntries == 0
              ? const Center(child: Text("No entries found for this period."))
              : ListView.builder(
                  itemCount: paginatedEntries.length,
                  itemBuilder: (context, index) {
                    final entry = paginatedEntries[index];
                    return Card(
                      key: ValueKey(entry.id),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: entry.profit >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(
                            entry.profit >= 0 ? Icons.trending_up : Icons.trending_down,
                            color: entry.profit >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          DateFormat.yMMMd().format(entry.date),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Profit: ₹${entry.profit.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: entry.profit >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _detailRow("Sales:", "₹${entry.sales.toStringAsFixed(2)}"),
                                const SizedBox(height: 8),
                                _detailRow("Expenditure:", "₹${entry.expenditure.toStringAsFixed(2)}"),
                                const SizedBox(height: 8),
                                _detailRow("Profit:", "₹${entry.profit.toStringAsFixed(2)}", 
                                    valueColor: entry.profit >= 0 ? Colors.green : Colors.red),
                                const Divider(height: 24),
                                const Text("Notes", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
                                const SizedBox(height: 4),
                                Text(
                                  entry.notes.isEmpty ? "No notes for this entry." : entry.notes,
                                  style: TextStyle(fontStyle: entry.notes.isEmpty ? FontStyle.italic : FontStyle.normal),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showEditDialog(context, entry, provider),
                                      icon: const Icon(Icons.edit, color: Colors.orange),
                                      label: const Text("EDIT", style: TextStyle(color: Colors.orange)),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _showDeleteDialog(context, entry, provider),
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      label: const Text("DELETE", style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (totalPages > 1) _buildPagination(totalPages),
      ],
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  List<Entry> _applyIndependentFilter(List<Entry> allEntries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<Entry> filtered = [];

    switch (_reportFilter) {
      case DateFilter.today:
        filtered = allEntries.where((e) {
          final d = DateTime(e.date.year, e.date.month, e.date.day);
          return d.isAtSameMomentAs(today);
        }).toList();
        break;
      case DateFilter.last7Days:
        final sevenDaysAgo = today.subtract(const Duration(days: 7));
        filtered = allEntries.where((e) => e.date.isAfter(sevenDaysAgo)).toList();
        break;
      case DateFilter.last30Days:
        final thirtyDaysAgo = today.subtract(const Duration(days: 30));
        filtered = allEntries.where((e) => e.date.isAfter(thirtyDaysAgo)).toList();
        break;
      case DateFilter.custom:
        if (_reportCustomRange != null) {
          filtered = allEntries.where((e) {
            return e.date.isAfter(_reportCustomRange!.start.subtract(const Duration(seconds: 1))) &&
                   e.date.isBefore(_reportCustomRange!.end.add(const Duration(days: 1)));
          }).toList();
        }
        break;
    }
    filtered.sort((a, b) => b.date.compareTo(a.date)); // Newest first for reports
    return filtered;
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: DateFilter.values.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter.name.toUpperCase()),
                selected: _reportFilter == filter,
                onSelected: (selected) async {
                  if (filter == DateFilter.custom) {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (range != null) {
                      setState(() {
                        _reportFilter = filter;
                        _reportCustomRange = range;
                        _currentPage = 0;
                      });
                    }
                  } else {
                    setState(() {
                      _reportFilter = filter;
                      _currentPage = 0;
                    });
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
          ),
          Text("Page ${_currentPage + 1} of $totalPages", style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildExportButtons(BuildContext context, List<Entry> entries) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _exportToPDF(context, entries),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("PDF"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _exportToExcel(context, entries),
              icon: const Icon(Icons.table_chart),
              label: const Text("Excel"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Entry entry, EntryProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Entry"),
        content: Text("Are you sure you want to delete the entry for ${DateFormat.yMMMd().format(entry.date)}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              try {
                await provider.deleteEntry(entry.id);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Entry deleted successfully"), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Entry entry, EntryProvider provider) {
    final formKey = GlobalKey<FormState>();
    double sales = entry.sales;
    double expenditure = entry.expenditure;
    String notes = entry.notes;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Entry"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: sales.toString(),
                  decoration: const InputDecoration(labelText: "Sales", prefixText: "₹ "),
                  keyboardType: TextInputType.number,
                  onSaved: (val) => sales = double.parse(val!),
                ),
                TextFormField(
                  initialValue: expenditure.toString(),
                  decoration: const InputDecoration(labelText: "Expenditure", prefixText: "₹ "),
                  keyboardType: TextInputType.number,
                  onSaved: (val) => expenditure = double.parse(val!),
                ),
                TextFormField(
                  initialValue: notes,
                  decoration: const InputDecoration(labelText: "Notes"),
                  maxLines: 3,
                  onSaved: (val) => notes = val ?? "",
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                final updatedEntry = Entry(
                  id: entry.id,
                  userId: entry.userId,
                  date: entry.date,
                  sales: sales,
                  expenditure: expenditure,
                  profit: sales - expenditure,
                  notes: notes,
                );
                try {
                  await provider.updateEntry(updatedEntry);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Entry updated successfully"), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text("UPDATE"),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPDF(BuildContext context, List<Entry> entries) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text("Business Analytics Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Sales (INR)', 'Exp (INR)', 'Profit (INR)', 'Notes'],
                data: entries.map((e) => [
                  DateFormat('dd/MM/yyyy').format(e.date),
                  e.sales.toStringAsFixed(2),
                  e.expenditure.toStringAsFixed(2),
                  e.profit.toStringAsFixed(2),
                  e.notes
                ]).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _exportToExcel(BuildContext context, List<Entry> entries) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Sheet1'];

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Sales (INR)'),
      TextCellValue('Expenditure (INR)'),
      TextCellValue('Profit (INR)'),
      TextCellValue('Notes'),
    ]);
    
    for (var e in entries) {
      sheet.appendRow([
        TextCellValue(DateFormat('dd/MM/yyyy').format(e.date)),
        DoubleCellValue(e.sales),
        DoubleCellValue(e.expenditure),
        DoubleCellValue(e.profit),
        TextCellValue(e.notes),
      ]);
    }

    final fileBytes = excel.save();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/business_report.xlsx');
    await file.writeAsBytes(fileBytes!);
    
    await Share.shareFiles([file.path], text: 'Business Analytics Report');
  }
}
