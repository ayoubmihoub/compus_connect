import 'package:compus_connect/pages/login.dart';
import 'package:compus_connect/pages/page_welcome.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/firebase_options.dart';
import 'pages/signup.dart';
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

      },
    );
  }
}


