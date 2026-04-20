import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'package:flutter_html/flutter_html.dart';

class AllNewsScreen extends StatefulWidget {
  final Animation<double>? transitionAnimation;

  const AllNewsScreen({Key? key, this.transitionAnimation}) : super(key: key);

  @override
  _AllNewsScreenState createState() => _AllNewsScreenState();
}

class _AllNewsScreenState extends State<AllNewsScreen> {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  List<dynamic> _allNews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllNews();
  }

  Future<void> _fetchAllNews() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();
    const String cacheKey = 'all_news_screen_cache';
    String apiUrl = "${ApiConfig.baseUrl}/api_get_news.php";

    // Step A: Load Cache
    String? cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final jsonResponse = json.decode(cachedData);
      if (mounted) {
        setState(() {
          _allNews = jsonResponse['data'];
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
              _allNews = jsonResponse['data'];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching news: $e");
      if (mounted && _allNews.isEmpty) setState(() => _isLoading = false);
    }
  }

  void _showNewsDetails(Map<String, dynamic> newsItem) {
    String imageUrl = Uri.encodeFull(newsItem['full_image_url']);
    String title = newsItem['title'] ?? "News";
    String date = newsItem['formatted_date'] ?? "";
    String rawDate = newsItem['news_date'] ?? ""; // Added raw date
    String content =
        newsItem['content'] ??
        newsItem['description'] ??
        newsItem['short_desc'] ??
        "No details available.";

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            NewsDetailScreen(
              title: title,
              imageUrl: imageUrl,
              date: date,
              rawDate: rawDate, // Pass raw date
              content: content,
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
                    : _allNews.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Center(child: Text("No news found")),
                          )
                        : SliverGrid.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 15,
                            crossAxisSpacing: 15,
                            childAspectRatio: 0.7, // Taller ratio for Poster Style
                            children: List.generate(_allNews.length, (index) {
                              return NewsRevealWrapper(
                                index: index,
                                child: _buildNewsGridItem(_allNews[index]),
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
                    "Latest News",
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

  // 🟢 UPDATED: "Poster Style" News Card (Matches Event Card)
  Widget _buildNewsGridItem(Map<String, dynamic> newsItem) {
    String imageUrl = Uri.encodeFull(newsItem['full_image_url']);
    String dateString = newsItem['formatted_date'] ?? "";

    // Logic to split date for the badge (e.g. "January 24" -> "JAN" "24")
    String month = "NEW";
    String day = "";
    try {
      List<String> parts = dateString.split(' ');
      if (parts.isNotEmpty) month = parts[0].substring(0, 3).toUpperCase();
      if (parts.length > 1) day = parts[1].replaceAll(',', '');
    } catch (e) {}

    return GestureDetector(
      onTap: () => _showNewsDetails(newsItem),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black, // Dark bg for loading
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full Image with Hero
              Hero(
                tag: imageUrl,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SkeletonContainer(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 0,
                      icon: Icons.newspaper,
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

              // 3. Date Badge (Top Left) - Matches Event Style
              if (day.isNotEmpty)
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
                      newsItem['title'],
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
                          "Read Article",
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

// 🟢 UPDATED: Immersive "News Showcase" Detail Screen
class NewsDetailScreen extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String date;
  final String rawDate;
  final String content;

  const NewsDetailScreen({
    Key? key,
    required this.title,
    required this.imageUrl,
    required this.date,
    required this.rawDate,
    required this.content,
  }) : super(key: key);

  @override
  _NewsDetailScreenState createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Setup Entrance Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // Start animation after page load
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🟢 Helper: Calculate Relative Time
  String _getTimeAgo() {
    try {
      // 1. Check for invalid or "Recently" fallbacks
      if (widget.rawDate.isEmpty || 
          widget.rawDate.contains("0000-00-00") || 
          widget.date.toLowerCase().contains("recently") ||
          widget.date.contains("-0001")) {
        return "posted recently";
      }

      DateTime postDate = DateTime.parse(widget.rawDate);
      DateTime now = DateTime.now();

      // 2. Sanity Check: If the date is absurdly old (e.g., year 0/1/-1 from DB error)
      if (postDate.year < 2010) { // News probably isn't from before 2010
        return "posted recently";
      }

      Duration diff = now.difference(postDate);

      // 3. Handle future dates (if server time is slightly ahead)
      if (diff.isNegative) {
        return "posted just now";
      }

      if (diff.inDays >= 365) {
        int years = (diff.inDays / 365).floor();
        return "posted $years ${years == 1 ? 'year' : 'years'} ago";
      } else if (diff.inDays >= 30) {
        int months = (diff.inDays / 30).floor();
        return "posted $months ${months == 1 ? 'month' : 'months'} ago";
      } else if (diff.inDays > 0) {
        return "posted ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago";
      } else if (diff.inHours > 0) {
        return "posted ${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago";
      } else if (diff.inMinutes > 0) {
        return "posted ${diff.inMinutes} ${diff.inMinutes == 1 ? 'min' : 'mins'} ago";
      } else {
        return "posted just now";
      }
    } catch (e) {
      return "posted recently";
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color amvGold = const Color(0xFFD4AF37);
    final Color amvViolet = const Color(0xFF2D0F35);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. Immersive Parallax Header
          SliverAppBar(
            expandedHeight: 400, // Very tall header for impact
            pinned: true,
            backgroundColor: amvViolet,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 🟢 Hero Image (Catches the flying image)
                  Hero(
                    tag: widget.imageUrl,
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey),
                    ),
                  ),
                  // Gradient for Text Visibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          amvViolet.withOpacity(0.2),
                          amvViolet.withOpacity(0.9),
                        ],
                        stops: const [0.4, 0.7, 1.0],
                      ),
                    ),
                  ),
                  // Title on Image
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category / Date Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: amvGold,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            (widget.date.contains("-0001") || widget.date.contains("0000")) 
                                ? "RECENTLY" 
                                : widget.date.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.title,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Animated Content Body
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  // Overlap effect
                  transform: Matrix4.translationValues(0, -20, 0),
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meta Row
                      Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            _getTimeAgo(),
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.newspaper_rounded,
                            color: Color(0xFFD4AF37),
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),

                      // Main Content
                      Html(
                        data: widget.content,
                        style: {
                          "body": Style(
                            fontFamily: GoogleFonts.montserrat().fontFamily,
                            fontSize: FontSize(16),
                            lineHeight: LineHeight(1.8),
                            color: Colors.grey[800],
                            margin: Margins.zero,
                          ),
                          "p": Style(margin: Margins.only(bottom: 20)),
                          "strong": Style(color: amvViolet),
                        },
                      ),

                      // Footer
                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          "●  ●  ●",
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🟢 SKELETON CONTAINER
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

class NewsRevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;
  const NewsRevealWrapper({required this.index, required this.child});

  @override
  _NewsRevealWrapperState createState() => _NewsRevealWrapperState();
}

class _NewsRevealWrapperState extends State<NewsRevealWrapper>
    with SingleTickerProviderStateMixin {
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
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    Future.delayed(Duration(milliseconds: widget.index * 50), () {
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
      child: SlideTransition(position: _offsetAnimation, child: widget.child),
    );
  }
}