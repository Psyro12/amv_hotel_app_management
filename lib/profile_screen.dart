import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';
import 'booking_history_screen.dart';
import 'api_config.dart';
import 'notification_button.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';
import 'transactions_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  User? _user;
  String _displayEmail = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      await currentUser.reload();
      currentUser = FirebaseAuth.instance.currentUser;

      String email = "No Email";

      if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
        email = currentUser.email!;
      } else {
        email = await _fetchMySQLEmail(currentUser!.uid);
      }

      if (mounted) {
        setState(() {
          _user = currentUser;
          _displayEmail = email;
        });
      }
    }
  }

  Future<String> _fetchMySQLEmail(String uid) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/check_user_email.php");
      final response = await http.post(url, body: {'uid': uid});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['has_email'] == true) {
          return data['email'];
        }
      }
    } catch (e) {
      print("Error fetching MySQL email: $e");
    }
    return "No Email Linked";
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user ?? FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Guest Mode"));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Column(
        children: [
          // --- HEADER SECTION ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [amvViolet, amvViolet.withOpacity(0.9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: amvViolet.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        "My Profile",
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: NotificationButton(
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: amvGold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: (user.photoURL != null)
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user.photoURL == null
                        ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                        : null,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  user.displayName ?? "Valued Guest",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _displayEmail,
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // --- OPTIONS LIST ---
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadProfileData,
              color: amvGold,
              child: ListView(
                padding: const EdgeInsets.all(20.0),
                children: [

                  // 2. Booking History
                  _buildProfileOption(
                    context,
                    Icons.history,
                    "Booking History",
                    () {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        _navigateWithSlideUp(
                            context,
                            BookingHistoryScreen(
                              userId: user.uid,
                              userEmail: _displayEmail,
                            ));
                      }
                    },
                  ),

                  // 3. Transactions
                  _buildProfileOption(
                    context,
                    Icons.account_balance_wallet_outlined,
                    "Transactions",
                    () {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        _navigateWithSlideUp(
                            context, TransactionsScreen(userId: user.uid));
                      }
                    },
                  ),

                  // 4. Privacy Policy
                  _buildProfileOption(
                    context,
                    Icons.privacy_tip_outlined,
                    "Privacy Policy",
                    () {
                      _navigateWithSlideUp(context, const PrivacyPolicyScreen());
                    },
                  ),

                  // 5. Terms & Conditions
                  _buildProfileOption(
                    context,
                    Icons.description_outlined,
                    "Terms & Conditions",
                    () {
                      _navigateWithSlideUp(context, const TermsConditionsScreen());
                    },
                  ),

                  const SizedBox(height: 30),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        await FirebaseAuth.instance.signOut();
                        await GoogleSignIn().signOut();
                        
                        if (context.mounted) {
                          // 🟢 UPDATED: Navigate to Login with Slide Up Animation
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                var begin = const Offset(0.0, 1.0); // Start from bottom
                                var end = Offset.zero;
                                var curve = Curves.fastOutSlowIn; // Premium curve
                                
                                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                
                                return SlideTransition(
                                  position: animation.drive(tween),
                                  child: child,
                                );
                              },
                              transitionDuration: const Duration(milliseconds: 600),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        side: BorderSide(color: Colors.red.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.red[400], size: 20),
                          const SizedBox(width: 10),
                          Text(
                            "Log Out",
                            style: GoogleFonts.montserrat(
                              color: Colors.red[400],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for Standard Options
  Widget _buildProfileOption(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback? onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: amvViolet.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: amvViolet, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
        ),
        onTap: onTap,
      ),
    );
  }

  // Slide Up Animation Helper
  void _navigateWithSlideUp(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.fastOutSlowIn;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}