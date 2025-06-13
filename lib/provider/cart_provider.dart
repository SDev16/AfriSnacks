import 'package:flutter/foundation.dart';
import 'package:meal/models/meals.dart';
import 'package:meal/services/cart_services.dart';

// Remove the duplicate CartItem class definition and use the one from cart_services.dart

class CartProvider with ChangeNotifier {
  // Use the existing CartService singleton
  final CartService _cartService = CartService();
  
  // Getters that delegate to the CartService
  List<CartItem> get items => _cartService.items;
  int get itemCount => _cartService.itemCount;
  double get totalPrice => _cartService.totalPrice;
  bool get isEmpty => _cartService.items.isEmpty;
  
  // Check if a meal is in the cart
  bool isInCart(String mealId) => _cartService.isInCart(mealId);
  
  // Get cart item by meal ID
  CartItem? getCartItem(String mealId) => _cartService.getCartItem(mealId);
  
  // Add a meal to cart
  void addToCart(Meal meal, {int quantity = 1}) {
    if (quantity <= 0) return;
    
    if (_cartService.isInCart(meal.id)) {
      // If it's already in cart, update quantity
      final currentQuantity = _cartService.getCartItem(meal.id)?.quantity ?? 0;
      _cartService.updateQuantity(meal.id, currentQuantity + quantity);
    } else {
      // Add to cart
      _cartService.addToCart(meal);
      
      // If quantity > 1, update the quantity after adding
      if (quantity > 1) {
        _cartService.updateQuantity(meal.id, quantity);
      }
    }
    
    // Notify listeners to update UI
    notifyListeners();
  }
  
  // Remove a meal from cart
  void removeFromCart(String mealId) {
    _cartService.removeFromCart(mealId);
    notifyListeners();
  }
  
  // Increment quantity of a meal in cart
  void incrementQuantity(String mealId) {
    _cartService.incrementQuantity(mealId);
    notifyListeners();
  }
  
  // Decrement quantity of a meal in cart
  void decrementQuantity(String mealId) {
    _cartService.decrementQuantity(mealId);
    notifyListeners();
  }
  
  // Update quantity of a meal in cart
  void updateQuantity(String mealId, int quantity) {
    _cartService.updateQuantity(mealId, quantity);
    notifyListeners();
  }
  
  // Clear the cart
  void clearCart() {
    _cartService.clearCart();
    notifyListeners();
  }
  
  // Get quantity of specific meal in cart
  int getMealQuantity(String mealId) {
    return _cartService.getCartItem(mealId)?.quantity ?? 0;
  }
}
