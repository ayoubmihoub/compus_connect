// admi_home.dart

import 'package:flutter/material.dart';
import '../service/auth_service.dart';
import '../service/firestore_service.dart';
import 'users.dart'; // Import des pages (Gestion des Utilisateurs)
import 'posts.dart'; // Import des pages (Gestion des Posts)
import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================================
// 1. CLASSE PRINCIPALE (AdminHomePage)
// ==========================================================
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  // 🔑 تم إزالة const لحل مشكلة 'Not a constant expression'
  late final List<Widget> _widgetOptions = <Widget>[
    DashboardContent(), // Index 0: Tableau de bord
    const UsersPage(),  // Index 1: Page Utilisateurs
    const PostsPage(),  // Index 2: Page Posts
  ];

  final List<String> _titles = ['Dashboard', 'Gestion des Utilisateurs', 'Gestion des Posts']; // [cite: 107]

  // Fonction pour gérer la déconnexion
  Future<void> _logout() async {
    await authService.value.signOut(); // [cite: 109]
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false); // [cite: 110]
    }
  }

  // Builder pour la barre الجانبية (Drawer)
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.red,
            ),
            child: Text(
              'Menu Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ), // [cite: 111-112]
          // Bouton Dashboard (Accueil)
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: _selectedIndex == 0,
            onTap: () {
              setState(() {
                _selectedIndex = 0;
              });
              Navigator.pop(context); // [cite: 113]
            },
          ),
          // Bouton Users
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Users'),
            selected: _selectedIndex == 1,
            onTap: () {
              setState(() {
                _selectedIndex = 1; // [cite: 115]
              });
              Navigator.pop(context);
            },
          ),
          // Bouton Posts
          ListTile(
            leading: const Icon(Icons.article),
            title: const Text('Posts'),
            selected: _selectedIndex == 2,
            onTap: () {
              setState(() {
                _selectedIndex = 2; // [cite: 116]
              });
              Navigator.pop(context);
            },
          ),
          const Divider(),
          // Bouton Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: _logout, // [cite: 117]
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.red,
      ),
      drawer: _buildDrawer(),
      body: _widgetOptions.elementAt(_selectedIndex), // [cite: 119]
    );
  }
}

// ==========================================================
// 2. CONTENU DU TABLEAU DE BORD (DashboardContent)
// ==========================================================

class DashboardContent extends StatelessWidget {
  DashboardContent({super.key});

  // جلب عدد المستخدمين والمنشورات
  final Future<int> _userCount = firestoreService.getCollectionCount('users'); // [cite: 120]
  final Future<int> _postCount = firestoreService.getCollectionCount('posts'); // [cite: 121]

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0), // [cite: 122]
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Statistiques Générales (temps réel)',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Cartes pour les statistiques
          Row(
            children: <Widget>[
              Expanded(
                child: FutureCountCard(
                  futureCount: _userCount,
                  title: 'Total Utilisateurs', // [cite: 123]
                  icon: Icons.people_alt,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: FutureCountCard(
                  futureCount: _postCount,
                  title: 'Total Posts', // [cite: 124]
                  icon: Icons.article_outlined,
                  color: Colors.green, // [cite: 125]
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          // Autres sections
          const Text(
            'Autres Analyses...',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ), // [cite: 126]
          const SizedBox(height: 10),
          Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(child: Text('Zone de graphiques ou rapports')), // [cite: 127]
          )
        ],
      ),
    );
  }
}

// ==========================================================
// 3. WIDGET FutureCountCard (لعرض الإحصائيات)
// ==========================================================

class FutureCountCard extends StatelessWidget {
  final Future<int> futureCount; // [cite: 129]
  final String title;
  final IconData icon;
  final Color color;

  const FutureCountCard({
    super.key,
    required this.futureCount,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // [cite: 130]
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: FutureBuilder<int>(
          future: futureCount,
          builder: (context, snapshot) {
            String value;
            Color indicatorColor = color; // [cite: 131]
            Widget indicator = const SizedBox.shrink();

            if (snapshot.connectionState == ConnectionState.waiting) {
              value = '...';
              indicator = SizedBox(
                width: 20,
                height: 20, // [cite: 132]
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              );
            } else if (snapshot.hasError) {
              value = 'Erreur';
              indicatorColor = Colors.red;
              indicator = const Icon(Icons.error, size: 20, color: Colors.red); // [cite: 133]
            } else {
              value = snapshot.data.toString(); // [cite: 134]
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 40, color: color), // [cite: 135]
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 36, // [cite: 136]
                        fontWeight: FontWeight.bold,
                        color: indicatorColor,
                      ), // [cite: 137]
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, color: Colors.grey), // [cite: 138]
                ),
                indicator,
              ],
            );
          },
        ),
      ), // [cite: 139]
    );
  }
}