import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 
import 'api_config.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  
  String _dbEmail = "";
  String _dbSource = "";

  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        _fetchUserDataFromMySQL(); 
      }
    });

    // Start Real-time Refresh Timer (every 15 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && !_isLoading) {
        _fetchNotifications();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserDataFromMySQL() async {
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/api_get_user_email.php");
      final response = await http.post(url, body: {"uid": user!.uid});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _dbEmail = data['email'];
              _dbSource = data['source'] ?? 'email';
            });
            _fetchNotifications();
          }
        } else {
           if (mounted) setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print("Error resolving user: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNotifications() async {
    if (_dbEmail.isEmpty) return;

    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/api_get_notifications.php");
      final response = await http.post(url, body: {
        "email": _dbEmail,   
        "source": _dbSource, 
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _notifications = data['data'];
              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print("Error fetching notifications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper for Dynamic Icons & Colors
  Map<String, dynamic> _getTypeStyle(String type) {
    switch (type.toLowerCase()) {
      case 'booking': 
        return {'icon': Icons.calendar_month_rounded, 'color': amvViolet, 'bg': amvViolet.withOpacity(0.1)};
      case 'promo': 
        return {'icon': Icons.local_offer_rounded, 'color': amvGold, 'bg': amvGold.withOpacity(0.1)};
      case 'system': 
        return {'icon': Icons.settings_suggest_rounded, 'color': Colors.blueGrey, 'bg': Colors.blueGrey.withOpacity(0.1)};
      default: 
        return {'icon': Icons.notifications_rounded, 'color': amvViolet, 'bg': Colors.grey.shade100};
    }
  }

  // 🟢 NEW: Smooth Custom Transition Dialog
  void _showNotificationDetails(Map<String, dynamic> notif) {
    String date = notif['created_at'];
    try {
      DateTime dt = DateTime.parse(notif['created_at']);
      date = DateFormat('MMMM dd, yyyy • h:mm a').format(dt);
    } catch (e) {}

    String type = notif['type'] ?? "General";
    var style = _getTypeStyle(type);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 600), // 🟢 1. Slower Duration
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // 🟢 2. Premium Curve: fastOutSlowIn
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn)),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: 450, // Fixed comfortable height
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Drag Handle
                  Container(
                    width: 50, height: 5,
                    margin: const EdgeInsets.only(bottom: 25),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(5)),
                  ),
                  
                  // Big Icon Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: style['bg'],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(style['icon'], size: 40, color: style['color']),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    notif['title'],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    date,
                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[500]),
                  ),
                  
                  const SizedBox(height: 25),
                  const Divider(),
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        notif['message'],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 15, height: 1.6, color: Colors.grey[700]
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amvViolet,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: Text("DISMISS", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("Notifications", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: amvViolet,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30), 
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: amvGold))
        : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 20),
                  Text("All Caught Up!", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text("No new notifications at the moment.", style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchNotifications, 
              color: amvGold,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notif = _notifications[index];
                  return NotificationRevealWrapper(
                    index: index,
                    child: _buildNotificationCard(notif),
                  );
                },
              ),
            ),
    );
  }

  // Enhanced Card Design
  Widget _buildNotificationCard(dynamic notif) {
    String date = notif['created_at']; 
    try {
      DateTime dt = DateTime.parse(notif['created_at']);
      if (dt.day == DateTime.now().day) {
        date = DateFormat('h:mm a').format(dt);
      } else {
        date = DateFormat('MMM dd').format(dt);
      }
    } catch (e) {}

    var style = _getTypeStyle(notif['type'] ?? "general");

    return GestureDetector(
      onTap: () => _showNotificationDetails(notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // 🟢 FIXED: Vertically Center Icon
            children: [
              // Icon Box
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: style['bg'],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(style['icon'], color: style['color'], size: 22),
              ),
              const SizedBox(width: 15),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif['title'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold, 
                              fontSize: 14, 
                              color: Colors.black87
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date, 
                          style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400])
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notif['message'], 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(fontSize: 12, height: 1.4, color: Colors.grey[600])
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationRevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const NotificationRevealWrapper({
    Key? key, 
    required this.index, 
    required this.child
  }) : super(key: key);

  @override
  State<NotificationRevealWrapper> createState() => _NotificationRevealWrapperState();
}

class _NotificationRevealWrapperState extends State<NotificationRevealWrapper> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}