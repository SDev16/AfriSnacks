import 'package:flutter/material.dart';

class AppTheme {
  // App bar theme presets
  static List<Color> primaryGradient = [
    Colors.blue.shade400,
    Colors.blue.shade600,
    Colors.blue.shade800,
  ];
  
  static List<Color> successGradient = [
    Colors.green.shade400,
    Colors.green.shade600,
    Colors.green.shade800,
  ];
  
  static List<Color> warningGradient = [
    Colors.orange.shade400,
    Colors.orange.shade600,
    Colors.orange.shade800,
  ];
  
  static List<Color> dangerGradient = [
    Colors.red.shade400,
    Colors.red.shade600,
    Colors.red.shade800,
  ];
  
  static List<Color> infoGradient = [
    Colors.blue.shade400,
    Colors.blue.shade600,
    Colors.blue.shade800,
  ];
  
  // Get gradient based on app section
  static List<Color> getGradientForSection(String section) {
    switch (section.toLowerCase()) {
      case 'profile':
        return [
          Colors.teal.shade400,
          Colors.teal.shade600,
          Colors.teal.shade800,
        ];
      case 'notifications':
        return [
          Colors.indigo.shade400,
          Colors.indigo.shade600,
          Colors.indigo.shade800,
        ];
      case 'settings':
        return [
          Colors.blueGrey.shade400,
          Colors.blueGrey.shade600,
          Colors.blueGrey.shade800,
        ];
      case 'orders':
        return [
          Colors.amber.shade400,
          Colors.amber.shade600,
          Colors.amber.shade800,
        ];
      default:
        return primaryGradient;
    }
  }
}