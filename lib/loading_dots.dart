import 'package:flutter/material.dart';

class LoadingDots extends StatefulWidget {
  final Color color;
  final double size;

  const LoadingDots({
    Key? key,
    this.color = const Color(0xFF2D0F35), // Your App's Violet Color
    this.size = 12.0,
  }) : super(key: key);

  @override
  _LoadingDotsState createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // One controller manages all three dots
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 3.5, // Total width based on dot size
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          // Stagger the animations using Intervals
          // Dot 1 starts at 0.0, Dot 2 at 0.2, Dot 3 at 0.4
          final begin = index * 0.2;
          final end = begin + 0.6; // Animation lasts 60% of total cycle

          return ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(
                parent: _controller,
                // Creates the "Wave" effect
                curve: Interval(begin, end < 1.0 ? end : 1.0, curve: Curves.easeInOut),
              ),
            ),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}