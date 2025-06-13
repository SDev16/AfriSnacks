import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:iconsax/iconsax.dart';
import 'package:meal/addons/curved_app_bar.dart';
import 'package:meal/l10n/app_localizations.dart';
import 'package:meal/models/category.dart';
import 'package:meal/models/meals.dart';
import 'package:meal/screens/pages/notifications_page.dart';
import 'package:meal/screens/pages/product_details_page.dart';
import 'package:meal/screens/receipt_management_page.dart';
import 'package:meal/env/app_config.dart';
import 'package:cached_network_image/cached_network_image.dart';


class HomePage extends StatefulWidget {
  final Account account;
  final models.User user;
  final Map<String, dynamic>? profileData;

  const HomePage({
    super.key,
    required this.account,
    required this.user,
    this.profileData,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool isLoadingCategories = false;
  bool isLoadingMeals = false;
  List<Category> categories = [];
  List<Meal> featuredMeals = [];
  String? errorMessage;
  int unreadNotificationCount = 0;
  int totalReceiptCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchCategories();
    _fetchFeaturedMeals();
    _fetchUnreadNotificationCount();
    _fetchReceiptCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchReceiptCount();
      _fetchUnreadNotificationCount();
    }
  }

  Future<void> _fetchUnreadNotificationCount() async {
    try {
      final databases = Databases(widget.account.client);

      print('Fetching unread notification count...');

      final userRegistrationDate = DateTime.parse(widget.user.$createdAt);

      final notificationsResponse = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.notificationId,
        queries: [
          Query.orderDesc('\$createdAt'),
          Query.greaterThanEqual('\$createdAt', userRegistrationDate.toIso8601String()),
        ],
      );

      print('Total notifications after registration: ${notificationsResponse.documents.length}');

      final readNotificationsResponse = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.readNotificationId,
        queries: [
          Query.equal('userId', widget.user.$id),
        ],
      );

      print('Read notifications: ${readNotificationsResponse.documents.length}');

      final deletedNotificationsResponse = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.deleteNotificationsId,
        queries: [
          Query.equal('userId', widget.user.$id),
        ],
      );

      print('Deleted notifications: ${deletedNotificationsResponse.documents.length}');

      final readNotificationIds = readNotificationsResponse.documents
          .map((doc) => doc.data['notificationId'] as String)
          .toSet();

      final deletedNotificationIds = deletedNotificationsResponse.documents
          .map((doc) => doc.data['notificationId'] as String)
          .toSet();

      int unreadCount = 0;
      for (var notification in notificationsResponse.documents) {
        final notificationId = notification.$id;
        if (!readNotificationIds.contains(notificationId) &&
            !deletedNotificationIds.contains(notificationId)) {
          unreadCount++;
        }
      }

      print('Unread count: $unreadCount');

      if (mounted) {
        setState(() {
          unreadNotificationCount = unreadCount;
        });
      }
    } catch (e) {
      print('Error fetching unread notification count: $e');
      if (mounted) {
        setState(() {
          unreadNotificationCount = 0;
        });
      }
    }
  }

  Future<void> _fetchReceiptCount() async {
    try {
      final databases = Databases(widget.account.client);

      print('Fetching receipt count...');

      final receiptsResponse = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.ordersId,
        queries: [
          Query.equal('userId', widget.user.$id),
          Query.orderDesc('\$createdAt'),
        ],
      );

      print('Total receipts: ${receiptsResponse.documents.length}');

      if (mounted) {
        setState(() {
          totalReceiptCount = receiptsResponse.documents.length;
        });
      }
    } catch (e) {
      print('Error fetching receipt count: $e');
      if (mounted) {
        setState(() {
          totalReceiptCount = 0;
        });
      }
    }
  }

  void refreshReceiptCount() {
    _fetchReceiptCount();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      isLoadingCategories = true;
    });

    try {
      final databases = Databases(widget.account.client);

      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.categoriesCollectionId,
        queries: [],
      );

      final List<Category> fetchedCategories = response.documents
          .map((doc) => Category.fromJson({...doc.data, '\$id': doc.$id}))
          .toList();

      if (mounted) {
        setState(() {
          categories = fetchedCategories;
          isLoadingCategories = false;
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
      if (mounted) {
        setState(() {
          errorMessage = AppLocalizations.of(context).errorFetchingCategories;
          isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _fetchFeaturedMeals() async {
    setState(() {
      isLoadingMeals = true;
    });

    try {
      final databases = Databases(widget.account.client);

      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.mealsCollectionId,
        queries: [
          Query.equal('isFeatured', true),
          Query.limit(4),
        ],
      );

      final List<Meal> fetchedMeals = response.documents
          .map((doc) => Meal.fromJson({...doc.data, '\$id': doc.$id}))
          .toList();

      if (mounted) {
        setState(() {
          featuredMeals = fetchedMeals;
          isLoadingMeals = false;
        });
      }
    } catch (e) {
      print('Error fetching meals: $e');
      if (mounted) {
        setState(() {
          errorMessage = AppLocalizations.of(context).errorFetchingMeals;
          isLoadingMeals = false;
        });
      }
    }
  }

  Widget _buildWelcomeContent() {
    final localizations = AppLocalizations.of(context);
    
    return Positioned(
      bottom: 40,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              '${localizations.welcomeBack}, ${widget.user.name}!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              localizations.discoverMeals,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.notifications_rounded,
                  label: localizations.notifications,
                  value: unreadNotificationCount.toString(),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.3),
                ),
                _buildStatItem(
                  icon: Icons.receipt_rounded,
                  label: localizations.receipts,
                  value: totalReceiptCount.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Curved App Bar
          CurvedAppBar(
            title: localizations.appTitle,
            subtitle: '${localizations.welcome} ${localizations.appTitle}',
            gradientColors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
              Colors.blue.shade800,
            ],
            expandedHeight: 250,
            flexibleContent: _buildWelcomeContent(),
            actions: [
              // Notifications icon with badge
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.notification,color: Colors.white,),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserNotificationsPage(
                            account: widget.account,
                            user: widget.user,
                            client: widget.account.client,
                          ),
                        ),
                      );
                      _fetchUnreadNotificationCount();
                    },
                    tooltip: localizations.notifications,
                  ),
                  if (unreadNotificationCount > 0)
                    Positioned(
                      right: 3.5,
                      top: 3,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        child: Text(
                          unreadNotificationCount > 10
                              ? '10+'
                              : unreadNotificationCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              // Receipts icon with badge
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.menu_board,color: Colors.white,),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReceiptsManagementPage(
                            account: widget.account,
                            user: widget.user,
                          ),
                        ),
                      );
                      _fetchReceiptCount();
                    },
                    tooltip: localizations.receipts,
                  ),
                  if (totalReceiptCount > 0)
                    Positioned(
                      right: 3.5,
                      top: 3,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        child: Text(
                          totalReceiptCount > 10
                              ? '10+'
                              : totalReceiptCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            showBackButton: false,
          ),

          // Content
          SliverToBoxAdapter(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _fetchCategories(),
                  _fetchFeaturedMeals(),
                  _fetchUnreadNotificationCount(),
                  _fetchReceiptCount(),
                ]);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.categories,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        isLoadingCategories
                            ? Center(child: CircularProgressIndicator())
                            : categories.isEmpty
                                ? Center(
                                    child: Text(
                                      errorMessage ?? localizations.noCategories,
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  )
                                : SizedBox(
                                    height: 100,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: categories.length,
                                      itemBuilder: (context, index) {
                                        final category = categories[index];
                                        return _buildCategoryItem(category);
                                      },
                                    ),
                                  ),
                      ],
                    ),
                  ),

                  // Featured meals
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.featuredMeals,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        isLoadingMeals
                            ? Center(child: CircularProgressIndicator())
                            : featuredMeals.isEmpty
                                ? Center(
                                    child: Text(
                                      errorMessage ?? localizations.noFeaturedMeals,
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 0.75,
                                    ),
                                    itemCount: featuredMeals.length,
                                    itemBuilder: (context, index) {
                                      final meal = featuredMeals[index];
                                      return _buildMealItem(meal);
                                    },
                                  ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Category category) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 80,
        margin: EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade100,
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: category.imageUrl,
                  fit: BoxFit.cover,
                  width: 60,
                  height: 60,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.blue.shade100,
                    child: Icon(
                      Icons.restaurant,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              category.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealItem(Meal meal) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsPage(
              account: widget.account,
              meal: meal,
            ),
          ),
        );
        _fetchReceiptCount();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: meal.imageUrl,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.grey.shade300,
                  child: Icon(
                    Icons.image,
                    size: 40,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${meal.price.toStringAsFixed(0)} Frs',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (meal.rating > 0) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        SizedBox(width: 4),
                        Text(
                          meal.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
