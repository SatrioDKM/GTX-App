import 'package:flutter/material.dart';

class NavigationMarker extends StatelessWidget {
  final ValueNotifier<double> headingNotifier;

  const NavigationMarker({
    super.key,
    required this.headingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blueAccent.withValues(alpha: 0.15),
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: headingNotifier,
          builder: (context, headingValue, child) {
            return AnimatedRotation(
              turns: headingValue / 360.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: 70,
                height: 70,
                child: const Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Icon(
                      Icons.navigation,
                      color: Colors.blueAccent,
                      size: 32,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 6)],
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
