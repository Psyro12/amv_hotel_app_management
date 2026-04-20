import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'api_config.dart';

class TransactionsScreen extends StatefulWidget {
  final String userId;
  const TransactionsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _isLoading = true;
  bool _showData = false;
  List<dynamic> _transactions = [];

  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    // Delay slightly to allow page transition to complete
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _showData = true);
        _fetchTransactions();
      }
    });
  }

  Future<void> _fetchTransactions() async {
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api_get_my_transactions.php"),
        body: {"uid": widget.userId},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _transactions = data['data'];
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
      print("❌ Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Overflow-Safe Receipt Modal
  void _showMessageStyleDetails(Map<String, dynamic> tx) {
    String category = tx['category'] ?? "General";
    String status = tx['status']?.toString().toUpperCase() ?? "PENDING";
    
    IconData icon = category == 'Food Order' ? Icons.restaurant_rounded : Icons.bed_rounded;
    Color statusColor = (status == "PAID" || status == "COMPLETED") 
        ? Colors.green 
        : (status == "CANCELLED" ? Colors.red : Colors.orange);

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
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(5)),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // 1. Hero Icon
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: amvViolet.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 35, color: amvViolet),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // 2. Category
                          Text(
                            category.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.2
                            ),
                          ),
                          
                          const SizedBox(height: 4),

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
                                  status,
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
                          _buildDetailRow(Icons.tag_rounded, "Reference ID", tx['ref_id']?.toString() ?? "N/A"),
                          _buildDetailRow(Icons.payment_rounded, "Payment Method", tx['payment_method']?.toString() ?? "Cash"),
                          _buildDetailRow(Icons.calendar_today_rounded, "Date", tx['date']?.toString() ?? "N/A"),
                          
                          const SizedBox(height: 15),
                          
                          // 5. Amount
                          Text(
                            "TOTAL AMOUNT", 
                            style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1)
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "₱${double.tryParse(tx['amount'].toString())?.toStringAsFixed(2) ?? "0.00"}",
                            style: GoogleFonts.montserrat(
                              fontSize: 24, fontWeight: FontWeight.w800, color: amvViolet
                            ),
                          ),
                          const SizedBox(height: 20),
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
                      child: Text("CLOSE RECEIPT", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12, letterSpacing: 0.5)),
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
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: amvViolet,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Transaction History",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
      ),
      body: !_showData || _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _transactions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator( // 🟢 1. Wrap ListView in RefreshIndicator
                  onRefresh: _fetchTransactions,
                  color: amvGold,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works even if list is short
                    padding: const EdgeInsets.all(20),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      return TransactionRevealWrapper(
                        index: index,
                        child: _buildTransactionCard(_transactions[index]),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    String rawDate = tx['date']?.toString() ?? "";
    String formattedDate = rawDate;
    try {
      if (rawDate.isNotEmpty) {
        DateTime dt = DateTime.parse(rawDate);
        formattedDate = DateFormat('MMM dd, yyyy • h:mm a').format(dt);
      }
    } catch (e) {
      formattedDate = rawDate;
    }

    String statusText = tx['status']?.toString().toLowerCase() ?? 'pending';
    Color statusColor = (statusText == 'paid' || statusText == 'completed') 
        ? Colors.green 
        : (statusText == 'cancelled' ? Colors.red : Colors.orange);

    IconData catIcon = (tx['category'] == 'Food Order') ? Icons.restaurant_rounded : Icons.bed_rounded;

    return GestureDetector(
      onTap: () => _showMessageStyleDetails(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: amvViolet.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(catIcon, color: amvViolet, size: 24),
            ),
            const SizedBox(width: 15),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx['category'] ?? "Transaction",
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate, 
                    style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)
                  ),
                ],
              ),
            ),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₱${double.tryParse(tx['amount'].toString())?.toStringAsFixed(2) ?? "0.00"}",
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: amvGold, fontSize: 16),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🟢 2. Refreshable Empty State
  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _fetchTransactions,
      color: amvGold,
      child: SingleChildScrollView( // Must be scrollable for RefreshIndicator to work
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8, // Take up screen height
          child: Center(
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
                  child: Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey[300]),
                ),
                const SizedBox(height: 20),
                Text("No transactions yet", style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TransactionRevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const TransactionRevealWrapper({Key? key, required this.index, required this.child}) : super(key: key);

  @override
  State<TransactionRevealWrapper> createState() => _TransactionRevealWrapperState();
}

class _TransactionRevealWrapperState extends State<TransactionRevealWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 80), () {
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
    return FadeTransition(opacity: _fadeAnimation, child: SlideTransition(position: _slideAnimation, child: widget.child));
  }
}