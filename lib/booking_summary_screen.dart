import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'api_config.dart';
import 'gcash_payment_screen.dart';
import 'home_screen.dart';

class BookingSummaryScreen extends StatefulWidget {
  final DateTimeRange dateRange;
  final List<dynamic> selectedRooms;
  final Map<String, dynamic> guestDetails;
  final int adults;
  final int children;

  const BookingSummaryScreen({
    Key? key,
    required this.dateRange,
    required this.selectedRooms,
    required this.guestDetails,
    required this.adults,
    required this.children,
  }) : super(key: key);

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);
  
  bool _isLoading = false;
  String _paymentMethod = "GCash"; // Default fixed to GCash
  
  // Payment Info Variables
  String _gcashName = "Loading...";
  String _gcashNumber = "";
  String? _gcashQrUrl; 

  File? _receiptImage;
  String? _paymentRef; // 🟢 Store extracted reference

  @override
  void initState() {
    super.initState();
    _fetchPaymentSettings();
  }

  Future<void> _fetchPaymentSettings() async {
    try {
      final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/api_get_payment_info.php"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _gcashName = data['account_name'] ?? "AMV Hotel";
              _gcashNumber = data['account_number'] ?? "";
              _gcashQrUrl = data['qr_image']; 
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching payment info: $e");
    }
  }

  double get _totalBookingCost {
    int nights = widget.dateRange.duration.inDays;
    double total = 0;
    for (var room in widget.selectedRooms) {
      double price = double.tryParse(room['price'].toString()) ?? 0.0;
      total += (price * nights);
    }
    return total;
  }

  double get _amountToPayNow {
    String term = widget.guestDetails['payment_term'] ?? 'full';
    if (term == 'partial') {
      return _totalBookingCost / 2;
    }
    return _totalBookingCost;
  }

  Future<void> _handleBookingButton() async {
    if (_paymentMethod == "GCash") {
      // 🟢 Result is now a Map { 'image': File, 'reference': String }
      final dynamic result = await Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false, 
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) {
            return GcashPaymentScreen(
              amountToPay: _amountToPayNow,
              gcashName: _gcashName,
              gcashNumber: _gcashNumber,
              gcashQrUrl: _gcashQrUrl,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = const Offset(0.0, 1.0); 
            var end = Offset.zero;            
            var curve = Curves.fastOutSlowIn;   

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );

      // If we got a result back, proceed with submission
      if (result != null && result is Map) {
        setState(() {
          _receiptImage = result['image'];
          _paymentRef = result['reference'];
        });
        _submitBooking();
      }
    } else {
      _submitBooking();
    }
  }

  Future<void> _submitBooking() async {
    setState(() => _isLoading = true);
    
    User? user = FirebaseAuth.instance.currentUser;
    final url = Uri.parse("${ApiConfig.baseUrl}/api_save_booking.php");

    List<Map<String, dynamic>> roomsData = widget.selectedRooms.map((r) => {
      'id': r['id'], 'name': r['name'], 'price': r['price']
    }).toList();

    Map<String, dynamic> fullData = {
      'uid': user?.uid ?? "",
      'guest': widget.guestDetails,
      'rooms': roomsData,
      'dates': {
        'check_in': DateFormat('yyyy-MM-dd').format(widget.dateRange.start),
        'check_out': DateFormat('yyyy-MM-dd').format(widget.dateRange.end),
      },
      'payment': {
        'method': _paymentMethod,
        'total_price': _totalBookingCost,
        'amount_paid': _amountToPayNow,
        'term': widget.guestDetails['payment_term'] ?? 'full',
        'payment_reference': _paymentRef, // 🟢 Added this
      },
      'adults': widget.adults,
      'children': widget.children,
      'status': _paymentMethod == "GCash" ? "Pending Verification" : "Confirmed"
    };

    try {
      if (_paymentMethod == "GCash" && _receiptImage != null) {
        var request = http.MultipartRequest('POST', url);
        var pic = await http.MultipartFile.fromPath("receipt", _receiptImage!.path);
        request.files.add(pic);
        request.fields['booking_data'] = jsonEncode(fullData);
        if (_paymentRef != null) {
          request.fields['payment_reference'] = _paymentRef!; // 🟢 Explicit field
        }

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        _handleResponse(response);
      } else {
        final response = await http.post(
          url, 
          body: json.encode(fullData), 
          headers: {"Content-Type": "application/json"},
        );
        _handleResponse(response);
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Error: $e"), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleResponse(http.Response response) {
    if (mounted) setState(() => _isLoading = false);
    
    try {
      final result = json.decode(response.body);
      if (result['success'] == true) {
        _showSuccessPage(result['ref']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Booking Failed: ${result['message']}"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Server Error: ${response.statusCode}"), backgroundColor: Colors.red));
    }
  }

  void _showSuccessPage(String ref) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => BookingSuccessScreen(
          reference: ref,
          amountToPay: _amountToPayNow,
          paymentMethod: _paymentMethod,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(0.0, 1.0); // Start from bottom
          var end = Offset.zero;             // End at center
          var curve = Curves.fastOutSlowIn;  // Premium feel

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

  @override
  Widget build(BuildContext context) {
    int nights = widget.dateRange.duration.inDays;
    bool isPartial = widget.guestDetails['payment_term'] == 'partial';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("Confirm Booking", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: amvViolet,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: amvViolet))
        : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Extra bottom padding for floating button
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Booking Details Card (Receipt Style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("BOOKING SUMMARY", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.5)),
                    const SizedBox(height: 20),
                    
                    // Dates
                    Row(
                      children: [
                        Expanded(child: _dateBox("CHECK-IN", widget.dateRange.start)),
                        Container(height: 40, width: 1, color: Colors.grey[300]),
                        Expanded(child: _dateBox("CHECK-OUT", widget.dateRange.end)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 30),
                    
                    // Details List
                    _detailRow("Duration", "$nights Night(s)"),
                    _detailRow("Guests", "${widget.adults} Adults, ${widget.children} Kids"),
                    _detailRow("Payment", isPartial ? "50% Downpayment" : "Full Payment"),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // 2. Selected Rooms Section
              Text("SELECTED ROOMS", style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
              const SizedBox(height: 15),
              ...widget.selectedRooms.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['name'], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: amvViolet)),
                          const SizedBox(height: 4),
                          Text("Standard Rate", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ), 
                    Text("₱${r['price']}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: amvGold))
                  ]
                ),
              )).toList(),

              const SizedBox(height: 25),

              // 3. Payment Method Card
              Text("PAYMENT METHOD", style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16), 
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "GCash E-Wallet",
                          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          "Secure & Instant Payment",
                          style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 4. Sticky Bottom Bar
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total Amount", style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                    Text("₱${_amountToPayNow.toStringAsFixed(2)}", style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: amvViolet)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, 
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleBookingButton, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amvViolet, 
                      padding: const EdgeInsets.symmetric(vertical: 18), 
                      elevation: 5,
                      shadowColor: amvViolet.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ), 
                    child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _paymentMethod == "GCash" ? "PAY NOW & BOOK" : "CONFIRM & BOOK", 
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1, fontSize: 16)
                        )
                  )
                ),
              ],
            ),
          ),
        ),
    );
  }

  // 🎨 Reusable Components
  Widget _dateBox(String label, DateTime date) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 5),
        Text(DateFormat('MMM dd').format(date), style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: amvViolet)),
        Text(DateFormat('yyyy').format(date), style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
  
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600])),
          Text(value, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}

// Full Screen Booking Success Page
class BookingSuccessScreen extends StatelessWidget {
  final String reference;
  final double amountToPay;
  final String paymentMethod;
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  const BookingSuccessScreen({
    Key? key,
    required this.reference,
    required this.amountToPay,
    required this.paymentMethod,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 80),
              ),
              const SizedBox(height: 40),
              Text(
                "Booking Submitted!",
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: amvViolet,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Reference: $reference",
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: amvGold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                paymentMethod == "GCash"
                    ? "Receipt uploaded! We will verify your payment (₱${amountToPay.toStringAsFixed(2)}) and confirm via email shortly."
                    : "Please present this reference at the front desk upon arrival.",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // 🟢 Clear dates in Home Screen
                    HomeScreen.clearSelectedDates();
                    
                    // 🟢 Pop all screens until we reach the Home Screen (the first route)
                    // This creates a natural "Slide Down" animation for the Success screen.
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amvViolet,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "RETURN TO HOME",
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
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
}