import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class PreloaderScreen extends StatefulWidget {
  final Widget? onComplete;
  
  const PreloaderScreen({Key? key, this.onComplete}) : super(key: key);

  @override
  State<PreloaderScreen> createState() => _PreloaderScreenState();
}

class _PreloaderScreenState extends State<PreloaderScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _particleController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  // 🟢 REMOVED unused _ringAnimation to fix warning

  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();

    // 1. Particle Animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // 2. Logo Animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOutSine),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _logoController.repeat(reverse: true);

    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    await Future.delayed(const Duration(milliseconds: 3000));

    if (!mounted) return;

    Widget nextScreen;

    if (widget.onComplete != null) {
      nextScreen = widget.onComplete!;
    } else {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      nextScreen = isLoggedIn ? HomeScreen() : const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => nextScreen,
        transitionDuration: const Duration(milliseconds: 1200),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. GRADIENT BACKGROUND
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  amvViolet,
                  const Color(0xFF1A051D),
                  Colors.black,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),

          // 2. PARTICLES
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

          // 3. CENTER CONTENT
          Center(
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo Container
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // A. Pulsing Ring (Fixed Opacity Math)
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                // 🟢 FIXED: Safe opacity value (0.2 to 0.4 based on scale)
                                color: amvGold.withOpacity(
                                  (0.2 * _scaleAnimation.value).clamp(0.0, 1.0)
                                ), 
                                width: 1.5
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: amvGold.withOpacity(0.1),
                                  blurRadius: 30 * _scaleAnimation.value,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          
                          // B. The Actual Logo
                          Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(25),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.03),
                                border: Border.all(color: amvGold.withOpacity(0.4), width: 1),
                              ),
                              child: Image.asset(
                                'assets/images/5.png',
                                height: 90,
                                width: 90,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 50),

                  // Title Text
                  Text(
                    "AMV HOTEL",
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 5,
                      shadows: [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Luxury & Comfort",
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: amvGold.withOpacity(0.8),
                      letterSpacing: 3.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. FOOTER
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Text(
                  "EST. 2024",
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.2),
                    letterSpacing: 2,
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

// Reused Atmosphere Painter
class AtmospherePainter extends CustomPainter {
  final double animationValue;
  final List<Particle> particles = List.generate(18, (index) => Particle());

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

class Particle {
  final double initialX = Random().nextDouble();
  final double initialY = Random().nextDouble() * 800;
  final double size = Random().nextDouble() * 2 + 1;
  final double speed = Random().nextDouble() * 0.2 + 0.05;
  final double opacity = Random().nextDouble() * 0.15 + 0.02;
}