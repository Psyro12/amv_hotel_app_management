import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notifications_screen.dart';
import 'api_config.dart';

class NotificationButton extends StatefulWidget {
  final Color iconColor;
  final Color backgroundColor;

  const NotificationButton({
    Key? key,
    this.iconColor = Colors.white,
    this.backgroundColor = const Color(0x26FFFFFF), // Default glass effect
  }) : super(key: key);

  @override
  State<NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<NotificationButton> {
  bool _hasUnread = false;
  int _unreadCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _checkNotifications();
    
    // Optional: Auto-refresh badge every 60 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) _checkNotifications();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // 🟢 LOGIC: Checks database for notifications
  Future<void> _checkNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String email = user.email ?? "";
      if (email.isEmpty) return;

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api_get_notifications.php"),
        body: {"email": email, "source": "email"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List items = data['data'];

          final prefs = await SharedPreferences.getInstance();
          int lastCount = prefs.getInt('last_known_notif_count') ?? 0;

          if (mounted) {
            setState(() {
              _unreadCount = items.length;
              
              // 🟢 FIX: Only show badge if we have MORE items than last time
              if (items.length > lastCount) {
                _hasUnread = true;
              } else {
                _hasUnread = false;
              }
            });
          }
        }
      }
    } catch (e) {
      print("Badge check error: $e");
    }
  }

  // 🟢 ACTION: Clears badge when clicked
  void _handlePress() async {
    // 1. Update local storage so we know these are "seen"
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_known_notif_count', _unreadCount);

    // 2. Hide badge visually immediately
    if (mounted) {
      setState(() => _hasUnread = false);
    }

    // 3. Open Screen
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => const NotificationsScreen(),
        transitionsBuilder: (context, animation, __, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.fastOutSlowIn;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 600),
      ),
    ).then((_) {
      // Re-check when coming back (optional)
      _checkNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 15),
      // 🟢 Stack allows us to layer the Badge ON TOP of the button
      child: Stack(
        clipBehavior: Clip.none, // Allow badge to overlap slightly
        children: [
          // 1. The Button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.backgroundColor,
            ),
            child: IconButton(
              icon: Icon(Icons.notifications, color: widget.iconColor, size: 22),
              onPressed: _handlePress,
            ),
          ),

          // 2. The Red Badge (Only shows if _hasUnread is true)
          if (_hasUnread)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5), // White border makes it pop
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}