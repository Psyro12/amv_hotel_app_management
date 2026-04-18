import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'api_config.dart';

class UserSyncService {
  
  // 🟢 Updated: Added 'provider' parameter (default is 'email')
  static Future<void> syncUserToMySQL(User user, {String? manualEmail, String provider = 'email'}) async {
    final String url = "${ApiConfig.baseUrl}/api_user_sync.php";
    
    String emailToSend = manualEmail ?? user.email ?? "";
    String nameToSend = user.displayName ?? "Guest User";
    String photoToSend = user.photoURL ?? "";
    String uidToSend = user.uid;

    print("🚀 SYNCING USER ($provider)...");

    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          'uid': uidToSend,
          'email': emailToSend,
          'name': nameToSend,
          'photo_url': photoToSend,
          'source': provider, // 🟢 Sending the source to PHP
        },
      );

      print("📥 RESPONSE: ${response.body}");
      
      // ... (rest of your error handling logic stays the same) ...
    } catch (e) {
      print("❌ CRITICAL ERROR during Sync: $e");
    }
  }
}