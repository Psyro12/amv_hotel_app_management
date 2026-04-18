import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReceiptScreen extends StatelessWidget {
  final Map<String, int> cartItems;
  final List<dynamic> foodData;
  final num subtotal;
  final num deliveryFee;
  final num grandTotal;
  final String deliveryLocation;
  final String contactNumber;
  final String paymentMethod;
  final String orderDate;

  const ReceiptScreen({
    Key? key,
    required this.cartItems,
    required this.foodData,
    required this.subtotal,
    required this.deliveryFee,
    required this.grandTotal,
    required this.deliveryLocation,
    required this.contactNumber,
    required this.paymentMethod,
    required this.orderDate,
  }) : super(key: key);

  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: amvViolet,
      body: SafeArea(
        child: SingleChildScrollView( // 🟢 Added to prevent overflow
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // RECEIPT CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      children: [
                        // Success Icon
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle, color: Colors.green, size: 50),
                        ),
                        const SizedBox(height: 15),
                        Text("Payment Success!", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: amvViolet)),
                        Text(orderDate, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
                        
                        const SizedBox(height: 20),
                        Divider(color: Colors.grey[300], thickness: 1), 
                        const SizedBox(height: 10),

                        // ITEMS LIST
                        ...cartItems.entries.map((entry) {
                          var item = foodData.firstWhere((element) => element['item_name'] == entry.key, orElse: () => {});
                          double price = item.isNotEmpty ? (double.tryParse(item['price'].toString()) ?? 0.0) : 0.0;
                          double totalItemPrice = price * entry.value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text("${entry.key} (x${entry.value})", 
                                    style: GoogleFonts.montserrat(fontSize: 13, color: Colors.black87),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text("₱${totalItemPrice.toStringAsFixed(2)}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          );
                        }).toList(),

                        const SizedBox(height: 10),
                        Divider(color: Colors.grey[300], thickness: 1),
                        const SizedBox(height: 10),

                        // TOTALS
                        _buildSummaryRow("Subtotal", subtotal.toDouble()),
                        _buildSummaryRow("Delivery Fee", deliveryFee.toDouble()),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("TOTAL PAID", style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: amvViolet)),
                            Text("₱${grandTotal.toDouble().toStringAsFixed(2)}", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: amvViolet)),
                          ],
                        ),

                        const SizedBox(height: 20),
                        
                        // DELIVERY INFO BOX
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow("Deliver To:", deliveryLocation),
                              if(contactNumber.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildInfoRow("Contact:", contactNumber),
                              ],
                              const SizedBox(height: 8),
                              _buildInfoRow("Payment:", paymentMethod),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // HOME BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        // 🟢 Returns to home with a slide-down animation
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("BACK TO HOME", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildSummaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
          Text("₱${amount.toStringAsFixed(2)}", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 70, child: Text(label, style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey))),
        Expanded(child: Text(value, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold))),
      ],
    );
  }
}
