import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NOUVEL IMPORT

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance; // INSTANCE FIRESTORE

  User? get currentUser => firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password
    );
  }

  // Fonction de création de compte MODIFIÉE pour ajouter 'username' et le rôle dans Firestore
  Future<UserCredential> createAccount({
    required String email,
    required String password,
    required String username, // NOUVEL ARGUMENT
  }) async {
    UserCredential userCredential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password
    );

    // Écriture du profil utilisateur dans Firestore avec le rôle par défaut 'user'
    if (userCredential.user != null) {
      // 1. Enregistrer les données de l'utilisateur dans Firestore
      await _db.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'username': username,
        'role': 'user', // RÔLE PAR DÉFAUT
        'createdAt': FieldValue.serverTimestamp(),
      });
      // 2. Mettre à jour le nom d'affichage Firebase Auth
      await userCredential.user!.updateDisplayName(username);
    }
    return userCredential;
  }

  // Fonction pour récupérer le rôle depuis Firestore (utilisée dans le login)
  Future<String> getUserRole() async {
    if (currentUser == null) {
      return 'guest';
    }
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['role'] ?? 'user';
      }
      return 'user';
    } catch (e) {
      print("Erreur de récupération de rôle: $e");
      return 'error';
    }
  }

  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  Future<void> resetPassword({
    required String email,
  }) async {
    await firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateUsername({
    required String username,
  }) async {
    await currentUser!.updateDisplayName(username);
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.delete();
    await firebaseAuth.signOut();
  }
}