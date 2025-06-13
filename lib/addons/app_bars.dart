import 'package:flutter/material.dart';
import 'curved_app_bar.dart';

class AppBars {
  /// Creates a standard curved app bar for use in CustomScrollView
  static CurvedAppBar curved({
    required String title,
    String? subtitle,
    List<Widget>? actions,
    Widget? leading,
    double expandedHeight = 180.0,
    bool pinned = true,
    List<Color>? gradientColors,
    Widget? flexibleContent,
    VoidCallback? onBackPressed,
    bool showBackButton = false,
  }) {
    return CurvedAppBar(
      title: title,
      subtitle: subtitle,
      actions: actions,
      leading: leading,
      expandedHeight: expandedHeight,
      pinned: pinned,
      gradientColors: gradientColors,
      flexibleContent: flexibleContent,
      onBackPressed: onBackPressed,
      showBackButton: showBackButton,
    );
  }

  /// Creates a scaffold with curved app bar for quick page setup
  static Scaffold scaffoldWithCurvedAppBar({
    required String title,
    required Widget body,
    String? subtitle,
    List<Widget>? actions,
    Widget? leading,
    double expandedHeight = 180.0,
    bool pinned = true,
    List<Color>? gradientColors,
    Widget? flexibleContent,
    VoidCallback? onBackPressed,
    bool showBackButton = false,
    Widget? floatingActionButton,
    FloatingActionButtonLocation? floatingActionButtonLocation,
    Widget? bottomNavigationBar,
  }) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CurvedAppBar(
            title: title,
            subtitle: subtitle,
            actions: actions,
            leading: leading,
            expandedHeight: expandedHeight,
            pinned: pinned,
            gradientColors: gradientColors,
            flexibleContent: flexibleContent,
            onBackPressed: onBackPressed,
            showBackButton: showBackButton,
          ),
          SliverToBoxAdapter(
            child: body,
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}