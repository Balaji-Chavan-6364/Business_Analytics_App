import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/entry_model.dart';
import '../services/firestore_service.dart';

enum DateFilter { today, last7Days, last30Days, custom }

class EntryProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Entry> _allEntries = [];
  List<Entry> _filteredEntries = [];
  bool _isLoading = true;
  StreamSubscription<List<Entry>>? _subscription;
  DateFilter _currentFilter = DateFilter.last7Days;
  DateTimeRange? _customDateRange;

  List<Entry> get entries => _filteredEntries;
  List<Entry> get allEntries => _allEntries;
  bool get isLoading => _isLoading;
  DateFilter get currentFilter => _currentFilter;

  EntryProvider() {
    _init();
  }

  void _init() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _subscribeToEntries(user.uid);
      } else {
        _allEntries = [];
        _filteredEntries = [];
        _subscription?.cancel();
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  void _subscribeToEntries(String userId) {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _firestoreService.getEntries(userId).listen((newEntries) {
      _allEntries = newEntries;
      _applyFilter();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      print("Error fetching entries: $error");
      _isLoading = false;
      notifyListeners();
    });
  }

  void setFilter(DateFilter filter, {DateTimeRange? customRange}) {
    _currentFilter = filter;
    _customDateRange = customRange;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_currentFilter) {
      case DateFilter.today:
        _filteredEntries = _allEntries.where((e) {
          final d = DateTime(e.date.year, e.date.month, e.date.day);
          return d.isAtSameMomentAs(today);
        }).toList();
        break;
      case DateFilter.last7Days:
        final sevenDaysAgo = today.subtract(const Duration(days: 7));
        _filteredEntries = _allEntries.where((e) => e.date.isAfter(sevenDaysAgo)).toList();
        break;
      case DateFilter.last30Days:
        final thirtyDaysAgo = today.subtract(const Duration(days: 30));
        _filteredEntries = _allEntries.where((e) => e.date.isAfter(thirtyDaysAgo)).toList();
        break;
      case DateFilter.custom:
        if (_customDateRange != null) {
          _filteredEntries = _allEntries.where((e) {
            return e.date.isAfter(_customDateRange!.start.subtract(const Duration(seconds: 1))) &&
                   e.date.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }
        break;
    }
    _filteredEntries.sort((a, b) => a.date.compareTo(b.date));
  }

  // KPI Calculations
  double get totalSales => _filteredEntries.fold(0.0, (sum, item) => sum + item.sales);
  double get totalExpenditure => _filteredEntries.fold(0.0, (sum, item) => sum + item.expenditure);
  double get totalProfit => totalSales - totalExpenditure;

  Entry? get todayEntry {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    try {
      return _allEntries.firstWhere((e) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        return d.isAtSameMomentAs(today);
      });
    } catch (_) {
      return null;
    }
  }

  Entry? get yesterdayEntry {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    try {
      return _allEntries.firstWhere((e) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        return d.isAtSameMomentAs(yesterday);
      });
    } catch (_) {
      return null;
    }
  }

  double get profitTrend {
    final today = todayEntry?.profit ?? 0.0;
    final yesterday = yesterdayEntry?.profit ?? 0.0;
    if (yesterday == 0) return today > 0 ? 100.0 : 0.0;
    return ((today - yesterday) / yesterday.abs()) * 100;
  }

  Future<void> addEntry(Entry entry) async {
    await _firestoreService.addEntry(entry);
  }

  Future<void> updateEntry(Entry entry) async {
    await _firestoreService.updateEntry(entry);
  }

  Future<void> deleteEntry(String id) async {
    await _firestoreService.deleteEntry(id);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
