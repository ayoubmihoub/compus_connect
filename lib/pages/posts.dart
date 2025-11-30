// posts.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
// 🔑 استيراد الدوال المشتركة من user_home.dart (deletePost, fetchUsername, formatPostDate)
// يجب تعديل هذا المسار ليناسب هيكل مشروعك إذا لزم الأمر
import 'user_home.dart';

// ==========================================================
// 1. الصفحة الرئيسية لإدارة المنشورات (PostsPage)
// ==========================================================

class PostsPage extends StatelessWidget {
  const PostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // جلب جميع المنشورات، مرتبة حسب الأحدث
      stream: FirebaseFirestore.instance
          .collection('posts')
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

        // عرض المنشورات
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot document = snapshot.data!.docs[index];
            Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

            return AdminPostCard(
              data: data,
              documentId: document.id,
            );
          },
        );
      },
    );
  }
}

// ==========================================================
// 2. ويدجت لعرض منشور في لوحة المسؤول (AdminPostCard)
// ==========================================================

class AdminPostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String documentId;

  const AdminPostCard({
    super.key,
    required this.data,
    required this.documentId,
  });

  // دالة تأكيد الحذف
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression (Admin)'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cette publication de force ?'),
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
                // استدعاء دالة الحذف العامة من user_home.dart
                deletePost(documentId, context);
              },
            ),
          ],
        );
      },
    );
  }

  // دالة عرض الصورة المشفرة Base64 (مستوحاة من PostCard)
  Widget _buildMedia(Map<String, dynamic> data) {
    final String mediaBase64 = data['mediaData'] ?? '';
    final String mediaType = data['mediaType'] ?? 'none';

    if (mediaType == 'image' && mediaBase64.isNotEmpty) {
      try {
        final Uint8List decodedBytes = base64Decode(mediaBase64);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
          child: Image.memory(
            decodedBytes,
            height: 250,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(height: 250, color: Colors.red[100], child: const Center(child: Text('Erreur d\'affichage Base64'))),
          ),
        );
      } catch (e) {
        return const SizedBox.shrink();
      }
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    // جلب البيانات
    final String description = data['description'] ?? 'Pas de description';
    final String postUserId = data['userId'] ?? '';
    final int likesCount = List<String>.from(data['likes'] ?? []).length;
    final int commentCount = data['commentCount'] ?? 0;
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      elevation: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // --- HEADER: اسم المستخدم وزر الحذف الإجباري ---
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0, right: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FutureBuilder<String>(
                  future: fetchUsername(postUserId),
                  builder: (context, snapshot) {
                    String username = snapshot.data ?? 'Chargement...';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@$username (Admin View)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                              fontSize: 14
                          ),
                        ),
                        Text(
                          'UID: $postUserId',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    );
                  },
                ),
                // زر الحذف الإجباري للمسؤول
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: () => _confirmDelete(context),
                  tooltip: 'Supprimer cette publication de force',
                ),
              ],
            ),
          ),

          _buildMedia(data), // عرض الصورة (إن وجدت)

          // --- DESCRIPTION ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),
          ),

          const Divider(),

          // --- STATS (Like/Comment Counts) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('❤ $likesCount J\'aime', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                Text('💬 $commentCount Commentaires', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // --- FOOTER: التاريخ ---
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0, top: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  formatPostDate(createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}