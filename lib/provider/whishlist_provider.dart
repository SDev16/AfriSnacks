import 'package:flutter/foundation.dart';
import 'package:appwrite/appwrite.dart';
import 'package:meal/models/meals.dart';
import 'package:meal/models/whishlist_item.dart';
import 'package:meal/services/wishlist_provider.dart';

class WishlistProvider with ChangeNotifier {
  final Client client;
  final String userId;
  
  WishlistService? _wishlistService;
  List<WishlistItem> _wishlistItems = [];
  bool _isLoading = false;
  String? _error;
  
  WishlistProvider({required this.client, required this.userId}) {
    _wishlistService = WishlistService(client, userId);
    fetchWishlistItems();
  }
  
  // Getters
  List<WishlistItem> get wishlistItems => _wishlistItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemCount => _wishlistItems.length;
  
  double get totalValue {
    return _wishlistItems
        .where((item) => item.meal != null)
        .fold(0.0, (sum, item) => sum + item.meal!.price);
  }
  
  // Check if a meal is in wishlist
  bool isMealInWishlist(String mealId) {
    return _wishlistItems.any((item) => item.mealId == mealId);
  }
  
  // Fetch all wishlist items
  Future<void> fetchWishlistItems() async {
    if (_wishlistService == null) return;
    
    _setLoading(true);
    
    try {
      final items = await _wishlistService!.getWishlistItemsWithMeals();
      _wishlistItems = items;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load wishlist items: ${e.toString()}';
      print('Error fetching wishlist items: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Add item to wishlist
  Future<void> addToWishlist(Meal meal) async {
    if (_wishlistService == null) return;
    
    try {
      await _wishlistService!.addToWishlist(meal);
      await fetchWishlistItems(); // Refresh the list
    } catch (e) {
      _error = 'Failed to add item to wishlist: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Remove item from wishlist
  Future<WishlistItem> removeFromWishlist(String mealId) async {
    if (_wishlistService == null) {
      throw Exception('WishlistService is not initialized');
    }
    
    try {
      // Store the item before removing for potential undo
      final removedItem = _wishlistItems.firstWhere((item) => item.mealId == mealId);
      
      // Remove from local state immediately for UI responsiveness
      _wishlistItems.removeWhere((item) => item.mealId == mealId);
      notifyListeners();
      
      // Then remove from backend
      await _wishlistService!.removeFromWishlist(mealId);
      
      // Return the removed item for potential undo operations
      return removedItem;
    } catch (e) {
      _error = 'Failed to remove item from wishlist: ${e.toString()}';
      await fetchWishlistItems(); // Refresh to ensure UI is in sync
      notifyListeners();
      rethrow;
    }
  }
  
  // Clear entire wishlist
  Future<void> clearWishlist() async {
    if (_wishlistService == null) return;
    
    try {
      await _wishlistService!.clearWishlist();
      _wishlistItems = [];
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear wishlist: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }
  
  // Helper method to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // Clear any error messages
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
