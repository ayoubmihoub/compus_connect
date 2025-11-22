// ... imports existants (login, page_welcome, firebase_options, signup, user_home, admin_home)
import 'package:compus_connect/pages/login.dart';
import 'package:compus_connect/pages/page_welcome.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/firebase_options.dart';
import 'pages/signup.dart';
import 'pages/user_home.dart';
import 'pages/admin_home.dart';
import 'pages/my_profile.dart'; // NOUVEL IMPORT

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Compus Connect",
      initialRoute: '/',
      routes: {
        '/signup': (context) => const SignUpPage(),
        '/': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/user_home': (context) => const UserHomePage(),
        '/admin_home': (context) => const AdminHomePage(),
        '/my_profile': (context) => const MyProfilePage(), // NOUVELLE ROUTE (Optionnel si vous voulez naviguer directement)
      },
    );
  }
}