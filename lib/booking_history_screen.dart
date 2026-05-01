import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'api_config.dart';

class BookingHistoryScreen extends StatefulWidget {
  final String userId;
  final String userEmail;

  const BookingHistoryScreen({
    Key? key,
    required this.userId,
    required this.userEmail,
  }) : super(key: key);

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  bool _isLoading = true;
  List<dynamic> _historyBookings = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    // Delay to smoothen animation
    await Future.delayed(const Duration(milliseconds: 800));

    if (widget.userId.isEmpty && widget.userEmail.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/api_get_my_bookings.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'uid': widget.userId,
          'email': widget.userEmail,
          'type': 'history',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _historyBookings = data['data'];
              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching history: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'arrived':
        return Colors.green;
      case 'checked out':
      case 'checked_out':
        return Colors.grey;
      case 'cancelled':
      case 'no-show':
        return Colors.red;
      case 'pending':
      case 'awaiting arrival':
      case 'awaiting_arrival':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // 🟢 NEW: Smooth Slide-Up Details Modal (Consistent with My Bookings)
  void _showBookingDetails(Map<String, dynamic> booking) {
    String formatDate(String? dateStr) {
      if (dateStr == null) return "N/A";
      try {
        return DateFormat('MMMM dd, yyyy').format(DateTime.parse(dateStr));
      } catch (e) {
        return dateStr;
      }
    }

    final String checkIn = formatDate(booking['check_in']);
    final String checkOut = formatDate(booking['check_out']);
    final String status = booking['arrival_status'] ?? booking['status'] ?? "Unknown";
    final String ref = booking['booking_reference'] ?? "N/A";
    final String rooms = booking['room_names'] ?? booking['room_name'] ?? "No Room Assigned";
    final String price = double.tryParse(booking['total_price'].toString())?.toStringAsFixed(2) ?? "0.00";
    final Color statusColor = _getStatusColor(status);

    // Get Icon based on status
    IconData statusIcon = Icons.history_rounded;
    if (status.toLowerCase().contains('arrived') || status.toLowerCase().contains('completed')) {
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (status.toLowerCase().contains('cancel')) {
      statusIcon = Icons.cancel_outlined;
    }

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
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 25), // 🟢 Compact Padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(5))
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // 1. Hero Icon (Top Center)
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(statusIcon, size: 35, color: statusColor),
                          ),
                          
                          const SizedBox(height: 12),

                          // 2. Title & Ref
                          Text(
                            "History Details",
                            style: GoogleFonts.montserrat(
                              fontSize: 18, fontWeight: FontWeight.bold, color: amvViolet
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Ref: $ref",
                            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[500], letterSpacing: 0.5),
                          ),

                          const SizedBox(height: 15),

                          // 3. Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 14, color: statusColor),
                                const SizedBox(width: 6),
                                Text(
                                  status.toString().toUpperCase().replaceAll('_', ' '),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10, fontWeight: FontWeight.bold, color: statusColor
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 20),

                          // 4. Details Section
                          _buildDetailRow(Icons.bed, "Room Type", rooms),
                          _buildDetailRow(Icons.calendar_today, "Check-in Date", checkIn),
                          _buildDetailRow(Icons.event, "Check-out Date", checkOut),
                          
                          const SizedBox(height: 15),

                          // 5. Total Price
                          Text(
                            "TOTAL PAID", 
                            style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1)
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "₱$price",
                            style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w800, color: amvGold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // 6. Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amvViolet,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text("CLOSE", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12, letterSpacing: 0.5)),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: amvViolet, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey)),
                Text(value, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Booking History",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: amvViolet,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: amvGold))
          : _historyBookings.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  color: amvGold,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    itemCount: _historyBookings.length,
                    itemBuilder: (context, index) {
                      return BookingRevealWrapper(
                        index: index,
                        child: _buildHistoryCard(_historyBookings[index]),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: amvGold,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("No booking history",
                    style: GoogleFonts.montserrat(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🟢 Enhanced History Card
  Widget _buildHistoryCard(dynamic booking) {
    String checkIn = "N/A";
    String checkOut = "N/A";

    try {
      if (booking['check_in'] != null) {
        checkIn = DateFormat('MMM dd').format(DateTime.parse(booking['check_in']));
      }
      if (booking['check_out'] != null) {
        checkOut = DateFormat('MMM dd, yyyy').format(DateTime.parse(booking['check_out']));
      }
    } catch (e) {}

    final fullDate = "$checkIn - $checkOut";

    final status = (booking['arrival_status'] != null && booking['arrival_status'].toString().isNotEmpty)
        ? booking['arrival_status']
        : (booking['status'] ?? "Unknown");
    
    final statusColor = _getStatusColor(status);

    final roomName = booking['room_names'] ?? booking['room_name'] ?? "Room Details";
    final refNumber = booking['booking_reference'] ?? "N/A";
    final price = "₱${double.tryParse(booking['total_price'].toString())?.toStringAsFixed(2) ?? '0.00'}";

    return GestureDetector(
      onTap: () => _showBookingDetails(booking),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      roomName,
                      style: GoogleFonts.montserrat(
                        fontSize: 16, // Slightly smaller than active for hierarchy
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[800], // Muted title for history
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    price,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: amvGold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                "Ref: $refNumber",
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 15),
              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_rounded,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            fullDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toString().toUpperCase().replaceAll('_', ' '),
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingRevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const BookingRevealWrapper(
      {Key? key, required this.index, required this.child})
      : super(key: key);

  @override
  State<BookingRevealWrapper> createState() => _BookingRevealWrapperState();
}

class _BookingRevealWrapperState extends State<BookingRevealWrapper>
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

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
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