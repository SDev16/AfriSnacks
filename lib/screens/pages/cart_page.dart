import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:iconsax/iconsax.dart';
import 'package:meal/addons/curved_app_bar.dart';
import 'package:meal/screens/pages/checkout_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:meal/screens/login_page.dart';
import 'package:meal/services/cart_services.dart';

class CartPage extends StatefulWidget {
  final Account account;
  final models.User? user;

  const CartPage({
    super.key,
    required this.account,
    required this.user,
  });

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartService _cartService = CartService();
  final bool _isProcessingCheckout = false;
  bool _isCheckingSession = false;

  @override
  void initState() {
    super.initState();
  }

  void _updateCart() {
    setState(() {});
  }

  Future<void> _checkout() async {
    if (_cartService.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    setState(() {
      _isCheckingSession = true;
    });

    try {
      // Check if user is logged in
      models.User? currentUser = widget.user;
      
      if (currentUser == null) {
        // Try to get current session
        try {
          await widget.account.getSession(sessionId: 'current');
          currentUser = await widget.account.get();
        } catch (e) {
          // No active session
          print('No active session: $e');
        }
      }

      if (currentUser == null) {
        // User is not logged in, show login prompt
        setState(() {
          _isCheckingSession = false;
        });
        
        _showLoginPrompt();
        return;
      }

      // User is logged in, proceed to checkout
      setState(() {
        _isCheckingSession = false;
      });
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutPage(
            account: widget.account,
            user: currentUser!,
          ),
        ),
      );
    } catch (e) {
      print('Error checking session: $e');
      setState(() {
        _isCheckingSession = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking login status: ${e.toString()}')),
      );
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Login Required'),
        content: Text('You need to be logged in to checkout. Would you like to login now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginPage(account: widget.account),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: Text('LOGIN'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartStats() {
    final cartItems = _cartService.items;
    final totalItems = cartItems.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalPrice = _cartService.totalPrice;
    final uniqueItems = cartItems.length;

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
              icon: Icons.shopping_cart_rounded,
              label: 'Items',
              value: totalItems.toString(),
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatItem(
              icon: Icons.category_rounded,
              label: 'Types',
              value: uniqueItems.toString(),
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatItem(
              icon: Icons.attach_money_rounded,
              label: 'Total',
              value: '${totalPrice.toStringAsFixed(0)} Frs',
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
    final cartItems = _cartService.items;
    final bool isCartEmpty = cartItems.isEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Curved App Bar
          CurvedAppBar(
            title: 'Shopping Cart',
            subtitle: !isCartEmpty 
                ? '${cartItems.fold<int>(0, (sum, item) => sum + item.quantity)} items in cart'
                : 'Your cart is empty',
            gradientColors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
              Colors.blue.shade800,
            ],
            expandedHeight: 200,
            flexibleContent: !isCartEmpty ? _buildCartStats() : null,
            actions: [
              if (!isCartEmpty)
                IconButton(
                  icon: const Icon(Iconsax.trash,color: Colors.white,),
                  tooltip: 'Clear cart',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Clear Cart'),
                        content: Text('Are you sure you want to clear your cart?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () {
                              _cartService.clearCart();
                              Navigator.pop(context);
                              _updateCart();
                            },
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: Text('CLEAR'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),

          // Content
          isCartEmpty
              ? SliverFillRemaining(child: _buildEmptyCart())
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final cartItem = cartItems[index];
                        return _buildCartItemCard(cartItem);
                      },
                      childCount: cartItems.length,
                    ),
                  ),
                ),
        ],
      ),
      bottomNavigationBar: isCartEmpty ? null : _buildCheckoutBar(),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Colors.green.shade400,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add items to your cart to place an order',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.shopping_bag_rounded,color: Colors.white,),
            label: const Text('Continue Shopping'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(CartItem cartItem) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: cartItem.meal.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade300,
                  child: Icon(
                    Icons.image,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.meal.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    cartItem.meal.category,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${cartItem.meal.price.toStringAsFixed(0)} Frs',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuantityButton(
                        icon: Icons.remove,
                        onPressed: () {
                          _cartService.decrementQuantity(cartItem.meal.id);
                          _updateCart();
                        },
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${cartItem.quantity}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildQuantityButton(
                        icon: Icons.add,
                        onPressed: () {
                          _cartService.incrementQuantity(cartItem.meal.id);
                          _updateCart();
                        },
                      ),
                      Spacer(),
                      Text(
                        '${cartItem.totalPrice.toStringAsFixed(0)} Frs',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 32,
      height: 32,
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '${_cartService.totalPrice.toStringAsFixed(0)} Frs',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Fee',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                'Calculated at checkout',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_cartService.totalPrice.toStringAsFixed(0)} Frs+',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isCheckingSession || _isProcessingCheckout ? null : _checkout,
              child: _isCheckingSession
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('CHECKING SESSION...'),
                      ],
                    )
                  : _isProcessingCheckout
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'PROCEED TO CHECKOUT',
                          style: TextStyle(fontSize: 16),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}