import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'api_config.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  bool _isLoading = true;
  List<dynamic> _policyData = [];

  // Track expanded state manually for smooth animations
  int _expandedIndex = 0; // Default first item open

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/api_get_privacy.php"));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _policyData = data['data'];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching privacy policy: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          "Privacy Policy",
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
          : _policyData.isEmpty
              ? Center(child: Text("No information available", style: GoogleFonts.montserrat()))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _policyData.length + 1, // +1 for Header
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildHeader();
                    }
                    final section = _policyData[index - 1];
                    return _buildSmoothCard(section, index - 1);
                  },
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: amvViolet.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, size: 50, color: amvViolet),
          ),
          const SizedBox(height: 15),
          Text(
            "Your Data & Privacy",
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "We are committed to protecting your personal information.",
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 Custom Smooth Card
  Widget _buildSmoothCard(Map<String, dynamic> section, int index) {
    final bool isExpanded = _expandedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          // Toggle: If clicking same, close it. If different, open new one.
          _expandedIndex = isExpanded ? -1 : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic, // 🟢 The "Buttery" Curve
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: isExpanded ? amvViolet : Colors.white, // Active changes color
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isExpanded ? 0.2 : 0.05),
              blurRadius: isExpanded ? 15 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header (Always Visible)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isExpanded ? Colors.white.withOpacity(0.2) : amvViolet.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.article_outlined, 
                      size: 20, 
                      color: isExpanded ? Colors.white : amvViolet
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      section['title'] ?? "Section $index",
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isExpanded ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0, // Rotates arrow 180 degrees
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down, 
                      color: isExpanded ? Colors.white70 : Colors.grey
                    ),
                  ),
                ],
              ),
            ),

            // Body (Animated Height)
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic, // 🟢 Smooth expansion
              alignment: Alignment.topCenter,
              child: Container(
                height: isExpanded ? null : 0, // Auto height when open, 0 when closed
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: isExpanded
                    ? Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Html(
                          data: section['content'] ?? "",
                          style: {
                            "body": Style(
                              fontFamily: GoogleFonts.montserrat().fontFamily,
                              fontSize: FontSize(14),
                              color: Colors.grey[800],
                              lineHeight: LineHeight(1.6),
                              margin: Margins.zero,
                            ),
                            "li": Style(margin: Margins.only(bottom: 8)),
                          },
                        ),
                      )
                    : const SizedBox(), // Empty when collapsed
              ),
            ),
          ],
        ),
      ),
    );
  }
}