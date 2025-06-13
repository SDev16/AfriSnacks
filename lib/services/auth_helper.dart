import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as model;
import 'package:meal/env/app_config.dart';
import 'package:meal/env/app_constants.dart';

class AuthHelper {
  late final Account account;
  late final Client client;

  AuthHelper() {
    client = Client()
      ..setEndpoint(AppConstants.endpoint)
      ..setProject(AppConfig.projectId)
      ..setSelfSigned(status: true);

    account = Account(client);
  }

  Future<String> loginWithNumber(String phoneNumber) async {
    try {
      // This will use the Twilio provider configured in Appwrite
      final token = await account.createPhoneToken(
        userId: ID.unique(),
        phone: phoneNumber,
      );
      return token.userId;
    } on AppwriteException catch (e) {
      print('Error during phone login: ${e.message}');
      rethrow;
    }
  }

  Future<model.Session> verifyOTP({
    required String userId,
    required String otp,
  }) async {
    try {
      final session = await account.updatePhoneSession(
        userId: userId,
        secret: otp,
      );
      return session;
    } catch (e) {
      print('Error verifying OTP: $e');
      rethrow;
    }
  }

  // Optional: Method to check if phone number is valid format
  bool isValidPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Check if it starts with + and has at least 10 digits
    return digitsOnly.startsWith('+') && digitsOnly.length >= 11;
  }
}
