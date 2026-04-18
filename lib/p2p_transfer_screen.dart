import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_config.dart'; // 🟢 MAKE SURE YOU HAVE THIS

class P2PTransferScreen extends StatefulWidget {
  const P2PTransferScreen({Key? key}) : super(key: key);

  @override
  State<P2PTransferScreen> createState() => _P2PTransferScreenState();
}

class _P2PTransferScreenState extends State<P2PTransferScreen> {
  // Input Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  
  // Theme Colors
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  bool _isLoading = false;

  // 🟢 STEP 1: CALL YOUR PHP SCRIPT
  Future<void> _initiateTransfer() async {
    // 1. Basic Validation
    if (_emailController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("You must be logged in to transfer funds.");
      }

      // 2. Prepare Data for PHP
      final url = Uri.parse("${ApiConfig.baseUrl}/send_p2p_otp.php");

      // 3. Send Request
      final response = await http.post(url, body: {
        // These keys match your $_POST variables in PHP exactly
        "sender_name": user.displayName ?? "AMV User",
        "sender_email": user.email ?? "",
        "receiver_email": _emailController.text.trim(),
        "amount": _amountController.text.trim(), 
      });

      // 4. Parse Response
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        
        // 🟢 CRITICAL: The PHP script sent the OTP back to us in the JSON
        // We save this 'serverOtp' to compare with what the user types.
        String serverOtp = data['otp'].toString();
        
        if (!mounted) return;
        
        // 5. Show the Dialog
        _showOtpDialog(serverOtp);
        
      } else {
        throw Exception(data['message'] ?? "Failed to send OTP");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🟢 STEP 2: SHOW DIALOG
  void _showOtpDialog(String requiredOtp) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to enter code or cancel
      builder: (context) {
        return _OtpDialog(
          correctOtp: requiredOtp,
          receiverEmail: _emailController.text,
          amount: _amountController.text,
          onVerified: () {
            // 🟢 STEP 3: OTP MATCHED!
            Navigator.pop(context); // Close the dialog
            _processFinalTransfer(); // Execute the money move
          },
        );
      },
    );
  }

  // 🟢 STEP 4: SUCCESS (MOCKED)
  // In the future, this function will call 'process_transfer.php' to update the DB
  void _processFinalTransfer() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text("Transfer Successful!", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "You successfully sent ₱${_amountController.text} to ${_emailController.text}.",
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close Alert
              Navigator.pop(context); // Go back to Home Screen
            },
            child: Text("Done", style: TextStyle(color: amvViolet, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("Transfer Funds", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: amvViolet,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Text
              Text(
                "Send Money",
                style: GoogleFonts.montserrat(
                  fontSize: 26, 
                  fontWeight: FontWeight.bold, 
                  color: amvViolet
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Secure transfer via Email Verification",
                style: GoogleFonts.montserrat(color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // Inputs
              _buildInput("Receiver's Email", Icons.email_outlined, _emailController),
              const SizedBox(height: 20),
              _buildInput("Amount (₱)", Icons.attach_money, _amountController, isNumber: true),

              const SizedBox(height: 40),

              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _initiateTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amvViolet,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    shadowColor: amvViolet.withOpacity(0.4),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : Text(
                        "CONTINUE",
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          fontSize: 16,
                          letterSpacing: 1.5
                        ),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, IconData icon, TextEditingController controller, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.emailAddress,
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(color: Colors.grey),
        prefixIcon: Icon(icon, color: amvGold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: amvViolet, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      ),
    );
  }
}

// 🟢 INTERNAL WIDGET: The Popup Dialog Logic
class _OtpDialog extends StatefulWidget {
  final String correctOtp;
  final String receiverEmail;
  final String amount;
  final VoidCallback onVerified;

  const _OtpDialog({
    required this.correctOtp,
    required this.receiverEmail,
    required this.amount,
    required this.onVerified,
  });

  @override
  State<_OtpDialog> createState() => __OtpDialogState();
}

class __OtpDialogState extends State<_OtpDialog> {
  final TextEditingController _otpController = TextEditingController();
  String? _errorText;
  bool _isVerifying = false;

  void _verify() {
    setState(() => _isVerifying = true);
    
    // Simulate a small delay for better UX
    Future.delayed(Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      if (_otpController.text.trim() == widget.correctOtp) {
        widget.onVerified(); // Calls the success function passed from parent
      } else {
        setState(() {
           _errorText = "Incorrect code";
           _isVerifying = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Color(0xFF2D0F35).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline, size: 40, color: Color(0xFF2D0F35)),
          ),
          const SizedBox(height: 15),
          Text(
            "Verify Transfer",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "We emailed a code to:",
            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
          ),
          Text(
            widget.receiverEmail,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D0F35)),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: "",
              hintText: "000000",
              hintStyle: TextStyle(color: Colors.grey.shade300),
              errorText: _errorText,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Ask the receiver for this code.",
            style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel", style: GoogleFonts.montserrat(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: _isVerifying ? null : _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D0F35),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10)
          ),
          child: _isVerifying 
            ? SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text("VERIFY", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}