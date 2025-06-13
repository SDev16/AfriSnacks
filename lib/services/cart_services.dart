
import 'package:meal/models/meals.dart';

class CartItem {
  final Meal meal;
  int quantity;
  
  CartItem({
    required this.meal,
    this.quantity = 1,
  });
  
  double get totalPrice => meal.price * quantity;
}

class CartService {
  // Singleton pattern
  static final CartService _instance = CartService._internal();
  
  factory CartService() {
    return _instance;
  }
  
  CartService._internal();
  
  // Cart items
  final List<CartItem> _items = [];
  
  // Get all items in cart
  List<CartItem> get items => _items;
  
  // Get total number of items in cart
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  
  // Get total price of all items in cart
  double get totalPrice => _items.fold(0, (sum, item) => sum + item.totalPrice);
  
  // Check if a meal is in the cart
  bool isInCart(String mealId) {
    return _items.any((item) => item.meal.id == mealId);
  }
  
  // Get cart item by meal ID
  CartItem? getCartItem(String mealId) {
    try {
      return _items.firstWhere((item) => item.meal.id == mealId);
    } catch (e) {
      return null;
    }
  }
  
  // Add a meal to cart
  void addToCart(Meal meal) {
    // Check if the meal is already in the cart
    if (isInCart(meal.id)) {
      // If it is, increase the quantity
      incrementQuantity(meal.id);
    } else {
      // If not, add it to the cart
      _items.add(CartItem(meal: meal));
    }
  }
  
  // Remove a meal from cart
  void removeFromCart(String mealId) {
    _items.removeWhere((item) => item.meal.id == mealId);
  }
  
  // Increment quantity of a meal in cart
  void incrementQuantity(String mealId) {
    final cartItem = getCartItem(mealId);
    if (cartItem != null) {
      cartItem.quantity++;
    }
  }
  
  // Decrement quantity of a meal in cart
  void decrementQuantity(String mealId) {
    final cartItem = getCartItem(mealId);
    if (cartItem != null) {
      if (cartItem.quantity > 1) {
        cartItem.quantity--;
      } else {
        removeFromCart(mealId);
      }
    }
  }
  
  // Update quantity of a meal in cart
  void updateQuantity(String mealId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(mealId);
      return;
    }
    
    final cartItem = getCartItem(mealId);
    if (cartItem != null) {
      cartItem.quantity = quantity;
    }
  }
  
  // Clear the cart
  void clearCart() {
    _items.clear();
  }
}
