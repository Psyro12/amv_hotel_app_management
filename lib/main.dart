import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'preloader_screen.dart'; // 🟢 Import the new Preloader
import 'notification_service.dart';

// 🟢 Background message handler must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,

  );

  // 🟢 Initialize Notifications
  await NotificationService.initialize();
  
  // 🟢 Set background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'AMV Hotel',
    
    // 🟢 1. START HERE
    // We removed AuthWrapper. The Preloader now handles the logic!
    home: PreloaderScreen(), 
  ));
}