
import 'package:meal/env/app_config.dart';
import 'package:meal/env/app_constants.dart';

class ImageService {
  // Construct image URL from file ID and bucket ID
  static String getImageUrl(String fileId, {String? bucketId}) {
    final actualBucketId = bucketId ?? AppConfig.bucketId;
    return 'https://fra.cloud.appwrite.io/v1/storage/buckets/$actualBucketId/files/$fileId/view?project=${AppConstants.projectId}';
  }
  
  // Extract file ID from image URL
  static String? extractFileId(String imageUrl) {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      // The file ID is typically the second-to-last segment in the path
      if (pathSegments.length >= 2) {
        return pathSegments[pathSegments.length - 2];
      }
    } catch (e) {
      print('Error extracting file ID: $e');
    }
    return null;
  }
}
