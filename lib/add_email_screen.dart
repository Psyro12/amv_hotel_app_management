import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart'; 
import 'preloader_screen.dart';

class AddEmailScreen extends StatefulWidget {
  const AddEmailScreen({Key? key}) : super(key: key);

  @override
  State<AddEmailScreen> createState() => _AddEmailScreenState();
}

class _AddEmailScreenState extends State<AddEmailScreen> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Theme Colors
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);
  
  bool _isLoading = false;

  // 🟢 1. SEND OTP via PHP
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      
      final url = Uri.parse("${ApiConfig.baseUrl}/send_verification_otp.php");
      print("Connecting to: $url"); 

      final response = await http.post(url, body: {
        "email": _emailController.text.trim(),
        "name": user?.displayName ?? "Guest",
      });

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);

          if (data['success'] == true) {
            String serverOtp = data['otp'].toString();
            if (!mounted) return;
            _showOtpDialog(serverOtp);
            
          } else {
            throw Exception(data['message'] ?? "Failed to send code");
          }
        } catch (e) {
           throw Exception("Server Error (Bad JSON): ${response.body}");
        }
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🟢 2. OTP INPUT DIALOG HELPER
  void _showOtpDialog(String correctOtp) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _OtpDialog(
          correctOtp: correctOtp,
          email: _emailController.text.trim(),
          onVerified: () {
             Navigator.pop(context); // Close dialog
             _finalizeEmailUpdate(); // Proceed to update account
          },
        );
      },
    );
  }

  Future<void> _finalizeEmailUpdate() async {
    setState(() => _isLoading = true);
    
    try {
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        String verifiedEmail = _emailController.text.trim();
        print("OTP Correct. Saving $verifiedEmail to MySQL directly...");

        await _saveToMySQL(user, verifiedEmail);

        if (!mounted) return;

        // 🟢 TRANSITION TO PRELOADER WITH SLIDE-UP ANIMATION
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const PreloaderScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0); // Start from bottom
              const end = Offset.zero;        // End at original position
              const curve = Curves.fastOutSlowIn; // Premium smooth curve

              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);

              return SlideTransition(
                position: offsetAnimation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 800), // Elegant slow speed
          ),
          (route) => false, // Remove all previous screens from stack
        );
      }
    } catch (e) {
      print("Sync Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save Failed: ${e.toString()}")),
      );
      setState(() => _isLoading = false);
    }
  }

  // 🟢 4. HELPER: Manually Sync to MySQL
  Future<void> _saveToMySQL(User user, String email) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api_user_sync.php");
    
    final response = await http.post(url, body: {
      'uid': user.uid,
      'email': email, // Explicitly send the verified email
      'name': user.displayName ?? "Guest",
      'phone': user.phoneNumber ?? "",
      'photo_url': user.photoURL ?? "",
      'source': 'manual', 
    });

    if (response.statusCode != 200) {
      throw Exception("Failed to sync to database: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, 
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Final Step", style: GoogleFonts.montserrat(color: amvGold, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(
                "Verify your Email",
                style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.bold, color: amvViolet),
              ),
              const SizedBox(height: 10),
              Text(
                "We will send a 6-digit code to this address to verify your account.",
                style: GoogleFonts.montserrat(color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 40),
              
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Email Address",
                  prefixIcon: Icon(Icons.email_outlined, color: amvGold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: amvViolet, width: 2)),
                ),
                validator: (val) => (val!.isEmpty || !val.contains('@')) ? "Enter valid email" : null,
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amvViolet,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : Text("SEND CODE", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🟢 INTERNAL WIDGET: Simple OTP Popup
class _OtpDialog extends StatefulWidget {
  final String correctOtp;
  final String email;
  final VoidCallback onVerified;

  const _OtpDialog({required this.correctOtp, required this.email, required this.onVerified});

  @override
  State<_OtpDialog> createState() => __OtpDialogState();
}

class __OtpDialogState extends State<_OtpDialog> {
  final TextEditingController _otpController = TextEditingController();
  String? _errorText;

  void _verify() {
    if (_otpController.text.trim() == widget.correctOtp) {
      widget.onVerified();
    } else {
      setState(() => _errorText = "Incorrect code");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Icon(Icons.mark_email_read, size: 50, color: Color(0xFF2D0F35)),
          SizedBox(height: 10),
          Text("Enter Code", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Sent to ${widget.email}", style: TextStyle(fontSize: 12, color: Colors.grey)),
          SizedBox(height: 15),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: "",
              hintText: "------",
              errorText: _errorText,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _verify,
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2D0F35)),
          child: Text("VERIFY", style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }
}