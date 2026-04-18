import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'api_config.dart';

class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({Key? key}) : super(key: key);

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  bool _isLoading = true;
  List<dynamic> _termsData = [];
  
  // Track expanded state for accordion effect
  int _expandedIndex = 0; 

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    // Slight delay to allow the screen transition to finish before loading data
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/api_get_terms.php"));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _termsData = data['data'];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching terms: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          "Terms & Conditions",
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
          : _termsData.isEmpty
              ? Center(child: Text("No terms available", style: GoogleFonts.montserrat()))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _termsData.length + 1, // +1 for Header
                  itemBuilder: (context, index) {
                    // 1. Render Header
                    if (index == 0) {
                      return TermsRevealWrapper(
                        index: 0,
                        child: _buildHeader(),
                      );
                    }
                    
                    // 2. Render List Items
                    final term = _termsData[index - 1];
                    return TermsRevealWrapper(
                      index: index, // Stagger based on index
                      child: _buildSmoothCard(term, index - 1),
                    );
                  },
                ),
    );
  }

  // 🟢 Visual Header
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: amvGold.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.gavel_rounded, size: 50, color: amvGold),
          ),
          const SizedBox(height: 15),
          Text(
            "Terms of Service",
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Please read these terms carefully before using our service.",
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

  // 🟢 Custom Smooth Accordion Card
  Widget _buildSmoothCard(Map<String, dynamic> term, int index) {
    final bool isExpanded = _expandedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          // Toggle logic: Close if clicked again, otherwise open new
          _expandedIndex = isExpanded ? -1 : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic, // Premium smooth curve
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isExpanded ? 0.15 : 0.05),
              blurRadius: isExpanded ? 15 : 10,
              offset: const Offset(0, 4),
            ),
          ],
          // Active Border Color
          border: isExpanded ? Border.all(color: amvGold.withOpacity(0.5), width: 1.5) : null,
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
                      color: isExpanded ? amvGold.withOpacity(0.2) : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.description_outlined, 
                      size: 20, 
                      color: isExpanded ? amvGold : Colors.grey[600]
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      term['title'] ?? "Clause $index",
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isExpanded ? amvViolet : Colors.black87,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0, // Rotates arrow 180 degrees
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down, 
                      color: isExpanded ? amvGold : Colors.grey
                    ),
                  ),
                ],
              ),
            ),

            // Body (Animated Height)
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic, // Smooth expansion
              alignment: Alignment.topCenter,
              child: Container(
                height: isExpanded ? null : 0, // Auto height when open, 0 when closed
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: isExpanded
                    ? Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Html(
                          data: term['content'] ?? "",
                          style: {
                            "body": Style(
                              fontFamily: GoogleFonts.montserrat().fontFamily,
                              fontSize: FontSize(14),
                              color: Colors.grey[800],
                              lineHeight: LineHeight(1.6),
                              margin: Margins.zero,
                            ),
                            "ul": Style(padding: HtmlPaddings.only(left: 10)),
                            "li": Style(margin: Margins.only(bottom: 8)),
                          },
                        ),
                      )
                    : const SizedBox(), // Empty when collapsed to avoid rendering cost
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🟢 Entrance Animation Wrapper
class TermsRevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const TermsRevealWrapper({Key? key, required this.index, required this.child}) : super(key: key);

  @override
  State<TermsRevealWrapper> createState() => _TermsRevealWrapperState();
}

class _TermsRevealWrapperState extends State<TermsRevealWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Staggered Delay based on index
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