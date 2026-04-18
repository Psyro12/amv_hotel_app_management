import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'api_config.dart';

class BookingSummaryScreen extends StatefulWidget {
  final DateTimeRange dateRange;
  final List<dynamic> selectedRooms;
  final Map<String, String> guestDetails;
  final int adults;   // 🟢 Add this
  final int children; // 🟢 Add this

  const BookingSummaryScreen({
    required this.dateRange,
    required this.selectedRooms,
    required this.guestDetails,
    required this.adults,   // 🟢 Add this
    required this.children,
  });

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  final Color amvViolet = Color(0xFF2D0F35);
  final Color amvGold = Color(0xFFD4AF37);
  bool _isLoading = false;
  String _paymentMethod = "Cash"; // Default

  double get _totalPrice {
    int nights = widget.dateRange.duration.inDays;
    double total = 0;
    for (var room in widget.selectedRooms) {
      total += (double.parse(room['price'].toString()) * nights);
    }
    return total;
  }

  Future<void> _submitBooking() async {
    setState(() => _isLoading = true);
    
    User? user = FirebaseAuth.instance.currentUser;
    final url = Uri.parse("${ApiConfig.baseUrl}/api_save_booking.php");

    // Prepare Room Data
    List<Map<String, dynamic>> roomsData = widget.selectedRooms.map((r) => {
      'id': r['id'],
      'name': r['name'],
      'price': r['price']
    }).toList();

    Map<String, dynamic> requestBody = {
      'uid': user?.uid ?? "",
      'guest': widget.guestDetails,
      'rooms': roomsData,
      'dates': {
        'check_in': DateFormat('yyyy-MM-dd').format(widget.dateRange.start),
        'check_out': DateFormat('yyyy-MM-dd').format(widget.dateRange.end),
      },
      'payment': {
        'method': _paymentMethod,
        'total_price': _totalPrice,
      }
    };

    try {
      final response = await http.post(url, body: json.encode(requestBody));
      final result = json.decode(response.body);

      if (result['success'] == true) {
        _showSuccessDialog(result['ref']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${result['message']}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text("Booking Confirmed!", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("Reference: $ref\nPlease present this at the front desk.", textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text("GO TO HOME"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int nights = widget.dateRange.duration.inDays;

    return Scaffold(
      appBar: AppBar(title: Text("Confirm Booking", style: GoogleFonts.montserrat(color: Colors.white)), backgroundColor: amvViolet),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: amvViolet))
        : SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Stay Details"),
              _infoRow("Check-in", DateFormat('MMM dd, yyyy').format(widget.dateRange.start)),
              _infoRow("Check-out", DateFormat('MMM dd, yyyy').format(widget.dateRange.end)),
              _infoRow("Duration", "$nights Nights"),
              Divider(),
              
              _sectionTitle("Rooms"),
              ...widget.selectedRooms.map((r) => Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r['name'], style: GoogleFonts.montserrat()),
                    Text("₱${r['price']}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                  ],
                ),
              )).toList(),
              Divider(),

              _sectionTitle("Payment Method"),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                items: ["Cash", "GCash"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setState(() => _paymentMethod = val!),
                decoration: InputDecoration(border: OutlineInputBorder()),
              ),
              Divider(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("TOTAL", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: amvViolet)),
                  Text("₱${_totalPrice.toStringAsFixed(2)}", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: amvGold)),
                ],
              ),
              SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitBooking,
                  style: ElevatedButton.styleFrom(backgroundColor: amvViolet, padding: EdgeInsets.symmetric(vertical: 16)),
                  child: Text("CONFIRM & BOOK", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
    );
  }

  Widget _sectionTitle(String title) => Padding(padding: EdgeInsets.only(bottom: 10, top: 10), child: Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.grey[600])));
  
  Widget _infoRow(String label, String value) => Padding(padding: EdgeInsets.only(bottom: 5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: GoogleFonts.montserrat()), Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))]));
}