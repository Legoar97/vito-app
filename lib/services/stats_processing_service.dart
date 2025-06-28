import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class StatsProcessingService {
  /// Combina los streams de hábitos y estados de ánimo en uno solo para la pantalla de estadísticas.
  static Stream<List<QuerySnapshot>> getHabitsAndMoodsStream() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      // Devuelve snapshots vacíos si no hay usuario para evitar errores en la UI.
      return Stream.value([EmptyQuerySnapshot(), EmptyQuerySnapshot()]);
    }

    final habitsStream = FirebaseFirestore.instance.collection('users').doc(userId).collection('habits').snapshots();
    final moodsStream = FirebaseFirestore.instance.collection('users').doc(userId).collection('moods').snapshots();

    // StreamZip combina los últimos eventos de cada stream en una lista.
    return StreamZip([habitsStream, moodsStream]);
  }

  /// Procesa la lista de documentos de hábitos para calcular todas las estadísticas necesarias.
  static Map<String, dynamic> processStats(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return {
        'totalHabits': 0,
        'overallCompletionRate': 0.0,
        'weeklySpots': List.generate(7, (i) => FlSpot(i.toDouble(), 0)),
        'categoryPerformance': {},
        'habitPerformance': [],
      };
    }

    int totalCompletions = 0;
    int possibleCompletions = 0;
    Map<String, List<int>> categoryCompletions = {}; // [completados, posibles]

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final completionsMap = Map<String, dynamic>.from(data['completions'] ?? {});
      final days = List<int>.from(data['days'] ?? []);
      final createdAt = (data['createdAt'] as Timestamp).toDate();
      final category = data['category'] as String? ?? 'Otros';
      
      // Contar completados y posibles
      completionsMap.values.forEach((completionData) {
        if (completionData['completed'] == true) {
          totalCompletions++;
        }
      });
      
      int daysSinceCreation = DateTime.now().difference(createdAt).inDays;
      for (int i = 0; i <= daysSinceCreation; i++) {
        final date = createdAt.add(Duration(days: i));
        if (days.contains(date.weekday)) {
          possibleCompletions++;
        }
      }
      
      // Rendimiento por categoría
      categoryCompletions.putIfAbsent(category, () => [0, 0]);
      completionsMap.forEach((dateKey, completionData) {
         if (completionData['completed'] == true) {
           categoryCompletions[category]![0]++;
         }
      });
      categoryCompletions[category]![1] = possibleCompletions; // Asumiendo que possibleCompletions es por hábito
    }

    final double overallCompletionRate = possibleCompletions > 0 ? (totalCompletions / possibleCompletions) * 100 : 0.0;

    // Datos para el gráfico semanal
    final weeklySpots = List.generate(7, (index) {
      final day = DateTime.now().subtract(Duration(days: 6 - index));
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      int completionsOnDay = 0;
      int activeHabitsOnDay = 0;

      for(var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final days = List<int>.from(data['days'] ?? []);
        if (days.contains(day.weekday)) {
          activeHabitsOnDay++;
          final completionsMap = Map<String, dynamic>.from(data['completions'] ?? {});
          if (completionsMap[dateKey]?['completed'] == true) {
            completionsOnDay++;
          }
        }
      }
      final rate = activeHabitsOnDay > 0 ? (completionsOnDay / activeHabitsOnDay) * 100 : 0.0;
      return FlSpot(index.toDouble(), rate);
    });

    // Top 3 hábitos por rendimiento
    final habitPerformance = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final completionsMap = Map<String, dynamic>.from(data['completions'] ?? {});
      final days = List<int>.from(data['days'] ?? []);
      final createdAt = (data['createdAt'] as Timestamp).toDate();

      int possible = 0;
      int completedCount = 0;
      int daysSinceCreation = DateTime.now().difference(createdAt).inDays;
      for (int i = 0; i <= daysSinceCreation; i++) {
        final date = createdAt.add(Duration(days: i));
        if (days.contains(date.weekday)) {
          possible++;
        }
      }
      completionsMap.values.forEach((val) {
        if (val['completed'] == true) completedCount++;
      });
      
      final rate = possible > 0 ? (completedCount / possible) * 100 : 0.0;
      return {'name': data['name'], 'rate': rate.toInt()};
    }).toList();
    habitPerformance.sort((a, b) => b['rate']!.compareTo(a['rate']!));

    return {
      'totalHabits': docs.length,
      'overallCompletionRate': overallCompletionRate,
      'weeklySpots': weeklySpots,
      'categoryPerformance': categoryCompletions,
      'habitPerformance': habitPerformance.take(3).toList(),
    };
  }

  /// Procesa la lista de documentos de moods para calcular estadísticas de ánimo.
  static Map<String, dynamic> processMoodStats(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return {
        'moodCounts': <String, int>{},
        'mostFrequentMood': null,
        'maxCount': 0,
        'totalDays': 0,
      };
    }

    final moodCounts = <String, int>{};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final moodValue = data['mood'] as String?;
      if (moodValue != null) {
        moodCounts[moodValue] = (moodCounts[moodValue] ?? 0) + 1;
      }
    }

    String? mostFrequentMood;
    int maxCount = 0;
    moodCounts.forEach((m, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequentMood = m;
      }
    });

    return {
      'moodCounts': moodCounts,
      'mostFrequentMood': mostFrequentMood,
      'maxCount': maxCount,
      'totalDays': docs.length,
    };
  }

  /// Genera un informe de texto conciso para la IA de Vito.
  static Future<String> getWellnessReportForAI() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return "El usuario no está disponible.";

    final habitsSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('habits').get();
    final moodsSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('moods').orderBy('timestamp', descending: true).limit(30).get();

    final stats = processStats(habitsSnapshot.docs);
    final moodStats = processMoodStats(moodsSnapshot.docs);

    final rate = stats['overallCompletionRate'].toStringAsFixed(0);
    final topHabit = (stats['habitPerformance'] as List).isNotEmpty ? (stats['habitPerformance'].first['name']) : 'ninguno en particular';
    final frequentMood = moodStats['mostFrequentMood'] ?? 'no registrado';

    return '''
      Informe de Bienestar del Usuario:
      - Tasa de completado general de hábitos: $rate%.
      - Su hábito más consistente es: "$topHabit".
      - Su estado de ánimo más frecuente últimamente ha sido: "$frequentMood".
      - Total de hábitos activos: ${stats['totalHabits']}.
    ''';
  }
}

// Clase auxiliar para manejar el caso de que no haya usuario y evitar errores de null.
class EmptyQuerySnapshot implements QuerySnapshot {
  @override
  List<QueryDocumentSnapshot> get docs => [];
  @override
  List<DocumentChange> get docChanges => [];
  @override
  SnapshotMetadata get metadata => throw UnimplementedError();
  @override
  int get size => 0;
}