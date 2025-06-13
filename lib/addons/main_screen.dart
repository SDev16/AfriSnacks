import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:meal/l10n/app_localizations.dart';
import 'package:meal/screens/pages/home_page.dart';
import 'package:meal/screens/pages/profile_page.dart';
import 'package:meal/screens/pages/shop_page.dart';
import 'package:meal/screens/pages/wishlist_page.dart';
import 'package:iconsax/iconsax.dart';


class MainScreen extends StatefulWidget {
  final Account account;
  final models.User user;
  final Map<String, dynamic>? profileData;

  const MainScreen({
    super.key,
    required this.account,
    required this.user,
    this.profileData,
  });

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(
        account: widget.account,
        user: widget.user,
      ),
      ShopPage(
        account: widget.account,
        user: widget.user,
      ),
      WishlistPage(
        account: widget.account,
        user: widget.user,
      ),
      ProfilePage(
        account: widget.account,
        user: widget.user,
        profileData: widget.profileData,
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.blue[400],
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.black54,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.home),
              activeIcon: const Icon(Iconsax.home_2),
              label: localizations.getHome,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.shopping_bag),
              activeIcon: const Icon(Icons.shop_2),
              label: localizations.getShop,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.like),
              activeIcon: const Icon(Iconsax.like_shapes),
              label: localizations.getWhishlist, // Use localized string for "Wishlist"
            ),
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.more_square),
              activeIcon: const Icon(Iconsax.more_2),
              label: localizations.getMore, // Use localized string for "More"
            ),
          ],
        ),
      ),
    );
  }
}
