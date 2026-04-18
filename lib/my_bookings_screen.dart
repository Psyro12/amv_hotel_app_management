import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'api_config.dart';
import 'notification_button.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  bool _isLoading = true;
  List<dynamic> _bookings = [];
  Timer? _refreshTimer;

  String _wifiSsid = "Loading...";
  String _wifiPassword = "Loading...";

  @override
  void initState() {
    super.initState();
    _fetchBookings();
    _fetchWifiInfo();

    // Start Real-time Refresh Timer (every 10 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !_isLoading) {
        _fetchBookings();
        _fetchWifiInfo();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWifiInfo() async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/api_get_wifi.php");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _wifiSsid = data['ssid'];
              _wifiPassword = data['password'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching WiFi: $e");
    }
  }

  Future<void> _fetchBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/api_get_my_bookings.php");
      final response = await http.post(
        url,
        body: json.encode({'uid': user.uid, 'type': 'active'}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _bookings = data['data'];
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching bookings: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int bookingId) async {
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api_mark_booking_read.php"),
        body: json.encode({'booking_id': bookingId}),
      );
      if (response.statusCode == 200) {
        _fetchBookings();
      }
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return Colors.green;
      case 'in house':
      case 'in_house': return amvViolet;
      case 'pending':
      case 'awaiting arrival':
      case 'awaiting_arrival': 
      case 'pending verification': return Colors.orange;
      case 'cancelled': return Colors.red;
      case 'completed': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return Icons.check_circle_outline;
      case 'in house':
      case 'in_house': return Icons.home_rounded;
      case 'pending':
      case 'awaiting arrival':
      case 'awaiting_arrival': 
      case 'pending verification': return Icons.hourglass_empty_rounded;
      case 'cancelled': return Icons.cancel_outlined;
      case 'completed': return Icons.thumb_up_alt_outlined;
      default: return Icons.info_outline;
    }
  }

  // 🟢 NEW: Premium Centered Modal (Fixes Overflow & Looks Engaging)
  void _showBookingDetails(Map<String, dynamic> booking) {
    final checkIn = DateFormat('MMMM dd, yyyy').format(DateTime.parse(booking['check_in']));
    final checkOut = DateFormat('MMMM dd, yyyy').format(DateTime.parse(booking['check_out']));
    final status = booking['arrival_status'] ?? booking['status'];
    final totalPrice = double.parse(booking['total_price'].toString()).toStringAsFixed(2);
    
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 600),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            color: Colors.white,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9, // Taller for better spacing
              ),
              padding: const EdgeInsets.fromLTRB(30, 15, 30, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 50, height: 5,
                    margin: const EdgeInsets.only(bottom: 25),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(5))
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // 1. Hero Icon (Top Center)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(statusIcon, size: 50, color: statusColor),
                          ),
                          
                          const SizedBox(height: 15),

                          // 2. Title & Ref
                          Text(
                            "Booking Details",
                            style: GoogleFonts.montserrat(
                              fontSize: 20, fontWeight: FontWeight.bold, color: amvViolet
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Ref: ${booking['booking_reference']}",
                            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[500], letterSpacing: 1),
                          ),

                          const SizedBox(height: 20),

                          // 3. Engaging Status Pill (Centered, No Overflow)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: statusColor.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 16, color: statusColor),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    status.toString().toUpperCase().replaceAll('_', ' '),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12, fontWeight: FontWeight.bold, color: statusColor
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),
                          const Divider(),
                          const SizedBox(height: 20),

                          // 4. Details Section
                          _buildDetailRow(Icons.bed, "Room Type", booking['room_names'] ?? "Standard Room"),
                          _buildDetailRow(Icons.calendar_today, "Check-in", checkIn),
                          _buildDetailRow(Icons.event, "Check-out", checkOut),
                          
                          if (status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'in house' || status.toLowerCase() == 'in_house') ...[
                            const SizedBox(height: 25),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.wifi, color: Colors.green[700], size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        "HOTEL WI-FI",
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.green[700],
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  _buildWifiRow("SSID", _wifiSsid),
                                  const SizedBox(height: 8),
                                  _buildWifiRow("Password", _wifiPassword),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 25),
                          
                          // 5. Big Total Price
                          Text(
                            "TOTAL AMOUNT", 
                            style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.5)
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "₱$totalPrice",
                            style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w800, color: amvGold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 6. Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amvViolet,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: Text("CLOSE", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: amvViolet, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
                Text(value, style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWifiRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600])),
        Text(value, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("My Bookings", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: amvViolet,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [NotificationButton(backgroundColor: Colors.transparent)],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: amvGold))
          : _bookings.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchBookings,
                  color: amvGold,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) {
                      return BookingRevealWrapper(
                        index: index,
                        child: _buildBookingCard(_bookings[index]),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildBookingCard(dynamic booking) {
    final checkIn = DateFormat('MMM dd').format(DateTime.parse(booking['check_in']));
    final checkOut = DateFormat('MMM dd, yyyy').format(DateTime.parse(booking['check_out']));
    final status = booking['arrival_status'] ?? booking['status'];
    final statusColor = _getStatusColor(status);
    
    bool isRead = (booking['is_read_by_user'] == 1 || booking['is_read_by_user'] == '1');
    bool isNewBooking = false;
    if (booking['created_at'] != null && !isRead) {
      try {
        DateTime createdAt = DateTime.parse(booking['created_at']);
        isNewBooking = DateTime.now().difference(createdAt).inHours < 24;
      } catch (e) { isNewBooking = false; }
    }

    return GestureDetector(
      onTap: () {
        _showBookingDetails(booking);
        if (!isRead) _markAsRead(int.parse(booking['id'].toString()));
      },
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          booking['room_names'] ?? "Room",
                          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: amvViolet),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "₱${double.parse(booking['total_price'].toString()).toStringAsFixed(2)}",
                        style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: amvGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text("Ref: ${booking['booking_reference']}", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[500])),
                  
                  const SizedBox(height: 15),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 15),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        flex: 3,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "$checkIn - $checkOut",
                                style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toString().toUpperCase().replaceAll('_', ' '),
                            style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (isNewBooking)
            Positioned(
              top: 0, left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: amvGold,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomRight: Radius.circular(12)),
                ),
                child: Text("NEW", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Icon(Icons.calendar_today_rounded, size: 60, color: Colors.grey[300]),
          ),
          const SizedBox(height: 20),
          Text(
            "No Bookings Yet",
            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            "Your scheduled stays will appear here.",
            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class BookingRevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;
  const BookingRevealWrapper({Key? key, required this.index, required this.child}) : super(key: key);
  @override
  State<BookingRevealWrapper> createState() => _BookingRevealWrapperState();
}

class _BookingRevealWrapperState extends State<BookingRevealWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 100), () { if (mounted) _controller.forward(); });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fadeAnimation, child: SlideTransition(position: _slideAnimation, child: widget.child));
  }
}