import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart' hide Locale;
import 'package:flutter/material.dart' as material show Locale;
import 'package:appwrite/appwrite.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:meal/firebase_options.dart';
import 'package:meal/l10n/app_localizations.dart';
import 'package:meal/provider/language_provider.dart';
import 'package:meal/provider/cart_provider.dart';
import 'package:meal/screens/splash_screen.dart';
import 'package:meal/services/notification_service.dart';
import 'package:meal/env/app_constants.dart';
import 'package:provider/provider.dart';

// Use Flutter's Locale explicitly
typedef FlutterLocale = material.Locale;

void main() async{
  
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  NotificationService().initializeNotifications();
  
  // Initialize Appwrite clients - using the constant for consistency
  Client client = Client()
      .setEndpoint(AppConstants.endpoint)
      .setProject(AppConstants.projectId)
      .setSelfSigned(status: true); // Enable this for development with self-signed certificates
  
  Account account = Account(client);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        // WishlistProvider will be created when user is authenticated
      ],
      child: MyApp(account: account, client: client),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Account account;
  final Client client;

  const MyApp({
    super.key, 
    required this.account,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          title: 'AfriSnacks',
          locale: languageProvider.currentLocale,
          supportedLocales: [
            FlutterLocale('en', ''),
            FlutterLocale('fr', ''),
          ],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.grey.shade50,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 1,
              centerTitle: true,
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          home: SplashScreen(account: account, client: client),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
