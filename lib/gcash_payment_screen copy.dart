import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart'; 

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
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndAnalyzeImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        setState(() => _isAnalyzing = true);

        final inputImage = InputImage.fromFilePath(pickedFile.path);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        
        String fullText = recognizedText.text.toLowerCase();
        String cleanText = fullText.replaceAll(',', ''); 
        textRecognizer.close();

        // Prepare amount formats
        String targetAmount = widget.amountToPay.toStringAsFixed(2); // "700.00"
        String targetAmountNoDec = widget.amountToPay.toStringAsFixed(0); // "700"
        
        // Validation Logic
        bool hasGCash = fullText.contains("gcash");
        bool hasCorrectAmount = cleanText.contains(targetAmount) || cleanText.contains(targetAmountNoDec);
        bool hasRef = fullText.contains("ref no") || fullText.contains("reference") || fullText.contains("txn");
        bool hasDate = fullText.contains("date") || fullText.contains("202"); 

        setState(() => _isAnalyzing = false);

        if (hasGCash && hasCorrectAmount) {
          setState(() {
            _selectedImage = File(pickedFile.path);
          });
        } else {
          String errorMessage = "We could not verify this receipt.\n\nIssues found:\n";
          
          if (!hasGCash) {
            errorMessage += "• Missing GCash logo or text\n";
          }
          if (!hasCorrectAmount) {
            errorMessage += "• Amount does not match ₱${NumberFormat("#,##0.00").format(widget.amountToPay)}\n";
          } else if (!hasRef && !hasDate) {
             errorMessage += "• Missing Reference No. or Date\n";
          }

          errorMessage += "\nPlease upload the correct official receipt.";
          _showErrorDialog("Invalid Receipt", errorMessage);
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
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: Material(
          color: Colors.transparent,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.warning_amber_rounded, size: 40, color: Colors.red.shade400),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title, 
                    style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: amvViolet), 
                    textAlign: TextAlign.center
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message, 
                    style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600], height: 1.5), 
                    textAlign: TextAlign.center
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amvViolet,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text("TRY AGAIN", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitReceipt() {
    if (_selectedImage != null) {
      Navigator.pop(context, _selectedImage);
    }
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