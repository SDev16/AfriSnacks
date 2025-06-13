import 'package:double_back_to_close/double_back_to_close.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:meal/screens/login_page.dart';
import 'package:meal/addons/main_screen.dart';
import 'package:meal/env/app_config.dart';

class SplashScreen extends StatefulWidget {
  final Account account;
  final Client client;

  const SplashScreen({
    super.key,
    required this.account,
    required this.client,
  });

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animation
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();

    // Check for existing session after a short delay
    Future.delayed(Duration(milliseconds: 1000), () {
      _checkSession();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    try {
      // Try to get the current user directly
      // This will throw an exception if there's no active session
      final user = await widget.account.get();
      print('User is logged in: ${user.name}');

      // Try to fetch user profile data
      Map<String, dynamic>? profileData;
      try {
        final databases = Databases(widget.client);
        final response = await databases.listDocuments(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.databaseCollectionId,
          queries: [
            Query.equal('user_id', user.$id),
          ],
        );

        if (response.documents.isNotEmpty) {
          profileData = response.documents.first.data;
        }
      } catch (e) {
        print('Error fetching profile data: $e');
        // Continue without profile data
      }

      // Navigate to MainScreen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => DoubleBack(
              child: MainScreen(
                account: widget.account,
                user: user,
                profileData: profileData,
              ),
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      print('No active session: $e');
      // If no session or error, navigate to LoginPage
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => DoubleBack(child: LoginPage(account: widget.account)),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restaurant,
                  size: 70,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 24),

              // App Name
              Text(
                'AfriSnacks',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 8),

              // Tagline
              Text(
                'Delicious food at your fingertips ',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 48),

              // Loading Indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
