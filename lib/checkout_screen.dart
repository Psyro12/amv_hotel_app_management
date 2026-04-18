import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_config.dart';
import 'gcash_payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, int> cartItems;
  final List<dynamic> foodData;
  final List<dynamic> roomData;

  final Function(
    String,
    String,
    String, {
    bool isOutside,
    String phone,
    File? receiptImage,
    String? paymentRef, // 🟢 Added this
  }) onSubmit;

  final Animation<double> transitionAnimation;

  const CheckoutScreen({
    Key? key,
    required this.cartItems,
    required this.foodData,
    required this.roomData,
    required this.onSubmit,
    required this.transitionAnimation,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  final _roomCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _paymentMethod = "Charge to Room";
  double _subtotal = 0;
  double _grandTotal = 0;

  // 🟢 Security Flags
  bool _hasActiveBooking = false;
  bool _isLoadingRoom = true;
  bool _isBlocked = false; // 🟢 New block flag
  Timer? _statusTimer;
  List<String> _availableRooms = []; // 🟢 List of rooms for the user

  String _gcashName = "Loading...";
  String _gcashNumber = "";
  String? _gcashQrUrl;
  File? _receiptImage;
  String? _paymentRef; // 🟢 Store extracted reference

  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _calculateTotals();
    _fetchActiveBooking();
    _fetchPaymentSettings();
    _checkUserStatus();

    // 🟢 Real-time status polling (Every 5 seconds)
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkUserStatus();
    });

    final curvedAnimation = CurvedAnimation(
      parent: widget.transitionAnimation,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(curvedAnimation);
  }

  @override
  void dispose() {
    _statusTimer?.cancel(); // 🟢 Cleanup
    super.dispose();
  }

  // 🟢 NEW: Check User Block Status
  Future<void> _checkUserStatus() async {
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
              _isBlocked = data['is_blocked'] ?? false;
            });
          }
        }
      }
    } catch (e) {
      print("Error checking user status: $e");
    }
  }

  // 🟢 ENHANCED: Premium Slide-Up Modal for Order Limit
  void _showOrderLimitModal() {
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
                                                      child: Icon(Icons.shopping_cart_checkout_rounded, color: amvGold, size: 45),
                                                    ),
                                                    const SizedBox(height: 25),
                                                    Text(
                                                      "ORDER LIMIT REACHED",
                                                      textAlign: TextAlign.center, // 🟢 Centered
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w800,
                                                        color: amvViolet,
                                                        letterSpacing: 1.2,
                                                      ),
                                                    ),                          const SizedBox(height: 15),
                          Text(
                            "You have 4 active pending orders. To maintain our high standard of service, please allow us to process your current orders before placing new ones.",
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
                            "Need help? Contact Front Desk",
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

  Future<void> _fetchActiveBooking() async {
    final prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('user_id') ?? "";

    if (userId.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userId = user.uid;
        await prefs.setString('user_id', userId);
      }
    }

    if (userId.isEmpty) {
      if (mounted) setState(() => _isLoadingRoom = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api_get_my_bookings.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({'uid': userId, 'type': 'active'}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          List<dynamic> bookings = jsonResponse['data'];
          List<String> allRooms = [];
          for (var booking in bookings) {
            String arrivalStatus = (booking['arrival_status'] ?? "").toString().toLowerCase().trim();
            
            // 🟢 Check if user is officially checked in
            if (arrivalStatus == "in_house" || arrivalStatus == "checked_in" || arrivalStatus == "checked in") {
              String roomNames = booking['room_names'] ?? booking['room_name'] ?? "";
              // Split by comma, trim, and remove empty results
              List<String> splitRooms = roomNames.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              allRooms.addAll(splitRooms);
            }
          }

          if (allRooms.isNotEmpty) {
            if (mounted) {
              setState(() {
                // Remove duplicates just in case
                _availableRooms = allRooms.toSet().toList();
                _roomCtrl.text = _availableRooms.first;
                _hasActiveBooking = true;
              });
            }
          }
        }
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingRoom = false);
    }
  }

  void _calculateTotals() {
    double total = 0;
    widget.cartItems.forEach((key, qty) {
      var item = widget.foodData.firstWhere(
        (element) => element['item_name'] == key,
        orElse: () => {},
      );
      if (item.isNotEmpty) {
        double price = double.tryParse(item['price'].toString()) ?? 0;
        total += price * qty;
      }
    });

    setState(() {
      _subtotal = total;
      _grandTotal = _subtotal;
    });
  }

  Future<void> _handleSubmit() async {
    // Extra safety check
    if (!_hasActiveBooking) {
      _showError("You must be checked in to order.");
      return;
    }

    if (_roomCtrl.text.trim().isEmpty) {
      _showError("Room identification failed.");
      return;
    }

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
              amountToPay: _grandTotal,
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
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );

      if (result != null && result is Map) {
        setState(() {
          _receiptImage = result['image'];
          _paymentRef = result['reference'];
        });
        _finalizeOrder();
      }
    } else {
      _finalizeOrder();
    }
  }

  void _finalizeOrder() {
    String location = _roomCtrl.text;
    FocusScope.of(context).unfocus();
    Navigator.pop(context);

    Future.delayed(const Duration(milliseconds: 200), () {
      widget.onSubmit(
        location,
        _paymentMethod,
        _notesCtrl.text,
        isOutside: false,
        phone: "",
        receiptImage: _receiptImage,
        paymentRef: _paymentRef, // 🟢 Passing the ref
      );
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.montserrat()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: amvViolet,
        elevation: 0,
        leading: SlideTransition(
          position: _headerSlide,
          child: FadeTransition(
            opacity: _headerFade,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: SlideTransition(
          position: _headerSlide,
          child: FadeTransition(
            opacity: _headerFade,
            child: Text(
              "Checkout",
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120), // Padding for sticky bottom
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Order Receipt Card
            Container(
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
                  Text("ORDER SUMMARY", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.5)),
                  const SizedBox(height: 20),
                  ...widget.cartItems.entries.map((entry) {
                    var item = widget.foodData.firstWhere((element) => element['item_name'] == entry.key, orElse: () => {});
                    double price = item.isNotEmpty ? double.tryParse(item['price'].toString()) ?? 0 : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(5)),
                                  child: Text("${entry.value}x", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: amvViolet)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(entry.key, style: GoogleFonts.montserrat(fontSize: 14, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                          Text("₱${(price * entry.value).toStringAsFixed(2)}", style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                    );
                  }).toList(),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Subtotal", style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600])),
                      Text("₱${_subtotal.toStringAsFixed(2)}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 🟢 2. Room Detection Section (SECURITY UPDATE)
            Text("DELIVER TO", style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
            const SizedBox(height: 15),
            
            _isLoadingRoom
              ? Center(child: CircularProgressIndicator(color: amvViolet))
              : _hasActiveBooking
                // ✅ Case A: User IS In-House
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user, color: Colors.green),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Verified Stay", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                              _availableRooms.length > 1
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _roomCtrl.text,
                                          isExpanded: true,
                                          isDense: true,
                                          icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                                          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                          items: _availableRooms.map((String room) {
                                            return DropdownMenuItem<String>(
                                              value: room,
                                              child: Text(room),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              setState(() {
                                                _roomCtrl.text = newValue;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Multiple rooms detected. Please select which room should receive this order.",
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(_roomCtrl.text, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                            ],
                          ),
                        ),
                        if (_availableRooms.length <= 1) const Icon(Icons.lock, color: Colors.grey, size: 18),
                      ],
                    ),
                  )
                // ⛔ Case B: User NOT In-House
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.no_meeting_room, color: Colors.red[300], size: 40),
                        const SizedBox(height: 10),
                        Text(
                          "No Active Booking Found",
                          style: GoogleFonts.montserrat(
                            color: Colors.red[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 14
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Ordering is only available for guests currently checked into the hotel.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            color: Colors.grey[600],
                            fontSize: 12
                          ),
                        ),
                      ],
                    ),
                  ),

            const SizedBox(height: 25),

            // 3. Engaging Payment Selector
            Text("PAYMENT METHOD", style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildPaymentCard("Charge to Room", Icons.bed, "Pay later")),
                const SizedBox(width: 15),
                Expanded(child: _buildPaymentCard("GCash", Icons.phone_android, "Pay now")),
              ],
            ),

            const SizedBox(height: 25),

            // 4. Notes Input
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Special Instructions (Optional)",
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes, color: amvGold),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
      ),

      // 5. Sticky Bottom Bar
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
                  Text("₱${_grandTotal.toStringAsFixed(2)}", style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: amvViolet)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // 🟢 LOGIC: Button is always enabled if checked in, but shows popup if blocked
                  onPressed: _hasActiveBooking 
                    ? () {
                        if (_isBlocked) {
                          _showOrderLimitModal();
                        } else {
                          _handleSubmit();
                        }
                      }
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasActiveBooking ? amvViolet : Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: _hasActiveBooking ? 5 : 0,
                    shadowColor: amvViolet.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                    _hasActiveBooking 
                      ? (_paymentMethod == "GCash" ? "PAY NOW & ORDER" : "PLACE ORDER")
                      : "CHECK-IN REQUIRED",
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold, 
                      color: _hasActiveBooking ? Colors.white : Colors.grey[500], 
                      fontSize: 16, 
                      letterSpacing: 1
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

  // 🟢 Custom Payment Card Widget
  Widget _buildPaymentCard(String title, IconData icon, String subtitle) {
    bool isSelected = _paymentMethod == title;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? amvViolet.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? amvViolet : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected 
            ? [BoxShadow(color: amvViolet.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] 
            : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? amvViolet : Colors.grey[400], size: 30),
            const SizedBox(height: 10),
            Text(title, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? amvViolet : Colors.grey[700]), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}