import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'home_screen.dart';
import 'add_email_screen.dart';
import 'user_sync_service.dart';
import 'api_config.dart';
import 'preloader_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  
  // Animation Controllers
  late AnimationController _entranceController;
  late AnimationController _particleController;
  late AnimationController _shimmerController;
  late AnimationController _floatController;

  // Staggered Animations
  late Animation<double> _fadeLogo;
  late Animation<Offset> _slideLogo;
  late Animation<double> _fadeText;
  late Animation<Offset> _slideText;
  late Animation<double> _fadeButtons;
  late Animation<Offset> _slideButtons;
  
  late Animation<double> _blurAnimation;

  // Background Carousel
  int _currentHeroIndex = 0;
  Timer? _heroTimer;
  final List<String> _heroImages = [
    "assets/images/hotel_background.png",
    "assets/images/hotel_foods.jpg",
    "assets/images/hotel_events.png",
    "assets/images/test_1.png",
  ];

  final Color amvGold = const Color(0xFFD4AF37);

  bool _isGoogleLoading = false;
  bool get _isLoading => _isGoogleLoading;

  @override
  void initState() {
    super.initState();
    _startHeroCarousel();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeLogo = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _slideLogo = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.4, curve: Curves.easeOutQuart)),
    );

    _fadeText = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );
    _slideText = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.3, 0.7, curve: Curves.easeOutQuart)),
    );

    _fadeButtons = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );
    _slideButtons = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.6, 1.0, curve: Curves.easeOutQuart)),
    );

    _blurAnimation = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.8, curve: Curves.easeOut)),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      _entranceController.forward();
    });
  }

  void _startHeroCarousel() {
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        setState(() {
          _currentHeroIndex = (_currentHeroIndex + 1) % _heroImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _entranceController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _saveSessionAndGoHome(User user) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('user_id', user.uid);
    if (!mounted) return;

    // 🟢 UPDATED: Custom Slide-Up Transition to Preloader
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            PreloaderScreen(onComplete: HomeScreen()),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); // Start from bottom
          const end = Offset.zero;        // End at center
          const curve = Curves.fastOutSlowIn; // Premium curve

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 1000), // Smooth 1s slide
      ),
    );
  }

  Future<void> _checkMySQLAndNavigate(User user) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/check_user_email.php");
      final response = await http.post(url, body: {'uid': user.uid});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['has_email'] == true) {
          UserSyncService.syncUserToMySQL(user);
          await _saveSessionAndGoHome(user);
          return;
        }
      }
    } catch (e) {
      print("MySQL Check Failed: $e");
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const AddEmailScreen()));
  }

  void _handleNavigation(User user) async {
    if (!mounted) return;
    if (user.email != null && user.email!.isNotEmpty) {
      UserSyncService.syncUserToMySQL(user);
      await _saveSessionAndGoHome(user);
    } else {
      await _checkMySQLAndNavigate(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. BACKGROUND WITH CINEMATIC BLUR
          AnimatedBuilder(
            animation: _blurAnimation,
            builder: (context, child) {
              return ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: _blurAnimation.value, 
                  sigmaY: _blurAnimation.value
                ),
                child: child,
              );
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1500),
              child: ZoomingHeroImage(
                key: ValueKey<String>(_heroImages[_currentHeroIndex]),
                imagePath: _heroImages[_currentHeroIndex],
              ),
            ),
          ),

          // 2. DARKER GRADIENT OVERLAY
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.8),
                  Colors.black.withOpacity(1.0),
                ],
                stops: const [0.2, 0.7, 1.0],
              ),
            ),
          ),
          
          // 3. AMBIENT PARTICLES
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: AtmospherePainter(_particleController.value),
                );
              },
            ),
          ),

          // 4. CONTENT
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- LOGO ---
                  FadeTransition(
                    opacity: _fadeLogo,
                    child: SlideTransition(
                      position: _slideLogo,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: amvGold.withOpacity(0.5), width: 1),
                          boxShadow: [
                            BoxShadow(color: amvGold.withOpacity(0.2), blurRadius: 30, spreadRadius: 5),
                          ],
                        ),
                        child: Image.asset('assets/images/5.png', height: 90),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- TEXT WITH SHIMMER ---
                  FadeTransition(
                    opacity: _fadeText,
                    child: SlideTransition(
                      position: _slideText,
                      child: Column(
                        children: [
                          Text(
                            "WELCOME TO",
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              letterSpacing: 4,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          
                          AnimatedBuilder(
                            animation: _shimmerController,
                            builder: (context, child) {
                              return ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    colors: [Colors.white, amvGold, Colors.white],
                                    stops: [0.0, _shimmerController.value, 1.0],
                                    begin: const Alignment(-1.0, -0.3),
                                    end: const Alignment(1.0, 0.3),
                                    tileMode: TileMode.clamp,
                                  ).createShader(bounds);
                                },
                                child: Text(
                                  "AMV HOTEL",
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 40,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                    shadows: [
                                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "Experience luxury and comfort\nlike never before.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                              height: 1.6,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // --- BUTTONS (Floating Effect) ---
                  FadeTransition(
                    opacity: _fadeButtons,
                    child: SlideTransition(
                      position: _slideButtons,
                      child: AnimatedBuilder(
                        animation: _floatController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 5 * sin(_floatController.value * 2 * pi)),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            // GOOGLE BUTTON
                            _socialBtn(
                              text: "Continue with Google",
                              assetPath: 'assets/images/google_logo.svg',
                              isLoading: _isGoogleLoading,
                              isDisabled: _isLoading,
                              onPressed: () async {
                                setState(() => _isGoogleLoading = true);
                                await Future.delayed(const Duration(seconds: 2));
                                final user = await _authService.signInWithGoogle();
                                if (user != null) {
                                  await UserSyncService.syncUserToMySQL(user, provider: 'google');
                                  _handleNavigation(user);
                                } else {
                                  if (mounted) {
                                    setState(() => _isGoogleLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Google login failed.")));
                                  }
                                }
                              },
                            ),
                            
                            const SizedBox(height: 40),
                            
                            Text(
                              "By continuing, you agree to our Terms & Privacy Policy.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _socialBtn({
    required String text,
    required String assetPath,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isDisabled = false,
  }) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: isDisabled ? null : onPressed,
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Center(
            child: isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(assetPath, height: 16, width: 16),
                      ),
                      const SizedBox(width: 15),
                      Text(
                        text,
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// Atmosphere Particle Painter
class AtmospherePainter extends CustomPainter {
  final double animationValue;
  final List<Particle> particles = List.generate(15, (index) => Particle());

  AtmospherePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      double y = (particle.initialY - (animationValue * size.height * particle.speed)) % (size.height + 100);
      if (y < -50) y += size.height + 100;
      paint.color = Colors.white.withOpacity(particle.opacity);
      canvas.drawCircle(Offset(particle.initialX * size.width, y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Helper class for random particles
class Particle {
  final double initialX = Random().nextDouble();
  final double initialY = Random().nextDouble() * 800;
  final double size = Random().nextDouble() * 3 + 1;
  final double speed = Random().nextDouble() * 0.5 + 0.2;
  final double opacity = Random().nextDouble() * 0.15 + 0.05;
}

// Zooming Hero Image
class ZoomingHeroImage extends StatefulWidget {
  final String imagePath;
  const ZoomingHeroImage({Key? key, required this.imagePath}) : super(key: key);

  @override
  _ZoomingHeroImageState createState() => _ZoomingHeroImageState();
}

class _ZoomingHeroImageState extends State<ZoomingHeroImage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Image.asset(widget.imagePath, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
    );
  }
}