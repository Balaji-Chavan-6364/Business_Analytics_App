import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/entry_model.dart';
import '../providers/entry_provider.dart';
import '../services/user_service.dart';
import 'package:intl/intl.dart';

class AddEntryScreen extends StatefulWidget {
  final VoidCallback? onSuccess;

  const AddEntryScreen({
    super.key,
    this.onSuccess,
  });

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _salesController = TextEditingController();
  final TextEditingController _expController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final UserService _userService = UserService();

  @override
  void dispose() {
    _salesController.dispose();
    _expController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((pickedDate) {
      if (pickedDate == null) return;
      setState(() => _selectedDate = pickedDate);
    });
  }

  void _submitData() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<EntryProvider>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Check if entry for this date already exists
        final existingEntry = provider.allEntries.any((e) => 
          e.date.year == _selectedDate.year && 
          e.date.month == _selectedDate.month && 
          e.date.day == _selectedDate.day
        );

        if (existingEntry) {
          final proceed = await _showDuplicateWarning();
          if (!proceed) return;
        }

        final profile = await _userService.getUserProfile(user.uid);
        if (profile == null) {
          _showErrorPopup("Please setup your business profile in Settings first.");
          return;
        }

        final sales = double.tryParse(_salesController.text) ?? 0.0;
        final expenditure = double.tryParse(_expController.text) ?? 0.0;
        
        final newEntry = Entry(
          id: '',
          userId: user.uid,
          date: _selectedDate,
          sales: sales,
          expenditure: expenditure,
          profit: sales - expenditure,
          notes: _notesController.text,
        );

        try {
          await provider.addEntry(newEntry);
          
          if (mounted) {
            _showSuccessPopup();
            _salesController.clear();
            _expController.clear();
            _notesController.clear();
            setState(() {
              _selectedDate = DateTime.now();
            });
          }
        } catch (e) {
          if (mounted) _showErrorPopup(e.toString());
        }
      }
    }
  }

  Future<bool> _showDuplicateWarning() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.yellow.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning, color: isDark ? Colors.orangeAccent : Colors.orange),
            const SizedBox(width: 10),
            Text(
              "Duplicate Entry",
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        content: Text(
          "An entry for this date already exists. Do you want to add another one?",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "CANCEL",
              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("YES, PROCEED"),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text("Success"),
          ],
        ),
        content: const Text("Your entry has been saved successfully."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onSuccess != null) {
                widget.onSuccess!();
              }
            },
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text("Error"),
          ],
        ),
        content: Text("Failed to save entry: $message"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              children: [
                Text("Date: ${DateFormat.yMd().format(_selectedDate)}", style: const TextStyle(fontSize: 16)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _presentDatePicker,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Change", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _salesController,
              decoration: InputDecoration(
                labelText: "Today's Sales",
                prefixText: "₹ ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              validator: (val) => val!.isEmpty ? 'Please enter sales' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _expController,
              decoration: InputDecoration(
                labelText: "Expenditure",
                prefixText: "₹ ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              validator: (val) => val!.isEmpty ? 'Please enter expenditure' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: "Notes",
                hintText: "E.g. High sales due to holiday...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _submitData,
              child: const Text("Save Entry", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
