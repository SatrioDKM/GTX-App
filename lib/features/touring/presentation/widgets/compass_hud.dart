import 'dart:math' as math;
import 'package:flutter/material.dart';

class CompassHud extends StatelessWidget {
  final bool isMapReady;
  final ValueNotifier<double> compassNotifier;
  final VoidCallback onCompassTap;

  const CompassHud({
    super.key,
    required this.isMapReady,
    required this.compassNotifier,
    required this.onCompassTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hudColor = isDark 
        ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.8);

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onCompassTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: hudColor,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
          ),
          child: ValueListenableBuilder<double>(
            valueListenable: compassNotifier,
            builder: (context, rotation, child) {
              return Transform.rotate(
                angle: -(rotation * math.pi / 180),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.navigation, color: Colors.red, size: 28),
                    Positioned(
                      top: 4,
                      child: Text(
                        'N', 
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 8, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
