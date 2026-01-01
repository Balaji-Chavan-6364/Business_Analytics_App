import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/entry_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addEntry(Entry entry) {
    return _db.collection('entries').add(entry.toMap());
  }

  Stream<List<Entry>> getEntries(String userId) {
    return _db
        .collection('entries')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Entry.fromFirestore(doc)).toList());
  }

  Future<void> updateEntry(Entry entry) {
    return _db.collection('entries').doc(entry.id).update(entry.toMap());
  }

  Future<void> deleteEntry(String entryId) {
    return _db.collection('entries').doc(entryId).delete();
  }
}
