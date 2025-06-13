import 'package:meal/env/app_constants.dart';

class Category {
  final String id;
  final String name;
  final String imageUrl;
  final String? fileId;
  final String? bucketId;

  Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.fileId,
    this.bucketId,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    String imageUrl = '';
    
    // If we have a direct imageUrl, use it
    if (json.containsKey('imageUrl') && json['imageUrl'] != null && json['imageUrl'] is String) {
      imageUrl = json['imageUrl'];
    } 
    // If we have fileId and bucketId, construct the URL
    else if (json.containsKey('fileId') && json['fileId'] != null) {
      final fileId = json['fileId'];
      final bucketId = json['bucketId'] ?? 'your_bucket_id';
      
      // Construct URL from fileId and bucketId with the correct project ID
      imageUrl = 'https://fra.cloud.appwrite.io/v1/storage/buckets/$bucketId/files/$fileId/view?project=${AppConstants.projectId}';
    }
    
    return Category(
      id: json['\$id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: imageUrl,
      fileId: json['fileId'],
      bucketId: json['bucketId'],
    );
  }
}
