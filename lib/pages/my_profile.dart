// my_profile.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔑 Import nécessaire pour reauthenticate
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'user_home.dart';
import '../service/auth_service.dart';

// ==========================================================
// 1. PAGE PRINCIPALE (MyProfilePage)
// ==========================================================

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final User? currentUser = authService.value.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(child: Text('Erreur: Utilisateur non connecté.'));
    }
    final String currentUserId = currentUser!.uid;

    return Column(
      children: <Widget>[
        // 🔑 1. ويدجت رأس الملف الشخصي القابل للتعديل
        ProfileHeader(userId: currentUserId, email: currentUser!.email),

        const Divider(thickness: 1, height: 1),

        // 2. عنوان منشوراتي
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Mes Publications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        // 3. عرض المنشورات
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
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Vous n\'avez publié aucun post.'));
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
// 2. WIDGET DE L'ENTÊTE (ProfileHeader) - مع منطق التعديل وتحديث كلمة المرور
// ==========================================================

class ProfileHeader extends StatefulWidget {
  final String userId;
  final String? email;

  const ProfileHeader({super.key, required this.userId, this.email});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  // 🔑 جلب بيانات المستخدم من Firestore لاسم المستخدم والصورة
  Future<DocumentSnapshot> _fetchUserData() {
    return FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
  }

  // 🔑 دالة تحديث البيانات (الاسم والصورة) وكلمة المرور
  void _showEditProfileModal(BuildContext context, Map<String, dynamic> currentData) {
    final TextEditingController usernameController = TextEditingController(text: currentData['username'] ?? '');

    // 🔑 حقول كلمة المرور الجديدة
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();

    XFile? _selectedImage;
    Uint8List? _previewImageBytes;

    final String currentBase64Image = currentData['profilePicture'] ?? '';
    if (currentBase64Image.isNotEmpty) {
      try {
        _previewImageBytes = base64Decode(currentBase64Image);
      } catch (e) {
        _previewImageBytes = null; // فشل في فك التشفير
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {

            // دالة لاختيار الصورة
            Future<void> pickImage() async {
              final ImagePicker picker = ImagePicker();
              final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

              if (pickedFile != null) {
                final bytes = await pickedFile.readAsBytes();
                setModalState(() {
                  _selectedImage = pickedFile;
                  _previewImageBytes = bytes;
                });
              }
            }

            // دالة حفظ التحديثات
            Future<void> saveChanges() async {
              final String newUsername = usernameController.text.trim();
              final String newPassword = newPasswordController.text.trim();
              final String currentPassword = currentPasswordController.text.trim();

              if (newUsername.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez entrer un nom d\'utilisateur.')),
                );
                return;
              }

              // --- 1. تحديث الصورة ---
              String newProfilePictureBase64 = currentBase64Image;

              if (_selectedImage != null) {
                final bytes = await _selectedImage!.readAsBytes();
                newProfilePictureBase64 = base64Encode(bytes);
                // 🛑 تحقق من الحجم
                if (newProfilePictureBase64.length > 500000) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ الصورة كبيرة جداً (Max ~350KB). التحديث ألغي.')),
                  );
                  return;
                }
              }

              // --- 2. تحديث كلمة المرور (إذا تم إدخال كلمة مرور جديدة) ---
              if (newPassword.isNotEmpty) {
                if (currentPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez entrer le mot de passe actuel pour changer le mot de passe.')),
                  );
                  return;
                }
                if (newPassword.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nouveau mot de passe doit contenir au moins 6 caractères.')),
                  );
                  return;
                }

                try {
                  // إعادة المصادقة أولاً
                  AuthCredential credential = EmailAuthProvider.credential(
                    email: widget.email!,
                    password: currentPassword,
                  );
                  await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(credential);

                  // تحديث كلمة المرور
                  await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mot de passe mis à jour.')),
                  );
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur de mot de passe: Mot de passe actuel invalide ou: ${e.code}')),
                  );
                  return;
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur inattendue lors de la mise à jour du mot de passe: $e')),
                  );
                  return;
                }
              }

              // --- 3. تحديث الاسم والصورة في Firestore ---
              try {
                await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                  'username': newUsername,
                  'profilePicture': newProfilePictureBase64,
                });
                await authService.value.currentUser!.updateDisplayName(newUsername);

                // تحديث واجهة MyProfilePage
                if (mounted) {
                  setState(() {});
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil mis à jour avec succès!')),
                );

              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur de mise à jour du profil: $e')),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('Modifier le Profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // اختيار الصورة
                    GestureDetector(
                      onTap: pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blueAccent,
                        backgroundImage: _previewImageBytes != null
                            ? MemoryImage(_previewImageBytes!) as ImageProvider<Object>?
                            : null,
                        child: _previewImageBytes == null
                            ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
                            : null,
                      ),
                    ),
                    TextButton(
                      onPressed: pickImage,
                      child: const Text('Changer la photo'),
                    ),

                    // حقل اسم المستخدم
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom d\'utilisateur',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- قسم تغيير كلمة المرور ---
                    const Text('Changer le Mot de Passe (Optionnel)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe actuel',
                        prefixIcon: Icon(Icons.lock_open),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe (min 6 caractères)',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // زر الحفظ
                    ElevatedButton(
                      onPressed: saveChanges,
                      child: const Text('Enregistrer les changements'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🔑 البنية الرئيسية لـ ProfileHeader
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _fetchUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(height: 150, color: Colors.grey[100], child: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data?.data() == null) {
          return Container(height: 150, color: Colors.red[100], child: const Center(child: Text('Erreur de chargement du profil.')));
        }

        final userData = snapshot.data!.data()! as Map<String, dynamic>;
        final String username = userData['username'] ?? 'Utilisateur Campus';
        final String profilePictureBase64 = userData['profilePicture'] ?? '';
        Uint8List? decodedBytes;

        if (profilePictureBase64.isNotEmpty) {
          try {
            decodedBytes = base64Decode(profilePictureBase64);
          } catch (e) {
            decodedBytes = null;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16.0),
          width: double.infinity,
          color: Colors.grey[100],
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blueAccent,
                backgroundImage: decodedBytes != null
                    ? MemoryImage(decodedBytes!) as ImageProvider<Object>?
                    : null,
                child: decodedBytes == null
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                '@$username',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                widget.email ?? 'Email inconnu',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 10),
              // زر التعديل
              ElevatedButton.icon(
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Modifier le Profil'),
                onPressed: () => _showEditProfileModal(context, userData),
              ),
            ],
          ),
        );
      },
    );
  }
}