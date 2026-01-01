import 'package:cloud_firestore/cloud_firestore.dart';

class Entry {
  final String id;
  final String userId;
  final DateTime date;
  final double sales;
  final double expenditure;
  final double profit;
  final String notes;

  Entry({
    required this.id,
    required this.userId,
    required this.date,
    required this.sales,
    required this.expenditure,
    required this.profit,
    this.notes = '',
  });

  factory Entry.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Safely handle the date field
    DateTime entryDate;
    if (data['date'] is Timestamp) {
      entryDate = (data['date'] as Timestamp).toDate();
    } else {
      entryDate = DateTime.now(); // Fallback
    }

    return Entry(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      date: entryDate,
      sales: double.tryParse(data['sales']?.toString() ?? '0.0') ?? 0.0,
      expenditure: double.tryParse(data['expenditure']?.toString() ?? '0.0') ?? 0.0,
      profit: double.tryParse(data['profit']?.toString() ?? '0.0') ?? 0.0,
      notes: data['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'sales': sales,
      'expenditure': expenditure,
      'profit': profit,
      'notes': notes,
    };
  }
}
