// users.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================================
// 1. الصفحة الرئيسية لإدارة المستخدمين (UsersPage)
// ==========================================================

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // جلب جميع وثائق المستخدمين من مجموعة 'users'
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucun utilisateur trouvé.'));
        }

        // عرض البيانات في قائمة
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot userDoc = snapshot.data!.docs[index];
            Map<String, dynamic> userData = userDoc.data()! as Map<String, dynamic>;
            final String userId = userDoc.id; // UID هو معرف الوثيقة

            return UserTile(userData: userData, userId: userId);
          },
        );
      },
    );
  }
}

// ==========================================================
// 2. ويدجت لعرض معلومات مستخدم واحد (UserTile)
// ==========================================================

class UserTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String userId;

  const UserTile({
    super.key,
    required this.userData,
    required this.userId,
  });

  // دالة لحذف وثيقة المستخدم من Firestore
  Future<void> _deleteUserFromFirestore(BuildContext context, String targetUserId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(targetUserId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Utilisateur ${userData['username']} supprimé de Firestore.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: $e')),
      );
    }
  }

  // دالة تأكيد الحذف
  void _confirmAndDeleteUser(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text('Êtes-vous sûr de vouloir supprimer l\'utilisateur @${userData['username']} ?'),
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
                _deleteUserFromFirestore(context, userId);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String username = userData['username'] ?? userData['email'] ?? 'Utilisateur inconnu';
    final String email = userData['email'] ?? 'Email non fourni';
    final String role = userData['role'] ?? 'user';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: role == 'admin' ? Colors.red.shade700 : Colors.blueAccent,
          child: Text(
              username[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
          ),
        ),
        title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: const TextStyle(fontSize: 12)),
            Text(
                'Rôle: $role',
                style: TextStyle(
                    color: role == 'admin' ? Colors.red.shade700 : Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 13
                )
            ),
          ],
        ),
        // زر الحذف
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmAndDeleteUser(context),
          tooltip: 'Supprimer cet utilisateur',
        ),
      ),
    );
  }
}