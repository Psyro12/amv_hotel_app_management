import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'api_config.dart';
import 'notification_service.dart';

class UserSyncService {
  
  static Future<void> syncUserToMySQL(User user, {String? manualEmail, String provider = 'email'}) async {
    // 🟢 ENSURE THIS MATCHES YOUR FOLDER STRUCTURE
    final String url = "${ApiConfig.baseUrl}/api_user_sync.php";
    
    String emailToSend = manualEmail ?? user.email ?? "";
    String nameToSend = user.displayName ?? "Guest User";
    String photoToSend = user.photoURL ?? "";
    String uidToSend = user.uid;
    
    // 🟢 GET FCM TOKEN
    String? fcmToken = await NotificationService.getToken();

    print("----------------------------------------");
    print("🚀 ATTEMPTING SYNC TO: $url");
    print("📧 Email: $emailToSend");
    print("🔑 FCM Token: ${fcmToken != null ? 'RECEIVED' : 'NULL'}");

    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          'uid': uidToSend,
          'email': emailToSend,
          'name': nameToSend,
          'photo_url': photoToSend,
          'source': provider,
          'fcm_token': fcmToken ?? "",
        },
      ).timeout(const Duration(seconds: 10)); // 🟢 ADDED TIMEOUT

      print("📥 SERVER RESPONSE CODE: ${response.statusCode}");
      print("📥 SERVER RESPONSE BODY: ${response.body}");
      
      if (response.statusCode == 200) {
        print("✅ USER SYNCED SUCCESSFULLY");
      } else {
        print("⚠️ SYNC FAILED WITH STATUS: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ CONNECTION ERROR: $e");
      print("💡 TIP: Check if your laptop's IP (${ApiConfig.localIp}) is correct and Firewall is OFF.");
    }
    print("----------------------------------------");
  }
}
