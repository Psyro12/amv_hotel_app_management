import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

class GcashPaymentScreen extends StatefulWidget {
  final double amountToPay;
  final String gcashName;
  final String gcashNumber;
  final String? gcashQrUrl;

  const GcashPaymentScreen({
    Key? key,
    required this.amountToPay,
    required this.gcashName,
    required this.gcashNumber,
    this.gcashQrUrl,
  }) : super(key: key);

  @override
  State<GcashPaymentScreen> createState() => _GcashPaymentScreenState();
}

class _GcashPaymentScreenState extends State<GcashPaymentScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);
  
  File? _selectedImage;
  String? _extractedRef; // 🟢 Store the found ref number
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();

  // 🟢 Validation Flags for Checklist
  bool? _hasGCash;
  bool? _hasCorrectAmount;
  bool? _hasRefPattern;
  bool? _hasRecipientMatch;
  bool? _isUnique;

  Future<void> _pickAndAnalyzeImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        setState(() {
          _isAnalyzing = true;
          _extractedRef = null;
        });

        final inputImage = InputImage.fromFilePath(pickedFile.path);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        
        String fullText = recognizedText.text.toLowerCase();
        String cleanText = fullText.replaceAll(',', ''); 
        textRecognizer.close();

        // 1. Extract Reference Number (Pattern: 13 digits, allows spaces/dashes)
        // This looks for 13 digits total, potentially separated by spaces
        RegExp refRegex = RegExp(r'(?:\d[\s-]*){13}');
        Iterable<Match> matches = refRegex.allMatches(recognizedText.text);
        
        String? foundRef;
        if (matches.isNotEmpty) {
          // Clean the found string by removing spaces and dashes
          foundRef = matches.first.group(0)!.replaceAll(RegExp(r'[\s-]'), '');
          
          // Double check it is exactly 13 digits after cleaning
          if (foundRef.length != 13) {
            foundRef = null;
          }
        }

        // Prepare amount formats
        String targetAmount = widget.amountToPay.toStringAsFixed(2);
        String targetAmountNoDec = widget.amountToPay.toStringAsFixed(0);
        
        // 2. Initial Validation Logic
        bool hasGCash = fullText.contains("gcash");
        
        // 🟢 STRICT MATCHING: Use Regex with word boundaries to ensure we match the standalone number
        // This prevents matching the "2" inside "2026" or a phone number.
        RegExp amountRegex = RegExp("\\b${RegExp.escape(targetAmount)}\\b|\\b${RegExp.escape(targetAmountNoDec)}\\b");
        bool hasCorrectAmount = amountRegex.hasMatch(cleanText);
        
        bool hasRefPattern = foundRef != null;

        // 3. Recipient Number Validation (Check for full number or last 4 digits)
        String last4 = widget.gcashNumber.length >= 4 
            ? widget.gcashNumber.substring(widget.gcashNumber.length - 4) 
            : widget.gcashNumber;
        bool hasRecipientMatch = cleanText.contains(widget.gcashNumber.replaceAll(RegExp(r'\D'), '')) || 
                                 cleanText.contains(last4);

        setState(() {
          _hasGCash = hasGCash;
          _hasCorrectAmount = hasCorrectAmount;
          _hasRefPattern = hasRefPattern;
          _hasRecipientMatch = hasRecipientMatch;
        });

        if (!hasGCash || !hasCorrectAmount || !hasRefPattern || !hasRecipientMatch) {
          setState(() => _isAnalyzing = false);
          String errorMessage = "We could not verify this receipt.\n\nIssues found:\n";
          if (!hasGCash) errorMessage += "• Not a GCash receipt\n";
          if (!hasCorrectAmount) errorMessage += "• Amount does not match ₱${NumberFormat("#,##0.00").format(widget.amountToPay)}\n";
          if (!hasRefPattern) errorMessage += "• Could not find 13-digit Reference No.\n";
          if (!hasRecipientMatch) errorMessage += "• Recipient account mismatch (ending in $last4)\n";
          
          _showErrorDialog("Invalid Receipt", errorMessage);
          return;
        }

        // 4. API Check: Prevent Duplicate Reference
        final response = await http.get(
          Uri.parse("${ApiConfig.baseUrl}/api_check_reference.php?ref=$foundRef"),
        );

        setState(() => _isAnalyzing = false);

        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          if (result['success'] == true) {
            if (result['is_duplicate'] == true) {
              setState(() => _isUnique = false);
              _showErrorDialog("Duplicate Receipt", "This reference number ($foundRef) has already been used for another transaction.");
            } else {
              // ✅ SUCCESS
              setState(() {
                _isUnique = true;
                _selectedImage = File(pickedFile.path);
                _extractedRef = foundRef;
              });
            }
          } else {
            _showErrorDialog("System Error", result['message'] ?? "Could not verify reference.");
          }
        } else {
          _showErrorDialog("Server Error", "Could not reach verification server.");
        }
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showErrorDialog("System Error", "Could not analyze image. Please try again.");
    }
  }

  void _showErrorDialog(String title, String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 600),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn)),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.fromLTRB(30, 15, 30, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle Bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 25),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon Header
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [amvViolet, const Color(0xFF4A1955)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: amvViolet.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Icon(Icons.warning_amber_rounded, color: amvGold, size: 45),
                        ),
                        const SizedBox(height: 25),
                        Text(
                          title.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: amvViolet,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 35),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: amvViolet,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 0,
                            ),
                            child: Text(
                              "TRY AGAIN",
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitReceipt() {
    if (_selectedImage != null && _extractedRef != null) {
      // 🟢 Return a Map containing both the File and the Ref Number
      Navigator.pop(context, {
        'image': _selectedImage,
        'reference': _extractedRef,
      });
    }
  }

  // 🟢 Helper to build checklist items
  Widget _buildCheckItem(String label, bool? passed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            passed == null ? Icons.circle_outlined : (passed ? Icons.check_circle : Icons.cancel),
            color: passed == null ? Colors.grey[300] : (passed ? Colors.green : Colors.red),
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: passed == null ? Colors.grey[400] : (passed ? Colors.green[700] : Colors.red[700]),
              fontWeight: passed != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Upload Payment", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: amvViolet,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            // 1. Instruction Card
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      "Please send exactly ₱${NumberFormat("#,##0.00").format(widget.amountToPay)} to the account below via GCash.",
                      style: GoogleFonts.montserrat(fontSize: 13, color: Colors.blue.shade900, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // 2. QR Code / Account Info
            if (widget.gcashQrUrl != null && widget.gcashQrUrl!.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(10),
                child: Image.network(widget.gcashQrUrl!, height: 180, fit: BoxFit.contain)
              )
            else
              const Icon(Icons.qr_code_2, size: 150, color: Colors.grey),
            
            const SizedBox(height: 15),
            Text(widget.gcashName, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            Text(widget.gcashNumber, style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: amvViolet, letterSpacing: 1)),
            
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),
            
            // 3. Upload Zone
            GestureDetector(
              onTap: _isAnalyzing ? null : _pickAndAnalyzeImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: amvGold.withOpacity(0.5), style: BorderStyle.solid, width: 1.5),
                ),
                child: _isAnalyzing 
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: amvGold),
                        const SizedBox(height: 15),
                        Text("Verifying Receipt...", style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 12)),
                      ],
                    )
                  : _selectedImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13), // Slightly less than container
                            child: Image.file(_selectedImage!, fit: BoxFit.cover),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.edit, color: Colors.black87, size: 20),
                              ),
                            ),
                          )
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 40, color: amvGold),
                          const SizedBox(height: 10),
                          Text("Tap to Upload Receipt", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                          const SizedBox(height: 5),
                          Text("(Must show GCash logo & Amount)", style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 20),

            // 🟢 Verification Checklist UI
            if (_hasGCash != null || _isAnalyzing)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: amvViolet),
                        const SizedBox(width: 8),
                        Text(
                          "VERIFICATION STATUS",
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: amvViolet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildCheckItem("GCash Receipt Detected", _hasGCash),
                    _buildCheckItem("Exact Amount Matched (₱${NumberFormat("#,##0.00").format(widget.amountToPay)})", _hasCorrectAmount),
                    _buildCheckItem("13-digit Reference No.", _hasRefPattern),
                    _buildCheckItem("Recipient Account Match", _hasRecipientMatch),
                    _buildCheckItem("Unique Transaction Reference", _isUnique),
                  ],
                ),
              ),

            const SizedBox(height: 30),
            
            // 4. Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedImage == null || _isAnalyzing ? null : _submitReceipt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: amvViolet,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey[300],
                  elevation: _selectedImage != null ? 5 : 0,
                  shadowColor: amvViolet.withOpacity(0.4),
                ),
                child: Text(
                  "SUBMIT PAYMENT", 
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold, 
                    color: _selectedImage != null ? Colors.white : Colors.grey[500], 
                    letterSpacing: 1
                  )
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}