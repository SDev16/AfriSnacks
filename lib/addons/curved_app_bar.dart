import 'package:flutter/material.dart';

class CurvedAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final double expandedHeight;
  final bool pinned;
  final bool floating;
  final List<Color>? gradientColors;
  final Color? backgroundColor;
  final Widget? flexibleContent;
  final double elevation;
  final VoidCallback? onBackPressed;
  final bool showBackButton;
  final double bottomRadius;

  const CurvedAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.expandedHeight = 180.0,
    this.pinned = true,
    this.floating = false,
    this.gradientColors,
    this.backgroundColor,
    this.flexibleContent,
    this.elevation = 0,
    this.onBackPressed,
    this.showBackButton = false,
    this.bottomRadius = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    final defaultGradient = [
              Colors.blue.shade400,
              Colors.blue.shade600,
              Colors.blue.shade800,
    ];

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: floating,
      pinned: pinned,
      elevation: elevation,
      backgroundColor: backgroundColor ?? Colors.blue.shade400,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white
                ),
              ),
              if (subtitle != null)
                Text(
                  '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
        ),
        background: Stack(
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors ?? defaultGradient,
                ),
              ),
            ),
            
            // Decorative circles
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            
            // Custom content
            if (flexibleContent != null) flexibleContent!,
            
            // Curved bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: bottomRadius,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(bottomRadius),
                    topRight: Radius.circular(bottomRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}