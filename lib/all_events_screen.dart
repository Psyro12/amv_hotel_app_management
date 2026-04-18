import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'api_config.dart';

class AllEventsScreen extends StatefulWidget {
  final Animation<double>? transitionAnimation;

  const AllEventsScreen({Key? key, this.transitionAnimation}) : super(key: key);

  @override
  _AllEventsScreenState createState() => _AllEventsScreenState();
}

class _AllEventsScreenState extends State<AllEventsScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    // Keep the delay for smooth animation entry
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();
    const String cacheKey = 'all_events_screen_cache';
    String apiUrl = "${ApiConfig.baseUrl}/api_get_events.php";

    // Step A: Load Cache
    String? cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final jsonResponse = json.decode(cachedData);
      if (mounted) {
        setState(() {
          _events = jsonResponse['data'];
          _isLoading = false;
        });
      }
    }

    // Step B: Fetch Fresh
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          await prefs.setString(cacheKey, response.body);
          if (mounted) {
            setState(() {
              _events = jsonResponse['data'];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching events: $e");
      if (mounted && _events.isEmpty) setState(() => _isLoading = false);
    }
  }

  void _showEventDetails(Map<String, dynamic> event) {
    String imageUrl = Uri.encodeFull(event['full_image_url']);
    String title = event['title'] ?? "Event";
    String date = event['formatted_date'] ?? "";
    String time = event['time_start'] ?? "TBA";
    String content = event['description'] ?? event['content'] ?? "No details available.";
    String rawDate = event['event_date'] ?? "";

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            EventDetailScreen(
              title: title,
              imageUrl: imageUrl,
              dateString: date,
              timeString: time,
              content: content,
              rawDate: rawDate,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.fastOutSlowIn;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> headerFade = widget.transitionAnimation != null
        ? Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: widget.transitionAnimation!,
              curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
            ),
          )
        : const AlwaysStoppedAnimation(1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverPadding(padding: EdgeInsets.only(top: 80)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                sliver: _isLoading
                    ? SliverToBoxAdapter(
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(color: amvGold),
                        ),
                      )
                    : _events.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Center(child: Text("No events found")),
                          )
                        : SliverGrid.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 15,
                            crossAxisSpacing: 15,
                            childAspectRatio: 0.7, // Taller for poster look
                            children: List.generate(_events.length, (index) {
                              return EventRevealWrapper(
                                index: index,
                                child: _buildEventGridCard(_events[index]),
                              );
                            }),
                          ),
              ),
            ],
          ),

          // Header
          FadeTransition(
            opacity: headerFade,
            child: Container(
              height: 80,
              padding: const EdgeInsets.only(top: 30, left: 5, right: 5),
              decoration: BoxDecoration(
                color: amvViolet,
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    "All Events",
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 UPDATED: Immersive "Event Poster" Card
  Widget _buildEventGridCard(dynamic event) {
    String rawUrl = event['full_image_url'];
    String imageUrl = Uri.encodeFull(rawUrl);
    String title = event['title'] ?? "Event";
    String dateString = event['formatted_date'] ?? "";
    
    // Parse Date for Badge
    String month = "JAN";
    String day = "01";
    try {
      List<String> parts = dateString.split(' ');
      if (parts.isNotEmpty) month = parts[0].substring(0, 3).toUpperCase();
      if (parts.length > 1) day = parts[1].replaceAll(',', '');
    } catch (e) {}

    return GestureDetector(
      onTap: () => _showEventDetails(event),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black, // Dark background for loading
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full Image with Hero
              Hero(
                tag: imageUrl, // Hero animation tag
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SkeletonContainer(
                      width: double.infinity, 
                      height: double.infinity, 
                      borderRadius: 0, 
                      icon: Icons.image
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => 
                      Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white24)),
                ),
              ),

              // 2. Gradient Overlay (Bottom Up)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.5, 0.7, 1.0],
                  ),
                ),
              ),

              // 3. Date Badge (Top Left)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        month,
                        style: GoogleFonts.montserrat(
                          color: amvViolet,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        day,
                        style: GoogleFonts.montserrat(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Title & Action (Bottom)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [const Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          "View Details",
                          style: GoogleFonts.montserrat(
                            color: amvGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, color: amvGold, size: 10),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🟢 Reusing Components for Consistency

class EventDetailScreen extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String dateString;
  final String timeString;
  final String content;
  final String rawDate; 

  const EventDetailScreen({
    Key? key,
    required this.title,
    required this.imageUrl,
    required this.dateString,
    required this.timeString,
    required this.content,
    required this.rawDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color amvGold = const Color(0xFFD4AF37);
    final Color amvViolet = const Color(0xFF2D0F35);

    String statusText = "UPCOMING EVENT";
    Color statusColor = amvGold; 
    
    try {
      DateTime? eventDate;
      if (rawDate.isNotEmpty) {
         eventDate = DateTime.parse(rawDate);
      } else {
         eventDate = DateFormat("MMMM d, yyyy").parse(dateString); 
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eDate = DateTime(eventDate.year, eventDate.month, eventDate.day);

      if (eDate.isBefore(today)) {
        statusText = "PAST EVENT";
        statusColor = Colors.grey; 
      } else if (eDate.isAtSameMomentAs(today)) {
        statusText = "HAPPENING NOW";
        statusColor = Colors.green; 
      }
    } catch (e) {}

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // IMMERSIVE HEADER
          SliverAppBar(
            expandedHeight: 400, // Taller header
            pinned: true,
            backgroundColor: amvViolet,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: imageUrl, // Matches grid card tag
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SkeletonContainer(width: double.infinity, height: double.infinity, borderRadius: 0, icon: Icons.event);
                      },
                      errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900]),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.8)],
                        stops: const [0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              statusText,
                              style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: GoogleFonts.montserrat(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                              shadows: [Shadow(blurRadius: 10.0, color: Colors.black.withOpacity(0.5), offset: const Offset(0, 2))],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CONTENT
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      Expanded(child: _buildInfoItem(Icons.calendar_today, "DATE", dateString, amvViolet)),
                      Expanded(child: _buildInfoItem(Icons.access_time_filled, "TIME", timeString, amvViolet)),
                    ],
                   ),
                   const SizedBox(height: 30),
                   Divider(color: Colors.grey[200]),
                   const SizedBox(height: 20),
                   Text("About this Event", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                   const SizedBox(height: 10),
                   Html(
                     data: content,
                     style: {
                       "body": Style(fontFamily: GoogleFonts.montserrat().fontFamily, fontSize: FontSize(15), lineHeight: LineHeight(1.8), color: Colors.grey[700], margin: Margins.zero),
                       "p": Style(margin: Margins.only(bottom: 15)),
                     },
                   ),
                   const SizedBox(height: 50),
                   Center(child: Icon(Icons.star, color: amvGold.withOpacity(0.3), size: 30)),
                   const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(value, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ],
    );
  }
}

// 4. SKELETON CONTAINER CLASS (Required for images)
class SkeletonContainer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final IconData? icon; 

  const SkeletonContainer({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.icon, 
  }) : super(key: key);

  @override
  _SkeletonContainerState createState() => _SkeletonContainerState();
}

class _SkeletonContainerState extends State<SkeletonContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[400],
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: widget.icon != null
            ? Center(
                child: Icon(widget.icon, color: Colors.white.withOpacity(0.5), size: 30),
              )
            : null,
      ),
    );
  }
}

class EventRevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const EventRevealWrapper({required this.index, required this.child});

  @override
  _EventRevealWrapperState createState() => _EventRevealWrapperState();
}

class _EventRevealWrapperState extends State<EventRevealWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) {
        _controller.forward();
      }
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