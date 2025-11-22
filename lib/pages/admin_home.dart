import 'package:flutter/material.dart';
import '../service/auth_service.dart';
import '../service/firestore_service.dart'; // NOUVEL IMPORT
import 'users.dart'; // Import des pages
import 'posts.dart'; // Import des pages

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  // Liste des widgets/pages pour la zone de contenu principale
  late final List<Widget> _widgetOptions = <Widget>[
    DashboardContent(), // Index 0: Tableau de bord
    const UsersPage(),  // Index 1: Page Utilisateurs
    const PostsPage(),  // Index 2: Page Posts
  ];

  // Noms pour la barre d'application
  final List<String> _titles = ['Dashboard', 'Gestion des Utilisateurs', 'Gestion des Posts'];

  // Fonction pour gérer la déconnexion
  Future<void> _logout() async {
    await authService.value.signOut();
    if (mounted) {
      // Naviguer vers la page de bienvenue et supprimer toutes les routes
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  // Builder pour la barre latérale de navigation
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
          ),
          // Bouton Dashboard (Accueil)
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: _selectedIndex == 0,
            onTap: () {
              setState(() {
                _selectedIndex = 0;
              });
              Navigator.pop(context);
            },
          ),
          // Bouton Users
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Users'),
            selected: _selectedIndex == 1,
            onTap: () {
              setState(() {
                _selectedIndex = 1;
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
                _selectedIndex = 2;
              });
              Navigator.pop(context);
            },
          ),
          const Divider(),
          // Bouton Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: _logout,
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
        // Le bouton du Drawer est géré automatiquement par Scaffold si le Drawer est présent
      ),
      drawer: _buildDrawer(),
      body: _widgetOptions.elementAt(_selectedIndex),
    );
  }
}

// Widget séparé pour le contenu du Tableau de Bord (Dashboard)
class DashboardContent extends StatelessWidget {
  DashboardContent({super.key});

  final Future<int> _userCount = firestoreService.getCollectionCount('users');
  // NOTE: 'posts' est une collection hypothétique que vous devrez créer dans Firestore
  final Future<int> _postCount = firestoreService.getCollectionCount('posts');

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
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
                  title: 'Total Utilisateurs',
                  icon: Icons.people_alt,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: FutureCountCard(
                  futureCount: _postCount,
                  title: 'Total Posts',
                  icon: Icons.article_outlined,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          // Autres sections du tableau de bord ici
          const Text(
            'Autres Analyses...',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(child: Text('Zone de graphiques ou rapports')),
          )
        ],
      ),
    );
  }
}

// Widget réutilisable pour afficher les données asynchrones de Firestore
class FutureCountCard extends StatelessWidget {
  final Future<int> futureCount;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: FutureBuilder<int>(
          future: futureCount,
          builder: (context, snapshot) {
            String value;
            Color indicatorColor = color;
            Widget indicator = const SizedBox.shrink();

            if (snapshot.connectionState == ConnectionState.waiting) {
              value = '...';
              indicator = SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              );
            } else if (snapshot.hasError) {
              value = 'Erreur';
              indicatorColor = Colors.red;
              indicator = const Icon(Icons.error, size: 20, color: Colors.red);
            } else {
              value = snapshot.data.toString();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 40, color: color),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: indicatorColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                indicator,
              ],
            );
          },
        ),
      ),
    );
  }
}