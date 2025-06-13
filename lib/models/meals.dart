import 'package:meal/env/app_constants.dart';

class Meal {
  final String id;
  final String name;
  final String nameFr; // French name
  final double price;
  final String imageUrl;
  final String description;
  final String descriptionFr; // French description
  final String category;
  final double rating;
  final bool isFeatured;
  final String? fileId;
  final String? bucketId;

  Meal({
    required this.id,
    required this.name,
    this.nameFr = '', // Default empty if not provided
    required this.price,
    required this.imageUrl,
    required this.description,
    this.descriptionFr = '', // Default empty if not provided
    required this.category,
    this.rating = 0.0,
    this.isFeatured = false,
    this.fileId,
    this.bucketId,
  });

  // Get localized name based on current locale
  String getLocalizedName(String languageCode) {
    if (languageCode == 'fr' && nameFr.isNotEmpty) {
      return nameFr;
    }
    return name;
  }

  // Get localized description based on current locale
  String getLocalizedDescription(String languageCode) {
    if (languageCode == 'fr' && descriptionFr.isNotEmpty) {
      return descriptionFr;
    }
    return description;
  }

  factory Meal.fromJson(Map<String, dynamic> json) {
    // Handle price - convert from cents (integer) to dollars (double)
    double priceValue = 0.0;
    if (json.containsKey('price')) {
      if (json['price'] is int) {
        // Convert from cents to dollars
        priceValue = (json['price'] as int) / 100.0;
      } else if (json['price'] is double) {
        priceValue = json['price'];
      } else if (json['price'] is String) {
        try {
          priceValue = double.parse(json['price']);
        } catch (e) {
          print('Error parsing price: $e');
        }
      }
    }

    // Handle image URL
    String imageUrl = '';
    if (json.containsKey('imageUrl') && json['imageUrl'] != null && json['imageUrl'] is String) {
      // Use the provided imageUrl if available
      imageUrl = json['imageUrl'];
    } else if (json.containsKey('fileId') && json['fileId'] != null) {
      final fileId = json['fileId'];
      final bucketId = json['bucketId'] ?? 'your_bucket_id';
      
      // Construct URL from fileId and bucketId with the correct project ID
      imageUrl = 'https://fra.cloud.appwrite.io/v1/storage/buckets/$bucketId/files/$fileId/view?project=${AppConstants.projectId}';
    }

    return Meal(
      id: json['\$id'] ?? '',
      name: json['name'] ?? '',
      nameFr: json['name_fr'] ?? '', // Get French name if available
      price: priceValue,
      imageUrl: imageUrl,
      description: json['description'] ?? '',
      descriptionFr: json['description_fr'] ?? '', // Get French description if available
      category: json['category'] ?? '',
      rating: json['rating'] is int 
          ? (json['rating'] as int).toDouble() 
          : double.tryParse(json['rating'].toString()) ?? 0.0,
      isFeatured: json['isFeatured'] ?? false,
      fileId: json['fileId'],
      bucketId: json['bucketId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'name_fr': nameFr,
      'price': price,
      'imageUrl': imageUrl,
      'description': description,
      'description_fr': descriptionFr,
      'category': category,
      'rating': rating,
      'isFeatured': isFeatured,
      'fileId': fileId,
      'bucketId': bucketId,
    };
  }
}
