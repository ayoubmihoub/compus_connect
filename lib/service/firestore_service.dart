import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Récupère le nombre total de documents dans une collection donnée.
  // La signature retourne Future<int>, garantissant une valeur non-nullable.
  Future<int> getCollectionCount(String collectionPath) async {
    try {
      AggregateQuerySnapshot snapshot =
      await _db.collection(collectionPath).count().get();

      // CORRECTION: Utilise ?? 0 pour garantir un int (non-nullable)
      // car snapshot.count peut être nullable (int?).
      return snapshot.count ?? 0;

    } catch (e) {
      print('Erreur lors de la récupération du compte pour $collectionPath: $e');
      return 0; // Retourne 0 en cas d'erreur
    }
  }
}

// Instance du service pour un accès facile
final FirestoreService firestoreService = FirestoreService();