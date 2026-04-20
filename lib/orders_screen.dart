import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'api_config.dart';
import 'notification_button.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  bool _isLoading = true;
  List<dynamic> _orders = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();

    // Start Real-time Refresh Timer (every 10 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !_isLoading) {
        _fetchOrders();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api_get_my_orders.php"),
        body: {"uid": user.uid},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _orders = data['data'];
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Mark Order as Read Logic
  Future<void> _markAsRead(int orderId) async {
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api_mark_order_read.php"),
        body: json.encode({'order_id': orderId}),
      );
      if (response.statusCode == 200) {
        _fetchOrders();
      }
    } catch (e) {
      print("Error marking order as read: $e");
    }
  }

  // 🟢 NEW: Smooth Details Modal using showGeneralDialog
  void _showOrderDetails(Map<String, dynamic> order) {
    String status = order['status'] ?? 'Pending';
    String dateStr = order['order_date'] ?? '';
    try {
      DateTime dt = DateTime.parse(order['order_date']);
      dateStr = DateFormat('MMMM dd, yyyy • h:mm a').format(dt);
    } catch (_) {}

    Color statusColor = Colors.orange;
    if (status.toLowerCase() == 'served' || status.toLowerCase() == 'completed') {
      statusColor = Colors.green;
    } else if (status.toLowerCase() == 'cancelled') {
      statusColor = Colors.red;
    } else if (status.toLowerCase() == 'preparing') {
      statusColor = Colors.blue;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 600),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
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
                            child: Icon(Icons.restaurant_rounded, size: 35, color: statusColor),
                          ),
                          
                          const SizedBox(height: 12),

                          // 2. Title & Date
                          Text(
                            "Order Details",
                            style: GoogleFonts.montserrat(
                              fontSize: 18, fontWeight: FontWeight.bold, color: amvViolet
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
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
                                Icon(Icons.info_outline, size: 14, color: statusColor),
                                const SizedBox(width: 6),
                                Text(
                                  status.toString().toUpperCase(),
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

                          // 4. Info Section
                          _buildDetailRow(Icons.room_rounded, "Deliver To", "Room ${order['room_number']}"),
                          _buildDetailRow(Icons.payment_rounded, "Payment Method", order['payment_method'] ?? "Cash"),
                          
                          const SizedBox(height: 15),
                          
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "ITEMS ORDERED",
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                                color: Colors.grey[400],
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._parseItemsForDetail(order['items']),
                          
                          if (order['notes'] != null && order['notes'].toString().isNotEmpty) ...[
                            const SizedBox(height: 15),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[100]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Special Instructions:",
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    order['notes'],
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 15),

                          // 5. Total Price
                          Text(
                            "TOTAL AMOUNT", 
                            style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1)
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "₱${double.parse(order['total_price'].toString()).toStringAsFixed(2)}",
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

  List<Widget> _parseItemsForDetail(String itemsJson) {
    List<Widget> widgets = [];
    try {
      Map<String, dynamic> itemsMap = json.decode(itemsJson);
      itemsMap.forEach((name, qty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$name", 
                  style: GoogleFonts.montserrat(fontSize: 13, color: Colors.black87)
                ),
                Text("x$qty", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: amvViolet)),
              ],
            ),
          ),
        );
      });
    } catch (e) {
      widgets.add(const Text("No items found"));
    }
    return widgets;
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
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          "My Orders",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: amvViolet,
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [NotificationButton(backgroundColor: Colors.transparent)],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: amvGold))
          : _orders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  color: amvGold,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      return OrderRevealWrapper(
                        index: index,
                        child: _buildOrderCard(_orders[index]),
                      );
                    },
                  ),
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
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey[300]),
          ),
          const SizedBox(height: 20),
          Text(
            "No Active Orders",
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your food orders will appear here.",
            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  // 🟢 Enhanced Card Design
  Widget _buildOrderCard(Map<String, dynamic> order) {
    String status = order['status'] ?? 'Pending';
    Color statusColor = Colors.orange;
    if (status.toLowerCase() == 'served' || status.toLowerCase() == 'completed') {
      statusColor = Colors.green;
    } else if (status.toLowerCase() == 'cancelled') {
      statusColor = Colors.red;
    } else if (status.toLowerCase() == 'preparing') {
      statusColor = Colors.blue;
    }

    String dateStr = order['order_date'] ?? '';
    try {
      DateTime dt = DateTime.parse(order['order_date']);
      dateStr = DateFormat('MMM dd • h:mm a').format(dt);
    } catch (_) {}

    // Extract first item for preview
    String itemPreview = "Items...";
    try {
      Map<String, dynamic> itemsMap = json.decode(order['items']);
      if (itemsMap.isNotEmpty) {
        String firstKey = itemsMap.keys.first;
        itemPreview = "${itemsMap[firstKey]}x $firstKey";
        if (itemsMap.length > 1) {
          itemPreview += " + ${itemsMap.length - 1} more";
        }
      }
    } catch (e) {
      itemPreview = "Unknown Items";
    }

    bool isRead = (order['is_read_by_user'] == 1 || order['is_read_by_user'] == '1');
    bool isNewOrder = false;

    if (order['order_date'] != null && !isRead) {
      try {
        DateTime orderDate = DateTime.parse(order['order_date']);
        isNewOrder = DateTime.now().difference(orderDate).inHours < 24;
      } catch (e) {
        isNewOrder = false;
      }
    }

    return GestureDetector(
      onTap: () {
        _showOrderDetails(order);
        if (!isRead) {
          _markAsRead(int.parse(order['id'].toString()));
        }
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
                      Text(
                        "Order #${order['id']}",
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: amvViolet,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    itemPreview,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateStr,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "₱${double.parse(order['total_price'].toString()).toStringAsFixed(2)}",
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: amvGold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // New Badge
          if (isNewOrder)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: amvGold,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  "NEW",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OrderRevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;
  const OrderRevealWrapper({Key? key, required this.index, required this.child}) : super(key: key);
  @override
  State<OrderRevealWrapper> createState() => _OrderRevealWrapperState();
}

class _OrderRevealWrapperState extends State<OrderRevealWrapper> with SingleTickerProviderStateMixin {
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
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
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
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}