import 'package:appwrite/models.dart' as model;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meal/screens/register_page.dart';
import 'package:meal/addons/main_screen.dart';
import 'package:meal/env/app_config.dart';
import 'package:country_picker/country_picker.dart';
import 'package:meal/env/app_constants.dart';
import 'package:pinput/pinput.dart';
import 'dart:math';

class AuthHelper {
  late final Account account;
  late final GoogleSignIn _googleSignIn;
  late final Databases databases;

  AuthHelper() {
    final client = Client()
      ..setEndpoint(AppConstants.endpoint)
      ..setProject(AppConfig.projectId)
      ..setSelfSigned(status: true);

    account = Account(client);
    databases = Databases(client);
    
    _googleSignIn = GoogleSignIn(
      scopes: [
        'email',
        'profile',
        'openid',
      ],
    );
  }

  Future<String> loginWithNumber(String phoneNumber) async {
    try {
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

  Future<model.User> signInWithGoogle() async {
    try {
      // Step 1: Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    
      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    
      if (googleAuth.accessToken == null) {
        throw Exception('Failed to get Google access token');
      }

      print('Google user signed in: ${googleUser.email}');

      // Step 2: Clear any existing sessions first
      try {
        final sessions = await account.listSessions();
        if (sessions.sessions.isNotEmpty) {
          await account.deleteSession(sessionId: 'current');
        }
      } catch (e) {
        print('No existing sessions to clear: $e');
      }

      // Step 3: Check if user already exists in database first
      bool userExistsInDB = false;
      String? existingUserId;
      String? storedPassword;
      
      try {
        final response = await databases.listDocuments(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.databaseCollectionId,
          queries: [Query.equal('email', googleUser.email)],
        );

        if (response.documents.isNotEmpty) {
          userExistsInDB = true;
          final userData = response.documents.first.data;
          existingUserId = userData['user_id'];
          storedPassword = userData['password'];
          print('User found in database: $existingUserId');
        }
      } catch (e) {
        print('Error checking database for existing user: $e');
      }

      model.User user;
      bool isNewUser = false;
      String userPassword = '';

      if (userExistsInDB && existingUserId != null && storedPassword != null) {
        // Step 4A: User exists - sign them in with stored password
        print('Signing in existing user...');
        try {
          await account.createEmailPasswordSession(
            email: googleUser.email,
            password: storedPassword,
          );
          
          user = await account.get();
          userPassword = storedPassword;
          print('Successfully signed in existing user: ${user.email}');
          
        } catch (e) {
          print('Failed to sign in existing user with stored password: $e');
          // If stored password doesn't work, generate new one and update
          userPassword = _generateSecurePassword();
          
          try {
            // Try to update the user's password
            await account.updatePassword(password: userPassword);
            
            // Create new session
            await account.createEmailPasswordSession(
              email: googleUser.email,
              password: userPassword,
            );
            
            user = await account.get();
            
            // Update stored password in database
            await _updateStoredPassword(existingUserId, userPassword);
            
          } catch (e2) {
            throw Exception('Failed to update existing user credentials: $e2');
          }
        }
        
      } else {
        // Step 4B: User doesn't exist - create new user
        print('Creating new user...');
        userPassword = _generateSecurePassword();
        
        try {
          user = await account.create(
            userId: ID.unique(),
            email: googleUser.email,
            password: userPassword,
            name: googleUser.displayName ?? googleUser.email.split('@')[0],
          );
          
          isNewUser = true;
          print('New user created successfully: ${user.email}');
          
          // Create session for new user
          await account.createEmailPasswordSession(
            email: googleUser.email,
            password: userPassword,
          );
          
        } on AppwriteException catch ( e) {
          if (e.code == 409) {
            // User exists in Appwrite but not in our database
            print('User exists in Appwrite but not in database, attempting sign-in...');
            
            // Try with a common password pattern or generate new one
            userPassword = _generateSecurePassword();
            
            try {
              // This might fail, but we'll handle it
              await account.createEmailPasswordSession(
                email: googleUser.email,
                password: userPassword,
              );
              
              user = await account.get();
              
            } catch (e2) {
              throw Exception(
                'Account exists but password unknown. Please use "Forgot Password" to reset your password, '
                'then try signing in with email/password.'
              );
            }
          } else {
            throw Exception('Failed to create user: ${e.message} (Code: ${e.code})');
          }
        }
      }

      // Step 5: Update user preferences
      try {
        await account.updatePrefs(prefs: {
          'google_id': googleUser.id,
          'google_photo': googleUser.photoUrl ?? '',
          'auth_provider': 'google',
          'last_google_signin': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('Failed to update user preferences: $e');
      }

      // Step 6: Create or update profile in database according to schema
      try {
        if (isNewUser || !userExistsInDB) {
          // Create new profile document with all required fields
          print('Creating new profile document...');
          await databases.createDocument(
            databaseId: AppConfig.databaseId,
            collectionId: AppConfig.databaseCollectionId,
            documentId: user.$id,
            data: {
              'user_id': user.$id,
              'name': googleUser.displayName ?? googleUser.email.split('@')[0],
              'email': googleUser.email,
              'phone': '', // Empty for Google users, can be updated later
              'created_at': DateTime.now().toIso8601String(),
              'profile_image': googleUser.photoUrl ?? '',
              'password': userPassword, // Store for future sign-ins
              'auth_provider': 'google',
            },
          );
          print('Profile document created successfully');
        } else {
          // Update existing profile document
          print('Updating existing profile document...');
          final response = await databases.listDocuments(
            databaseId: AppConfig.databaseId,
            collectionId: AppConfig.databaseCollectionId,
            queries: [Query.equal('user_id', user.$id)],
          );

          if (response.documents.isNotEmpty) {
            await databases.updateDocument(
              databaseId: AppConfig.databaseId,
              collectionId: AppConfig.databaseCollectionId,
              documentId: response.documents.first.$id,
              data: {
                'name': googleUser.displayName ?? googleUser.email.split('@')[0],
                'profile_image': googleUser.photoUrl ?? '',
                'last_google_signin': DateTime.now().toIso8601String(),
                'password': userPassword, // Update stored password
              },
            );
            print('Profile document updated successfully');
          } else {
            // Profile doesn't exist, create it
            await databases.createDocument(
              databaseId: AppConfig.databaseId,
              collectionId: AppConfig.databaseCollectionId,
              documentId: user.$id,
              data: {
                'user_id': user.$id,
                'name': googleUser.displayName ?? googleUser.email.split('@')[0],
                'email': googleUser.email,
                'phone': '',
                'created_at': DateTime.now().toIso8601String(),
                'profile_image': googleUser.photoUrl ?? '',
                'password': userPassword,
                'auth_provider': 'google',
                'last_google_signin': DateTime.now().toIso8601String(),
              },
            );
          }
        }
      } catch (e) {
        print('Failed to create/update profile document: $e');
        // Don't throw here as user is already authenticated
      }

      print('Google Sign-In completed successfully for user: ${user.email}');
      return user;
    } catch (e) {
      print('Error during Google Sign-In: $e');
      rethrow;
    }
  }

  // Helper method to update stored password in database
  Future<void> _updateStoredPassword(String userId, String newPassword) async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.databaseCollectionId,
        queries: [Query.equal('user_id', userId)],
      );

      if (response.documents.isNotEmpty) {
        await databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.databaseCollectionId,
          documentId: response.documents.first.$id,
          data: {
            'password': newPassword,
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      print('Failed to update stored password: $e');
    }
  }

  String _generateSecurePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random.secure();
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> signOutGoogle() async {
    try {
      // First check if user is signed in with Google
      final isGoogleSignedIn = await _googleSignIn.isSignedIn();
      if (isGoogleSignedIn) {
        await _googleSignIn.signOut();
        print('Google sign out successful');
      }
      
      // Then try to delete Appwrite session
      try {
        await account.get(); // Check if user is logged in
        await account.deleteSession(sessionId: 'current');
        print('Appwrite session deleted successfully');
      } catch (e) {
        // User might already be logged out from Appwrite
        print('Appwrite logout error (might already be logged out): $e');
        // Don't rethrow this error - we still want the UI to update
      }
    } catch (e) {
      print('Error during logout process: $e');
      // Don't throw the error - just log it
    }
  }

  // Check if user is actually logged in
  Future<bool> isLoggedIn() async {
    try {
      await account.get();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isSignedInWithGoogle() async {
    return await _googleSignIn.isSignedIn();
  }
}

class LoginPage extends StatefulWidget {
  final Account account;

  const LoginPage({super.key, required this.account});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AuthHelper _authHelper;
  
  // Email login controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  // Phone login controllers
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  
  // State variables
  bool isLoading = false;
  bool isGoogleLoading = false;
  String? errorMessage;
  bool _rememberMe = true;
  
  // Phone auth specific
  Country selectedCountry = Country(
    phoneCode: "233",
    countryCode: "GH",
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: "Ghana",
    example: "Ghana",
    displayName: "Ghana",
    displayNameNoCountryCode: "GH",
    e164Key: "",
  );
  
  String? tempUserId;
  bool showOTPField = false;
  int resendTimer = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _authHelper = AuthHelper();
  }

  @override
  void dispose() {
    _tabController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  Future<void> signInWithGoogle() async {
    setState(() {
      isGoogleLoading = true;
      errorMessage = null;
    });

    try {
      final user = await _authHelper.signInWithGoogle();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      
      if (fcmToken != null) {
        try {
          await widget.account.createPushTarget(
            targetId: ID.unique(),
            identifier: fcmToken,
            providerId: AppConfig.fcmId,
          );
        } catch (e) {
          print('Failed to create push target: $e');
        }
      }

      // Fetch profile data
      Map<String, dynamic>? profileData;
      try {
        final databases = Databases(widget.account.client);
        final response = await databases.listDocuments(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.databaseCollectionId,
          queries: [Query.equal('user_id', user.$id)],
        );

        if (response.documents.isNotEmpty) {
          profileData = response.documents.first.data;
        }
      } catch (e) {
        print('Error fetching profile data: $e');
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainScreen(
              account: widget.account,
              user: user,
              profileData: profileData,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Google Sign-In failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter both email and password';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await widget.account.createEmailPasswordSession(
        email: email,
        password: password,
      );

      final user = await widget.account.get();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      
      if (fcmToken != null) {
        try {
          await widget.account.createPushTarget(
            targetId: ID.unique(),
            identifier: fcmToken,
            providerId: AppConfig.fcmId,
          );
        } catch (e) {
          print('Failed to create push target: $e');
        }
      }

      Map<String, dynamic>? profileData;
      try {
        final databases = Databases(widget.account.client);
        final response = await databases.listDocuments(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.databaseCollectionId,
          queries: [Query.equal('user_id', user.$id)],
        );

        if (response.documents.isNotEmpty) {
          profileData = response.documents.first.data;
        }
      } catch (e) {
        print('Error fetching profile data: $e');
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainScreen(
              account: widget.account,
              user: user,
              profileData: profileData,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Login failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> loginWithPhone() async {
    if (phoneController.text.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your phone number';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final fullPhoneNumber = '+${selectedCountry.phoneCode}${phoneController.text}';
      final userId = await _authHelper.loginWithNumber(fullPhoneNumber);
      
      setState(() {
        tempUserId = userId;
        showOTPField = true;
        isLoading = false;
      });
      
      _startResendTimer();
      
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to send OTP: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> verifyOTP() async {
    if (otpController.text.isEmpty || tempUserId == null) {
      setState(() {
        errorMessage = 'Please enter the OTP code';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final session = await _authHelper.verifyOTP(
        userId: tempUserId!,
        otp: otpController.text,
      );

      final user = await widget.account.get();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      
      if (fcmToken != null) {
        try {
          await widget.account.createPushTarget(
            targetId: ID.unique(),
            identifier: fcmToken,
            providerId: AppConfig.fcmId,
          );
        } catch (e) {
          print('Failed to create push target: $e');
        }
      }

      Map<String, dynamic>? profileData;
      try {
        final databases = Databases(widget.account.client);
        final response = await databases.listDocuments(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.databaseCollectionId,
          queries: [Query.equal('user_id', user.$id)],
        );

        if (response.documents.isNotEmpty) {
          profileData = response.documents.first.data;
        }
      } catch (e) {
        print('Error fetching profile data: $e');
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainScreen(
              account: widget.account,
              user: user,
              profileData: profileData,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Invalid OTP code: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> resendOTP() async {
    if (resendTimer > 0) return;
    
    setState(() {
      showOTPField = false;
      tempUserId = null;
      otpController.clear();
      errorMessage = null;
    });
    
    await loginWithPhone();
  }

  void _startResendTimer() {
    setState(() {
      resendTimer = 60;
    });
    
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          resendTimer--;
        });
      }
      return resendTimer > 0 && mounted;
    });
  }

  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController emailResetController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock_reset, color: Colors.blue),
              SizedBox(width: 8),
              Text('Reset Password'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter your email address to receive a password reset link.'),
                SizedBox(height: 16),
                TextField(
                  controller: emailResetController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Send Reset Link'),
              onPressed: () async {
                if (emailResetController.text.isNotEmpty) {
                  try {
                    await widget.account.createRecovery(
                      email: emailResetController.text,
                      url: 'https://yourapp.com/reset-password', // Update with your reset URL
                    );
                    
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('Password reset email sent to ${emailResetController.text}'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send reset email: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Sign In'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Email Login', icon: Icon(Icons.email)),
            Tab(text: 'Phone Login', icon: Icon(Icons.phone)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEmailLoginTab(),
          _buildPhoneLoginTab(),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: ElevatedButton.icon(
        onPressed: isGoogleLoading ? null : signInWithGoogle,
        icon: isGoogleLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Container(
                height: 20,
                width: 20,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(
                      'https://developers.google.com/identity/images/g-logo.png',
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
        label: Text(
          isGoogleLoading ? 'Signing in...' : 'Continue with Google',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Colors.grey),
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade400)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade400)),
      ],
    );
  }

  Widget _buildErrorMessage() {
    if (errorMessage == null) return SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 20),
          
          // Welcome Text
          Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Sign in to your account',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 40),
          
          // Error Message
          _buildErrorMessage(),
          
          // Google Sign-In Button
          _buildGoogleSignInButton(),
          
          // Divider
          _buildDivider(),
          SizedBox(height: 24),
          
          // Email Field
          TextField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email, color: Colors.blue.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: 16),
          
          // Password Field
          TextField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock, color: Colors.blue.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => loginWithEmail(emailController.text, passwordController.text),
          ),
          SizedBox(height: 16),
          
          // Remember Me & Forgot Password
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? true;
                  });
                },
                activeColor: Colors.blue.shade600,
              ),
              Text('Remember me'),
              Spacer(),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.blue.shade600),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          
          // Login Button
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () => loginWithEmail(emailController.text, passwordController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Sign In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
          SizedBox(height: 24),
          
          // Register Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RegisterPage(account: widget.account),
                    ),
                  );
                },
                child: Text(
                  'Sign Up',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 20),
          
          // Welcome Text
          Text(
            'Phone Login',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Enter your phone number to receive OTP',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 40),
          
          // Error Message
          _buildErrorMessage(),
          
          // Google Sign-In Button
          _buildGoogleSignInButton(),
          
          // Divider
          _buildDivider(),
          SizedBox(height: 24),
          
          if (!showOTPField) ...[
            // Country and Phone Input
            Row(
              children: [
                InkWell(
                  onTap: () {
                    showCountryPicker(
                      context: context,
                      onSelect: (Country country) {
                        setState(() {
                          selectedCountry = country;
                        });
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedCountry.flagEmoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+${selectedCountry.phoneCode}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone, color: Colors.blue.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => loginWithPhone(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // Send OTP Button
            ElevatedButton(
              onPressed: isLoading ? null : loginWithPhone,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Send OTP',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
          
          if (showOTPField) ...[
            // OTP Instructions
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enter the 6-digit code sent to +${selectedCountry.phoneCode}${phoneController.text}',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            
            // OTP Input
            Pinput(
              controller: otpController,
              length: 6,
              onCompleted: (pin) => verifyOTP(),
              defaultPinTheme: PinTheme(
                width: 56,
                height: 56,
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
              ),
              focusedPinTheme: PinTheme(
                width: 56,
                height: 56,
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade600, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 24),
            
            // Verify OTP Button
            ElevatedButton(
              onPressed: isLoading ? null : verifyOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Verify OTP',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
            SizedBox(height: 16),
            
            // Resend OTP
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive the code? ",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                TextButton(
                  onPressed: resendTimer > 0 ? null : resendOTP,
                  child: Text(
                    resendTimer > 0 
                        ? 'Resend in ${resendTimer}s' 
                        : 'Resend OTP',
                    style: TextStyle(
                      color: resendTimer > 0 ? Colors.grey : Colors.blue.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            // Back to Phone Number
            TextButton(
              onPressed: () {
                setState(() {
                  showOTPField = false;
                  tempUserId = null;
                  otpController.clear();
                  errorMessage = null;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 16, color: Colors.blue.shade600),
                  SizedBox(width: 4),
                  Text(
                    'Back to Phone Number',
                    style: TextStyle(color: Colors.blue.shade600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
