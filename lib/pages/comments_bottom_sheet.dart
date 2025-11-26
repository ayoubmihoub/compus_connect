// comments_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Assurez-vous que les fonctions fetchUsername et formatPostDate sont accessibles
import 'user_home.dart';

// ==========================================================
// 1. الشاشة السفلية الرئيسية للتعليقات
// ==========================================================
class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String currentUserId;

  const CommentsBottomSheet({
    Key? key,
    required this.postId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // 🔑 إضافة التعليق إلى Firestore
  Future<void> _addComment() async {
    final String commentText = _commentController.text.trim();

    if (commentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter un commentaire.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. إضافة التعليق في المجموعة الفرعية 'comments'
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'userId': widget.currentUserId,
        'comment': commentText,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. تحديث عداد التعليقات في المنشور الرئيسي (Post)
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({'commentCount': FieldValue.increment(1)});

      _commentController.clear();
      // لا نعرض SnackBar لعدم إزعاج المستخدم أثناء الكتابة المستمرة

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ajout du commentaire: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        height: screenHeight * 0.75, // تأخذ 75% من الشاشة
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: <Widget>[
            // شريط العنوان
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Commentaires',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // 2. قائمة التعليقات
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Aucun commentaire. Soyez le premier !'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot commentDoc = snapshot.data!.docs[index];
                      Map<String, dynamic> commentData = commentDoc.data()! as Map<String, dynamic>;

                      return CommentTile(commentData: commentData);
                    },
                  );
                },
              ),
            ),

            // 3. منطقة إدخال تعليق جديد
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Ajouter un commentaire...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ==========================================================
// 2. ويدجت لعرض كل تعليق
// ==========================================================
class CommentTile extends StatelessWidget {
  final Map<String, dynamic> commentData;

  const CommentTile({Key? key, required this.commentData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String userId = commentData['userId'] ?? '';
    final String commentText = commentData['comment'] ?? 'Commentaire supprimé';
    final Timestamp? createdAt = commentData['createdAt'] as Timestamp?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CircleAvatar(
            radius: 18,
            child: Icon(Icons.person, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // اسم المستخدم والوقت
                FutureBuilder<String>(
                  future: fetchUsername(userId),
                  builder: (context, snapshot) {
                    String username = snapshot.data ?? 'Chargement...';
                    return Text(
                      '@$username',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent),
                    );
                  },
                ),

                // نص التعليق
                Text(commentText, style: const TextStyle(fontSize: 15)),

                // التاريخ
                if (createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      formatPostDate(createdAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
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