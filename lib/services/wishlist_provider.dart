import 'package:appwrite/appwrite.dart';
import 'package:meal/models/meals.dart';
import 'package:meal/models/whishlist_item.dart';
import 'package:meal/env/app_config.dart';

class WishlistService {
  final Databases _databases;
  final String _userId;
  
  // Collection ID for wishlist items

  
  WishlistService(Client client, this._userId) 
      : _databases = Databases(client);
  
  // Add a meal to wishlist
  Future<WishlistItem> addToWishlist(Meal meal) async {
    try {
      // Check if the meal is already in the wishlist
      final existingItems = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.wishlistCollectionId,
        queries: [
          Query.equal('userId', _userId),
          Query.equal('mealId', meal.id),
        ],
      );
      
      // If the meal is already in the wishlist, return the existing item
      if (existingItems.documents.isNotEmpty) {
        return WishlistItem.fromJson(
          existingItems.documents.first.data,
          mealData: meal,
        );
      }
      
      // Create a new wishlist item
      final wishlistItem = WishlistItem(
        id: '', // Will be set by Appwrite
        userId: _userId,
        mealId: meal.id,
        dateAdded: DateTime.now(),
        meal: meal,
      );
      
      // Save to database
      final result = await _databases.createDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.wishlistCollectionId,
        documentId: ID.unique(),
        data: wishlistItem.toJson(),
      );
      
      // Return the created item
      return WishlistItem.fromJson(result.data, mealData: meal);
    } catch (e) {
      print('Error adding to wishlist: $e');
      rethrow;
    }
  }
  
  // Remove a meal from wishlist
  Future<void> removeFromWishlist(String mealId) async {
    try {
      // Find the wishlist item
      final items = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.wishlistCollectionId,
        queries: [
          Query.equal('userId', _userId),
          Query.equal('mealId', mealId),
        ],
      );
      
      // If found, delete it
      if (items.documents.isNotEmpty) {
        await _databases.deleteDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.wishlistCollectionId,
          documentId: items.documents.first.$id,
        );
      }
    } catch (e) {
      print('Error removing from wishlist: $e');
      rethrow;
    }
  }
  
  // Check if a meal is in the wishlist
  Future<bool> isInWishlist(String mealId) async {
    try {
      final items = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.wishlistCollectionId,
        queries: [
          Query.equal('userId', _userId),
          Query.equal('mealId', mealId),
        ],
      );
      
      return items.documents.isNotEmpty;
    } catch (e) {
      print('Error checking wishlist: $e');
      return false;
    }
  }
  
  // Get all wishlist items for the user
  Future<List<WishlistItem>> getWishlistItems() async {
    try {
      final result = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.wishlistCollectionId,
        queries: [
          Query.equal('userId', _userId),
          Query.orderDesc('dateAdded'),
        ],
      );
      
      // Convert to WishlistItem objects
      return result.documents.map((doc) => 
        WishlistItem.fromJson(doc.data)
      ).toList();
    } catch (e) {
      print('Error getting wishlist items: $e');
      return [];
    }
  }
  
  // Get wishlist items with meal data
  Future<List<WishlistItem>> getWishlistItemsWithMeals() async {
    try {
      // Get wishlist items
      final wishlistItems = await getWishlistItems();
      
      if (wishlistItems.isEmpty) {
        return [];
      }
      
      // Get meal IDs
      final mealIds = wishlistItems.map((item) => item.mealId).toList();
      
      // Fetch meals data
      List<WishlistItem> itemsWithMeals = [];
      
      for (var item in wishlistItems) {
        try {
          final mealDoc = await _databases.getDocument(
            databaseId: AppConfig.databaseId,
            collectionId: AppConfig.mealsCollectionId,
            documentId: item.mealId,
          );
          
          // Create meal object
          final meal = Meal.fromJson({...mealDoc.data, '\$id': mealDoc.$id});
          
          // Add meal data to wishlist item
          itemsWithMeals.add(WishlistItem(
            id: item.id,
            userId: item.userId,
            mealId: item.mealId,
            dateAdded: item.dateAdded,
            meal: meal,
          ));
        } catch (e) {
          print('Error fetching meal ${item.mealId}: $e');
          // Add the item without meal data
          itemsWithMeals.add(item);
        }
      }
      
      return itemsWithMeals;
    } catch (e) {
      print('Error getting wishlist items with meals: $e');
      return [];
    }
  }
  
  // Clear the entire wishlist
  Future<void> clearWishlist() async {
    try {
      final items = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.wishlistCollectionId,
        queries: [
          Query.equal('userId', _userId),
        ],
      );
      
      // Delete each item
      for (var doc in items.documents) {
        await _databases.deleteDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.wishlistCollectionId,
          documentId: doc.$id,
        );
      }
    } catch (e) {
      print('Error clearing wishlist: $e');
      rethrow;
    }
  }
}
