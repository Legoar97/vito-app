import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart'; // Asegúrate de que este import sea correcto.

/// Un servicio para centralizar todas las operaciones de Firestore
/// relacionadas con los hábitos y perfiles de usuario.
class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Propiedades de Acceso ---

  static String? get currentUserId => _auth.currentUser?.uid;
  static CollectionReference get _usersCollection => _firestore.collection('users');

  static CollectionReference? get _habitsCollection {
    final userId = currentUserId;
    if (userId == null) return null;
    return _usersCollection.doc(userId).collection('habits');
  }

  // --- Métodos de Perfil de Usuario ---

  static Future<void> createOrUpdateUserProfile({
    required String userId,
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    final userData = {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'lastActive': FieldValue.serverTimestamp(),
      ...?additionalData,
    };
    
    final userDocRef = _usersCollection.doc(userId);
    final userDoc = await userDocRef.get();

    if (!userDoc.exists) {
      userData['createdAt'] = FieldValue.serverTimestamp();
    }

    await userDocRef.set(
      userData,
      SetOptions(merge: true),
    );
  }

  static Future<DocumentSnapshot> getUserProfile(String userId) async {
    return await _usersCollection.doc(userId).get();
  }

  static Stream<DocumentSnapshot> streamUserProfile(String userId) {
    return _usersCollection.doc(userId).snapshots();
  }

  // --- Métodos CRUD de Hábitos ---

  static Future<String> createHabit(Habit habit) async {
    final habitsCollection = _habitsCollection;
    if (habitsCollection == null) throw Exception('Usuario no autenticado');
    final docRef = await habitsCollection.add(habit.toMap());
    return docRef.id;
  }

  static Future<void> updateHabit(String habitId, Map<String, dynamic> data) async {
    final habitsCollection = _habitsCollection;
    if (habitsCollection == null) throw Exception('Usuario no autenticado');
    await habitsCollection.doc(habitId).update(data);
  }

  static Future<void> deleteHabit(String habitId) async {
    final habitsCollection = _habitsCollection;
    if (habitsCollection == null) throw Exception('Usuario no autenticado');
    await habitsCollection.doc(habitId).delete();
  }

  static Future<DocumentSnapshot> getHabit(String habitId) async {
    final habitsCollection = _habitsCollection;
    if (habitsCollection == null) throw Exception('Usuario no autenticado');
    return await habitsCollection.doc(habitId).get();
  }

  // --- Streams de Hábitos ---

  static Stream<QuerySnapshot>? streamHabits() {
    final habitsCollection = _habitsCollection;
    if (habitsCollection == null) return null;
    return habitsCollection.orderBy('createdAt', descending: false).snapshots();
  }

  static Stream<QuerySnapshot>? streamHabitsForDay(int weekday) {
    final habitsCollection = _habitsCollection;
    if (habitsCollection == null) return null;
    return habitsCollection
        .where('days', arrayContains: weekday)
        .orderBy('specificTime.hour')
        .orderBy('specificTime.minute')
        .snapshots();
  }

  static Stream<QuerySnapshot>? streamHabitsByCategory(String category) {
    final habitsCollection = _habitsCollection;
    if (habitsCollection == null) return null;
    return habitsCollection
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // --- Lógica de Interacción con Hábitos ---

  /// Marca/desmarca un hábito y actualiza la racha de forma atómica usando una transacción.
  static Future<void> toggleHabitCompletion(String habitId, DateTime date) async {
    final habitsCollection = _habitsCollection;
    if (habitsCollection == null) throw Exception('Usuario no autenticado');

    final habitDocRef = habitsCollection.doc(habitId);

    // Se usa una transacción para asegurar que la lectura, modificación y escritura
    // de los datos del hábito ocurra como una sola operación indivisible.
    // Esto previene errores si el usuario interactúa muy rápido con la app.
    await _firestore.runTransaction((transaction) async {
      final habitDoc = await transaction.get(habitDocRef);
      if (!habitDoc.exists) {
        throw Exception("Hábito no encontrado.");
      }

      final habitData = habitDoc.data() as Map<String, dynamic>;
      final completions = List<Timestamp>.from(habitData['completions'] ?? []);
      
      final dateOnly = DateTime(date.year, date.month, date.day);
      final isCompleted = completions.any((ts) => _isSameDay(ts.toDate(), dateOnly));

      if (isCompleted) {
        completions.removeWhere((ts) => _isSameDay(ts.toDate(), dateOnly));
      } else {
        completions.add(Timestamp.fromDate(dateOnly));
      }
      
      // --- Lógica de cálculo de racha (integrada en la transacción) ---
      
      completions.sort((a, b) => a.toDate().compareTo(b.toDate()));
    
      int currentStreak = 0;
      if (completions.isNotEmpty) {
        currentStreak = 1;
        // Se itera hacia atrás para contar los días consecutivos.
        for (int i = completions.length - 1; i > 0; i--) {
          final date1 = completions[i].toDate();
          final date2 = completions[i - 1].toDate();
          if (date1.difference(date2).inDays == 1) {
            currentStreak++;
          } else if (date1.difference(date2).inDays > 1) {
            // Si hay un hueco de más de 1 día, la racha se rompe.
            break; 
          }
        }

        // Se verifica si la racha actual sigue activa (si el último día completado no fue hoy ni ayer).
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final lastCompletionDate = completions.last.toDate();
        if (today.difference(lastCompletionDate).inDays > 1) {
          currentStreak = 0;
        }
      }
      
      int longestStreak = habitData['longestStreak'] as int? ?? 0;
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
      
      // Se actualizan todos los campos relacionados en la misma transacción.
      transaction.update(habitDocRef, {
        'completions': completions,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      });
    });
  }

  /// Calcula y devuelve un mapa con estadísticas generales del usuario.
  static Future<Map<String, dynamic>> getStatistics() async {
    // (Este método no necesita cambios, su lógica es correcta)
    final habitsCollection = _habitsCollection;
    if (habitsCollection == null) {
      return {
        'totalHabitsToday': 0,
        'completedToday': 0,
        'completionRate': 0.0,
        'overallLongestStreak': 0,
        'categoryBreakdown': <String, int>{},
      };
    }

    final habitsSnapshot = await habitsCollection.get();
    final habits = habitsSnapshot.docs;
    
    int totalHabitsToday = 0;
    int completedToday = 0;
    int overallLongestStreak = 0;
    final categoryBreakdown = <String, int>{};
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayWeekday = today.weekday;
    
    for (final habitDoc in habits) {
      final data = habitDoc.data() as Map<String, dynamic>;
      final days = List<int>.from(data['days'] ?? []);

      if (days.contains(todayWeekday)) {
        totalHabitsToday++;
        final category = data['category'] as String? ?? 'Otros';
        categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + 1;

        final completions = List<Timestamp>.from(data['completions'] ?? []);
        if (completions.any((ts) => _isSameDay(ts.toDate(), today))) {
          completedToday++;
        }
      }

      final longestStreak = data['longestStreak'] as int? ?? 0;
      if (longestStreak > overallLongestStreak) {
        overallLongestStreak = longestStreak;
      }
    }

    final completionRate = totalHabitsToday > 0 ? (completedToday / totalHabitsToday) * 100 : 0.0;

    return {
      'totalHabitsToday': totalHabitsToday,
      'completedToday': completedToday,
      'completionRate': completionRate,
      'overallLongestStreak': overallLongestStreak,
      'categoryBreakdown': categoryBreakdown,
    };
  }

  // --- Funciones Auxiliares ---

  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}
