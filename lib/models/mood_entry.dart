import 'package:cloud_firestore/cloud_firestore.dart';

class MoodEntry {
  final String id;
  final String mood;
  final String? journalEntry;
  final String? aiResponse;
  final DateTime timestamp;
  final DateTime? nextCheckIn;

  MoodEntry({
    required this.id,
    required this.mood,
    this.journalEntry,
    this.aiResponse,
    required this.timestamp,
    this.nextCheckIn,
  });

  factory MoodEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MoodEntry(
      id: doc.id,
      mood: data['mood'] ?? '',
      journalEntry: data['journalEntry'],
      aiResponse: data['aiResponse'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      nextCheckIn: data['nextCheckIn'] != null 
          ? (data['nextCheckIn'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'mood': mood,
      'journalEntry': journalEntry,
      'aiResponse': aiResponse,
      'timestamp': Timestamp.fromDate(timestamp),
      'nextCheckIn': nextCheckIn != null 
          ? Timestamp.fromDate(nextCheckIn!) 
          : null,
    };
  }
}