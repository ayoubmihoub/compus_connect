import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import '../service/auth_service.dart';
import 'my_profile.dart';

// ==========================================================
// 1. FONCTIONS UTILITAIRES GLOBALES
// ==========================================================

// Fonction pour formater un Timestamp en chaîne de caractères lisible
String formatPostDate(Timestamp? timestamp) {
  if (timestamp == null) {
    return 'Date inconnue';
  }

  DateTime date = timestamp.toDate();

  if (date.day == DateTime.now().day &&
      date.month == DateTime.now().month &&
      date.year == DateTime.now().year) {
    return 'Aujourd\'hui à ${DateFormat('HH:mm').format(date)}';
  }

  return DateFormat('d MMMM yyyy à HH:mm', 'fr').format(date);
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

// Fonction pour récupérer le nom d'utilisateur à partir de l'UID
Future<String> fetchUsername(String userId) async {
  if (userId.isEmpty) return 'Utilisateur Inconnu';
  try {
    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (userDoc.exists && userDoc.data() != null) {
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      return userData['username'] ?? userData['email'] ?? 'Utilisateur Inconnu';
    }
    return 'Utilisateur Inconnu';
  } catch (e) {
    return 'Profil Supprimé';
  }
}


// ==========================================================
// 2. CLASSE PRINCIPALE (UserHomePage)
// ==========================================================

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions = <Widget>[
    const HomeFeedContent(),
    const MyProfilePage(),
  ];

  Future<void> _logout() async {
    await authService.value.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // MÉTHODE BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Fil d\'Actualité' : 'Mon Profil'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),

      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Mon Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }
}

// ==========================================================
// 3. CONTENU DU FIL D'ACTUALITÉ (HomeFeedContent)
// ==========================================================

class HomeFeedContent extends StatelessWidget {
  const HomeFeedContent({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = authService.value.currentUser?.uid ?? '';

    return Column(
      children: <Widget>[
        // 1. Zone de Création de Post
        const PostCreationZone(),

        const Divider(height: 10, thickness: 1),

        // 2. Affichage des Posts Publiés
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('posts')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Aucun post à afficher.'));
              }

              return ListView(
                children: snapshot.data!.docs.map((DocumentSnapshot document) {
                  Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
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

// ==========================================================
// 4. ZONE DE CRÉATION DE POST (PostCreationZone)
// ==========================================================

class PostCreationZone extends StatefulWidget {
  const PostCreationZone({super.key});

  @override
  State<PostCreationZone> createState() => _PostCreationZoneState();
}

class _PostCreationZoneState extends State<PostCreationZone> {
  final TextEditingController _descriptionController = TextEditingController();
  XFile? _selectedMedia;
  String? _mediaType;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _showMediaSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Choisir une Photo (Image)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery, 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Vidéo (Bloqué - Limite 1MB)'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🛑 Le stockage de vidéo est bloqué : fichier trop volumineux pour Firestore (max 1MB).')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickMedia(ImageSource source, String type) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    setState(() {
      _selectedMedia = pickedFile;
      _mediaType = 'image';
    });
  }

  Future<void> _publishPost() async {
    final String description = _descriptionController.text.trim();

    if (description.isEmpty && _selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter une description ou un média.')),
      );
      return;
    }

    final String? currentUserId = authService.value.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: Utilisateur non connecté pour publier.')),
      );
      return;
    }

    String mediaBase64 = '';

    if (_selectedMedia != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Encodage et vérification de la taille...')),
      );

      try {
        final bytes = await _selectedMedia!.readAsBytes();

        mediaBase64 = base64Encode(bytes);

        if (mediaBase64.length > 1000000) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Image trop grande (Max ~700KB original). Publication annulée.')),
          );
          return;
        }

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'encodage du média: $e')),
        );
        return;
      }
    }

    Map<String, dynamic> postData = {
      'description': description,
      'userId': currentUserId,
      'mediaData': mediaBase64,
      'mediaType': mediaBase64.isNotEmpty ? 'image' : 'none',
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('posts').add(postData);

      _descriptionController.clear();
      setState(() {
        _selectedMedia = null;
        _mediaType = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post publié avec succès !')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de publication Firestore (Vérifiez la limite 1MB): $e')),
      );
    }
  }

  Widget _buildSelectedMediaPreview() {
    if (_selectedMedia == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _mediaType == 'image' ? 'Image sélectionnée.' : 'Vidéo sélectionnée.',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedMedia = null;
                _mediaType = null;
              });
            },
            child: const Text('Retirer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // MÉTHODE BUILD CORRIGÉE
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: <Widget>[
            TextFormField(
              controller: _descriptionController,
              // 🔑 C'EST ICI QUE LA HAUTEUR EST DIMINUÉE À 2 LIGNES
              maxLines: 1,
              decoration: const InputDecoration(
                hintText: 'Quoi de neuf sur le campus ?',
                border: OutlineInputBorder(
                    borderSide: BorderSide.none
                ),
                filled: true,
                fillColor: Color(0xFFF3F3F3),
              ),
            ),
            const SizedBox(height: 10),

            _buildSelectedMediaPreview(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                TextButton.icon(
                  onPressed: _showMediaSourceDialog,
                  icon: const Icon(Icons.add_a_photo, color: Colors.green),
                  label: const Text('Photo/Vidéo'),
                ),

                ElevatedButton.icon(
                  onPressed: _publishPost,
                  icon: const Icon(Icons.send),
                  label: const Text('Publier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// 5. WIDGET D'AFFICHAGE (PostCard)
// ==========================================================

class PostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String documentId;
  final String currentUserId;

  const PostCard({
    super.key,
    required this.data,
    required this.documentId,
    required this.currentUserId,
  });

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
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
    final bool canDelete = postUserId == currentUserId;

    // Décodage de l'image Base64
    Uint8List? decodedBytes;
    if (mediaBase64.isNotEmpty && (data['mediaType'] ?? 'none') == 'image') {
      try {
        decodedBytes = base64Decode(mediaBase64);
      } catch (e) {
        // Ignorer l'erreur
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      elevation: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[

          // --- HEADER: Nom d'utilisateur et Bouton Supprimer ---
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0, right: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Affichage asynchrone du nom d'utilisateur
                FutureBuilder<String>(
                  future: fetchUsername(postUserId),
                  builder: (context, snapshot) {
                    String username = snapshot.data ?? 'Chargement...';
                    return Text(
                      '@$username',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                          fontSize: 14
                      ),
                    );
                  },
                ),

                // Bouton de suppression conditionnel
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(context),
                    tooltip: 'Supprimer cette publication',
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),

          // --- MÉDIA ---
          if (decodedBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
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

          // --- FOOTER: Date de publication ---
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0, top: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  formatPostDate(createdAt), // Affichage de la date
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