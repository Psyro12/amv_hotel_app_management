import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'preloader_screen.dart'; // 🟢 Import the new Preloader

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'AMV Hotel',
    
    // 🟢 1. START HERE
    // We removed AuthWrapper. The Preloader now handles the logic!
    home: PreloaderScreen(), 
  ));
}