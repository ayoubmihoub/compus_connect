import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart'; // 🔑 IMPORTANT: Ajoutez 'intl: ^0.18.1' (ou version récente) dans pubspec.yaml
import '../service/auth_service.dart';


// ==========================================================
// 1. FONCTIONS UTILITAIRES
// ==========================================================

// Fonction pour formater un Timestamp en chaîne de caractères lisible
String formatPostDate(Timestamp? timestamp) {
  if (timestamp == null) {
    return 'Date inconnue';
  }

  // Convertir le Timestamp en DateTime
  DateTime date = timestamp.toDate();

  // Si le post a été créé aujourd'hui, afficher l'heure
  if (date.day == DateTime.now().day &&
      date.month == DateTime.now().month &&
      date.year == DateTime.now().year) {
    return 'Aujourd\'hui à ${DateFormat('HH:mm').format(date)}';
  }

  // Sinon, afficher la date complète
  return DateFormat('d MMMM yyyy à HH:mm', 'fr').format(date);
  // 💡 NOTE: 'fr' pour le français nécessite d'ajouter 'intl: ^0.18.1' dans pubspec.yaml
}

// Logique de suppression d'un document Firestore
void deletePost(String postId, BuildContext context) async {
  try {
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post supprimé avec succès.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur lors de la suppression du post: $e')),
    );
  }
}


// ==========================================================
// 2. PAGE PRINCIPALE (MyProfilePage)
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
                  return MyProfilePostCard(
                    data: data,
                    documentId: document.id,
                    currentUserId: currentUserId,
                    // 🔑 On passe l'email de l'utilisateur comme "username" par défaut.
                    currentUsername: currentUser.email ?? 'Utilisateur Inconnu',
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

// ==========================================================
// 3. WIDGET D'AFFICHAGE DE POSTS (MyProfilePostCard)
// ==========================================================

class MyProfilePostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String documentId;
  final String currentUserId;
  final String currentUsername; // Nom d'utilisateur de l'utilisateur connecté

  const MyProfilePostCard({
    super.key,
    required this.data,
    required this.documentId,
    required this.currentUserId,
    required this.currentUsername,
  });

  // Affiche une boîte de dialogue de confirmation avant la suppression
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cette publication ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                deletePost(documentId, context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String description = data['description'] ?? 'Pas de description';
    final String postUserId = data['userId'] ?? '';
    final String mediaBase64 = data['mediaData'] ?? '';
    final Timestamp? createdAt = data['createdAt'] as Timestamp?; // 🔑 RÉCUPÉRATION DU TIMESTAMP

    // Pour l'affichage sur la page de profil, on utilise le username de l'utilisateur courant
    // car le post lui appartient (confirmé par la requête Firestore)
    final String usernameToDisplay = currentUsername;

    // Décodage de la chaîne Base64 en bytes affichables (pour l'image)
    Uint8List? decodedBytes;
    if (mediaBase64.isNotEmpty && (data['mediaType'] ?? 'none') == 'image') {
      try {
        decodedBytes = base64Decode(mediaBase64);
      } catch (e) {
        // Ignorer l'erreur, decodedBytes restera null
      }
    }

    final bool canDelete = postUserId == currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      elevation: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // --- HEADER: Bouton Supprimer ---
          if (canDelete)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(context),
                    tooltip: 'Supprimer cette publication',
                  ),
                ],
              ),
            ),

          // --- MÉDIA ---
          if (decodedBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Image.memory(
                decodedBytes,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(height: 250, color: Colors.red[100], child: const Center(child: Text('Erreur d\'affichage Base64'))),
              ),
            ),

          // --- DESCRIPTION ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),
          ),

          // 🔑 --- FOOTER: USERNAME et DATE (NOUVELLE SECTION) ---
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Username
                Text(
                  '@${usernameToDisplay}',
                  style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12
                  ),
                ),
                // Date de publication
                Text(
                  formatPostDate(createdAt), // Utilisation de la fonction utilitaire
                  style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}