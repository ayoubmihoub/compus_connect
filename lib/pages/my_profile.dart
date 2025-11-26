// my_profile.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
// 🔑 IMPORT DES FONCTIONS UTILITAIRES ET POSTCARD DE USER_HOME
import 'user_home.dart';
import '../service/auth_service.dart';

// 🔑 NOTE: FONCTIONS UTILITAIRES (formatPostDate, deletePost, fetchUsername)
// SONT DÉSORMAIS IMPORTÉES DE 'user_home.dart'.

// ==========================================================
// 1. PAGE PRINCIPALE (MyProfilePage)
// ==========================================================

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final User? currentUser = authService.value.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Erreur: Utilisateur non connecté.'));
    }
    final String currentUserId = currentUser.uid;

    return Column(
      children: <Widget>[
        // Zone d'en-tête du profil
        Container(
          padding: const EdgeInsets.all(16.0),
          width: double.infinity,
          color: Colors.grey[100],
          child: Column(
            children: [

              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 10),

              Text(
                currentUser.email ?? 'Utilisateur Campus',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Mon Profil',

                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),

        const Divider(thickness: 1, height: 1),

        // Affichage des Posts Filtrés
        const Padding(

          padding: EdgeInsets.all(8.0),
          child: Text(
            'Mes Publications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance

                .collection('posts')
                .where('userId', isEqualTo: currentUserId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {

                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erreur lors du chargement des posts: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Vous n\'avez publié aucun post.'));
              }

              // Liste des posts de l'utilisateur
              return ListView(
                children: snapshot.data!.docs.map((DocumentSnapshot document) {
                  Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

                  // 🔑 UTILISATION DU WIDGET PostCard (qui gère Likes/Comments/Delete)
                  return PostCard(
                    data: data,
                    documentId: document.id,
                    currentUserId: currentUserId,
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

// 🔑 CLASSE MyProfilePostCard PRÉCÉDENTE (DE L'INPUT) SUPPRIMÉE ET REMPLACÉE PAR PostCard IMPORTÉE.