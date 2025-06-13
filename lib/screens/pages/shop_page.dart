import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:iconsax/iconsax.dart';
import 'package:meal/l10n/app_localizations.dart';
import 'package:meal/models/category.dart';
import 'package:meal/models/meals.dart';
import 'package:meal/provider/cart_provider.dart';
import 'package:meal/provider/whishlist_provider.dart';
import 'package:meal/screens/pages/cart_page.dart';
import 'package:meal/screens/pages/product_details_page.dart';
import 'package:meal/env/app_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:meal/addons/curved_app_bar.dart';
import 'package:provider/provider.dart';

class ShopPage extends StatefulWidget {
  final Account account;
  final models.User? user;

  const ShopPage({
    super.key,
    required this.account,
    this.user,
  });

  @override
  _ShopPageState createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  bool isLoading = false;
  bool isLoadingCategories = false;
  List<Meal> meals = [];
  List<Category> categories = [];
  String? errorMessage;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchMeals();
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _fetchCategories(),
      _fetchMeals(),
    ]);
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
      );

      final fetchedCategories = response.documents
          .map((doc) => Category.fromJson({...doc.data, '\$id': doc.$id}))
          .toList();

      setState(() {
        categories = fetchedCategories;
        isLoadingCategories = false;
      });
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() {
        errorMessage = AppLocalizations.of(context).errorFetchingCategories;
        isLoadingCategories = false;
      });
    }
  }

  Future<void> _fetchMeals() async {
    setState(() {
      isLoading = true;
    });

    try {
      final databases = Databases(widget.account.client);

      List<String> queries = [];

      if (_selectedCategory != 'All') {
        queries.add(Query.equal('category', _selectedCategory));
      }

      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.mealsCollectionId,
        queries: queries,
      );

      final fetchedMeals = response.documents
          .map((doc) => Meal.fromJson({...doc.data, '\$id': doc.$id}))
          .toList();

      setState(() {
        meals = fetchedMeals;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching meals: $e');
      setState(() {
        errorMessage = AppLocalizations.of(context).errorFetchingMeals;
        isLoading = false;
      });
    }
  }

  Future<void> _toggleWishlist(Meal meal, WishlistProvider? wishlistProvider) async {
    if (wishlistProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to add items to your wishlist'),
          action: SnackBarAction(
            label: 'LOGIN',
            onPressed: () {},
          ),
        ),
      );
      return;
    }

    try {
      final isInWishlist = wishlistProvider.isMealInWishlist(meal.id);
      
      if (isInWishlist) {
        await wishlistProvider.removeFromWishlist(meal.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed from wishlist'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                await wishlistProvider.addToWishlist(meal);
              },
            ),
          ),
        );
      } else {
        await wishlistProvider.addToWishlist(meal);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to wishlist')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating wishlist: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addToCart(Meal meal, CartProvider cartProvider) async {
    try {
      cartProvider.addToCart(meal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${meal.name} added to cart'),
          action: SnackBarAction(
            label: 'VIEW CART',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartPage(
                    account: widget.account,
                    user: widget.user,
                  ),
                ),
              ).then((_) {
                // Refresh data when returning from cart
                _refreshData();
              });
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to cart: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildShopStats(CartProvider cartProvider) {
    final localizations = AppLocalizations.of(context);
    
    return Positioned(
      bottom: 40,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.restaurant_menu_rounded,
              label: localizations.products,
              value: meals.length.toString(),
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatItem(
              icon: Icons.shopping_cart_rounded,
              label: localizations.inCart,
              value: cartProvider.itemCount.toString(),
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
  List<String> categoryNames = ['All'];
  categoryNames.addAll(categories.map((category) => category.name).toList());

  // Create the main content widget
  Widget mainContent = Scaffold(
    backgroundColor: Colors.grey.shade50,
    body: RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        slivers: [
          // Curved App Bar - Use Consumer here to listen to cart changes
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              return CurvedAppBar(
                title: localizations.shop,
                subtitle: _selectedCategory == 'All' 
                    ? localizations.browseAllProducts
                    : '${localizations.categoryPrefix}$_selectedCategory',
                gradientColors: [
                  Colors.blue.shade400,
                  Colors.blue.shade600,
                  Colors.blue.shade800,
                ],
                expandedHeight: 200,
                flexibleContent: _buildShopStats(cartProvider),
                actions: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Iconsax.shopping_cart, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CartPage(
                                account: widget.account,
                                user: widget.user,
                              ),
                            ),
                          ).then((_) {
                            // Refresh data when returning from cart
                            _refreshData();
                          });
                        },
                      ),
                      if (cartProvider.itemCount > 0)
                        Positioned(
                          right: 4,
                          top: 8,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${cartProvider.itemCount}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                showBackButton: false,
              );
            },
          ),

          // Category filter
          SliverToBoxAdapter(
            child: Container(
              height: 60,
              padding: EdgeInsets.symmetric(vertical: 8),
              child: isLoadingCategories
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categoryNames.length,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final category = categoryNames[index];
                        final isSelected = category == _selectedCategory;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                            _fetchMeals();
                          },
                          child: Container(
                            margin: EdgeInsets.only(right: 12),
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Products grid - Use Consumer here too for cart-related operations
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: isLoading
                    ? SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()))
                    : errorMessage != null
                        ? SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    errorMessage!,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchMeals,
                                    child: Text(localizations.retry),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : meals.isEmpty
                            ? SliverFillRemaining(
                                child: Center(
                                  child: Text(localizations.noMealsFound),
                                ),
                              )
                            : SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.60,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final meal = meals[index];
                                    return _buildProductItem(meal, cartProvider);
                                  },
                                  childCount: meals.length,
                                ),
                              ),
              );
            },
          ),
        ],
      ),
    ),
  );

  // If user is logged in, provide the WishlistProvider
  if (widget.user != null) {
    return ChangeNotifierProvider(
      create: (_) => WishlistProvider(
        client: widget.account.client,
        userId: widget.user!.$id,
      ),
      child: mainContent,
    );
  }

  return mainContent;
}

  Widget _buildProductItem(Meal meal, CartProvider cartProvider) {
    final localizations = AppLocalizations.of(context);

    return Consumer<WishlistProvider?>(
      builder: (context, wishlistProvider, child) {
        final isInWishlist = wishlistProvider?.isMealInWishlist(meal.id) ?? false;
        final isLoadingWishlist = wishlistProvider?.isLoading ?? false;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailsPage(
                              account: widget.account,
                              meal: meal,
                              user: widget.user,
                            ),
                          ),
                        );
                      },
                      child: CachedNetworkImage(
                        imageUrl: meal.imageUrl,
                        height: 120,
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image,
                                size: 40,
                                color: Colors.grey.shade600,
                              ),
                              SizedBox(height: 4),
                              Text(
                                localizations.imageNotAvailable,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleWishlist(meal, wishlistProvider),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isLoadingWishlist
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              )
                            : Icon(
                                isInWishlist ? Icons.favorite : Icons.favorite_border,
                                color: isInWishlist
                                    ? Colors.red
                                    : Colors.grey.shade600,
                                size: 18,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        meal.category,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      if (meal.rating > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 2),
                            Text(
                              meal.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${meal.price.toStringAsFixed(0)} Frs',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _addToCart(meal, cartProvider),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade600,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.add_shopping_cart,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
