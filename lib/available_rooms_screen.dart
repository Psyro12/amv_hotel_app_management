import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🟢 Added missing import
import 'api_config.dart';
import 'guest_info_screen.dart';

class AvailableRoomsScreen extends StatefulWidget {
  final DateTimeRange dateRange;
  final int adults;
  final int children;
  final Animation<double>? transitionAnimation;

  AvailableRoomsScreen({
    required this.dateRange,
    required this.adults,
    required this.children,
    this.transitionAnimation,
  });

  @override
  _AvailableRoomsScreenState createState() => _AvailableRoomsScreenState();
}

class _AvailableRoomsScreenState extends State<AvailableRoomsScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  List<dynamic> _rooms = [];
  bool _isLoading = true;
  List<dynamic> _selectedRooms = [];
  bool _isBookingBlocked = false; // 🟢 New
  Timer? _statusTimer; // 🟢 New

  @override
  void initState() {
    super.initState();
    _fetchRooms();
    _checkBookingStatus();

    // 🟢 Real-time status polling (Every 5 seconds)
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkBookingStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel(); // 🟢 Cleanup
    super.dispose();
  }

  // 🟢 NEW: Check User Booking Block Status
  Future<void> _checkBookingStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api_get_user_status.php?uid=${user.uid}"),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _isBookingBlocked = data['is_booking_blocked'] ?? false;
            });
          }
        }
      }
    } catch (e) {
      print("Error checking booking status: $e");
    }
  }

  // 🟢 ENHANCED: Premium Slide-Up Modal for Booking Limit
  void _showBookingLimitModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87, // Darker backdrop
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

                  // Scrollable Content
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                                                    // 🟢 ENHANCED: Signature AMV Icon Header
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
                                                      child: Icon(Icons.hotel_rounded, color: amvGold, size: 45),
                                                    ),
                                                    const SizedBox(height: 25),
                                                    Text(
                                                      "BOOKING LIMIT REACHED",
                                                      textAlign: TextAlign.center, // 🟢 Centered
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w800,
                                                        color: amvViolet,
                                                        letterSpacing: 1.2,
                                                      ),
                                                    ),
                          
                          const SizedBox(height: 15),
                          Text(
                            "You have 4 active pending bookings. To ensure fair room availability, please wait for the admin to process your current reservations before booking more.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 35),
                          
                          // Action Buttons
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
                                "UNDERSTOOD",
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "Need help? Contact Reservations",
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: amvGold,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
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
        );
      },
    );
  }

  Future<void> _fetchRooms() async {
    // 🟢 1. ADDED DELAY: Forces the loading state to show for 1.5 seconds
    // This ensures the user sees the "Staggered Reveal" animation every time.
    await Future.delayed(const Duration(milliseconds: 800));

    String checkIn = DateFormat('yyyy-MM-dd').format(widget.dateRange.start);
    String checkOut = DateFormat('yyyy-MM-dd').format(widget.dateRange.end);

    String apiUrl = "${ApiConfig.baseUrl}/api_get_available_rooms.php?checkin=$checkIn&checkout=$checkOut";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          if (mounted) {
            setState(() {
              _rooms = jsonResponse['data'];
              _isLoading = false; // 🟢 Animation triggers when this becomes false
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print("Error fetching rooms: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleRoom(dynamic room) {
    setState(() {
      final isSelected = _selectedRooms.any((r) => r['id'] == room['id']);
      if (isSelected) {
        _selectedRooms.removeWhere((r) => r['id'] == room['id']);
      } else {
        _selectedRooms.add(room);
      }
    });
  }

  double _calculateTotal() {
    int nights = widget.dateRange.duration.inDays;
    double total = 0;
    for (var room in _selectedRooms) {
      double price = double.tryParse(room['price'].toString()) ?? 0.0;
      total += price * nights;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. COLLAPSING HEADER
              SliverAppBar(
                expandedHeight: 180.0,
                floating: false,
                pinned: true,
                backgroundColor: amvViolet,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    "Available Rooms",
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Decorative Gradient Background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              amvViolet,
                              const Color(0xFF4A1A5E),
                            ],
                          ),
                        ),
                      ),
                      // Info overlay
                      Positioned(
                        bottom: 60,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Text(
                              "${widget.dateRange.duration.inDays} Nights Stay",
                              style: GoogleFonts.montserrat(
                                color: amvGold,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "${DateFormat('MMM dd').format(widget.dateRange.start)} - ${DateFormat('MMM dd').format(widget.dateRange.end)}",
                              style: GoogleFonts.montserrat(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people, color: Colors.white54, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  "${widget.adults} Adults, ${widget.children} Children",
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. ROOM LIST
              _isLoading
                  ? SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: amvGold)),
                    )
                  : _rooms.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 50, color: Colors.grey[300]),
                                const SizedBox(height: 10),
                                Text(
                                  "No rooms available for these dates.",
                                  style: GoogleFonts.montserrat(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120), // Bottom padding for sticky bar
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return RoomRevealWrapper(
                                  index: index,
                                  child: _buildRoomCard(_rooms[index]),
                                );
                              },
                              childCount: _rooms.length,
                            ),
                          ),
                        ),
            ],
          ),

          // 3. STICKY BOTTOM SUMMARY (Slides Up)
          _buildBottomSummary(),
        ],
      ),
    );
  }

  // 🟢 UPDATED: Engaging Room Card
  Widget _buildRoomCard(dynamic room) {
    bool isSelected = _selectedRooms.any((r) => r['id'] == room['id']);
    String rawUrl = room['full_image_url'] ?? "";
    String imageUrl = Uri.encodeFull(rawUrl);

    return GestureDetector(
      onTap: () => _toggleRoom(room),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? amvGold : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? amvGold.withOpacity(0.2) : Colors.black.withOpacity(0.08),
              blurRadius: isSelected ? 15 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE HEADER (Full Bleed)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: Colors.grey[300], child: const Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                // Price Tag
                Positioned(
                  top: 15,
                  right: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
                    ),
                    child: Text(
                      "₱${double.parse(room['price'].toString()).toStringAsFixed(0)}",
                      style: GoogleFonts.montserrat(
                        color: amvViolet,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                // Selected Indicator
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: amvGold.withOpacity(0.2),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check, color: amvGold, size: 30),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // 2. ROOM DETAILS
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    room['name'] ?? "Room Name",
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    room['description'] ?? "Experience luxury and comfort.",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Icons Row
                  Row(
                    children: [
                      _buildDetailBadge(Icons.bed, room['bed_type'] ?? "King Bed"),
                      const SizedBox(width: 10),
                      _buildDetailBadge(Icons.person, "${room['capacity'] ?? 2} Guests"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: amvViolet.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: amvViolet),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: amvViolet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSummary() {
    bool hasSelection = _selectedRooms.isNotEmpty;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 600),
      curve: Curves.fastOutSlowIn,
      bottom: hasSelection ? 0 : -150,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(25, 20, 25, 30), // Extra bottom padding for safe area
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_selectedRooms.length} Selected",
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "₱${_calculateTotal().toStringAsFixed(2)}",
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: amvViolet,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                if (_isBookingBlocked) {
                  _showBookingLimitModal();
                  return;
                }
                
                if (hasSelection) {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          GuestInfoScreen(
                        dateRange: widget.dateRange,
                        selectedRooms: _selectedRooms,
                        adults: widget.adults,
                        children: widget.children,
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        var begin = const Offset(0.0, 1.0);
                        var end = Offset.zero;
                        var curve = Curves.fastOutSlowIn;
                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        return SlideTransition(position: animation.drive(tween), child: child);
                      },
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: amvViolet,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 8,
                shadowColor: amvViolet.withOpacity(0.4),
              ),
              child: Row(
                children: [
                  Text(
                    "CONTINUE",
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🟢 Animation Wrapper for Staggered List
class RoomRevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const RoomRevealWrapper({required this.index, required this.child});

  @override
  _RoomRevealWrapperState createState() => _RoomRevealWrapperState();
}

class _RoomRevealWrapperState extends State<RoomRevealWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // Stagger based on index
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
        position: _offsetAnimation,
        child: widget.child,
      ),
    );
  }
}