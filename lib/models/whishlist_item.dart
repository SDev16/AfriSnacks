import 'package:meal/models/meals.dart';

class WishlistItem {
  final String id;
  final String userId;
  final String mealId;
  final DateTime dateAdded;
  Meal? meal; // Optional meal data for UI display

  WishlistItem({
    required this.id,
    required this.userId,
    required this.mealId,
    required this.dateAdded,
    this.meal,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json, {Meal? mealData}) {
    return WishlistItem(
      id: json['\$id'] ?? '',
      userId: json['userId'] ?? '',
      mealId: json['mealId'] ?? '',
      dateAdded: json['dateAdded'] != null 
          ? DateTime.parse(json['dateAdded']) 
          : DateTime.now(),
      meal: mealData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'mealId': mealId,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }
}
