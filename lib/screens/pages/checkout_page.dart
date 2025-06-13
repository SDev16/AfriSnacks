import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'dart:convert';
import 'package:meal/models/location.dart';
import 'package:meal/env/app_config.dart';
import 'package:meal/payments/mtn_money_page.dart';
import 'package:meal/payments/orange_money.dart';
import 'package:meal/screens/receipt_page.dart';
import 'package:meal/services/cart_services.dart';
import 'package:meal/addons/curved_app_bar.dart';

class CheckoutPage extends StatefulWidget {
  final Account account;
  final models.User user;

  const CheckoutPage({
    super.key,
    required this.account,
    required this.user,
  });

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final CartService _cartService = CartService();
  bool _isLoading = true;
  bool _isProcessingOrder = false;
  String? _errorMessage;
  List<DeliveryLocation> _locations = [];
  DeliveryLocation? _selectedLocation;
  
  // Form controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Payment method
  String _paymentMethod = 'Cash on Delivery';
  final List<String> _paymentMethods = ['Cash on Delivery', 'Mobile Money (MoMo)'];
  String _momoProvider = ''; // 'MTN' or 'Orange'
  
  // Order type
  String _orderType = 'Delivery'; // 'Delivery' or 'Reservation'
  
  // Reservation details
  DateTime _reservationDate = DateTime.now().add(Duration(days: 1));
  TimeOfDay _reservationTime = TimeOfDay(hour: 12, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadUserInfo() {
    _nameController.text = widget.user.name;
    _emailController.text = widget.user.email;
    
    // Try to get phone from user profile if available
    // This would need to be implemented based on your user profile structure
  }

  Future<void> _fetchLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final databases = Databases(widget.account.client);
      
      // Fetch locations from Appwrite
      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.locationsCollectionId,
      );

      final fetchedLocations = response.documents
          .map((doc) => DeliveryLocation.fromJson({...doc.data, '\$id': doc.$id}))
          .toList();

      setState(() {
        _locations = fetchedLocations;
        
        // Set default location if available
        final defaultLocation = _locations.isNotEmpty
            ? _locations.firstWhere(
                (location) => location.isDefault,
                orElse: () => _locations.first,
              )
            : null;

        if (defaultLocation != null) {
          _selectedLocation = defaultLocation;
        }
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching locations: $e');
      setState(() {
        _errorMessage = 'Failed to load delivery locations. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _placeOrder() async {
    // Validate form
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter your name');
      return;
    }
    
    if (_phoneController.text.trim().isEmpty) {
      _showError('Please enter your phone number');
      return;
    }
    
    if (_selectedLocation == null) {
      _showError('Please select a delivery location');
      return;
    }
    
    if (_cartService.items.isEmpty) {
      _showError('Your cart is empty');
      return;
    }
    
    // Validate payment method
    if (!_validatePaymentMethod()) {
      return;
    }

    setState(() {
      _isProcessingOrder = true;
    });

    try {
      // Generate order ID
      final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      
      // Create order data (but don't save to database yet for MoMo payments)
      final orderData = _createOrderData(orderId);
      
      // Handle different payment methods
      if (_paymentMethod == 'Cash on Delivery') {
        // For Cash on Delivery, create order immediately since payment happens on delivery
        await _saveOrderToDatabase(orderData);
        _cartService.clearCart();
        _showReceipt(orderData);
      } else {
        // For Mobile Money, process payment first, then create order on success
        _processMomoPayment(orderData);
      }
    } catch (e) {
      _showError('Failed to process order: ${e.toString()}');
      setState(() {
        _isProcessingOrder = false;
      });
    }
  }

  Map<String, dynamic> _createOrderData(String orderId) {
    // Convert items array to a JSON string
    final itemsJson = jsonEncode(_cartService.items.map((item) => {
      'id': item.meal.id,
      'name': item.meal.name,
      'price': item.meal.price,
      'quantity': item.quantity,
    }).toList());

    // Create order data
    final orderData = {
      'orderId': orderId,
      'userId': widget.user.$id,
      'userName': _nameController.text,
      'userPhone': _phoneController.text,
      'userEmail': _emailController.text,
      'orderType': _orderType,
      'deliveryLocation': _selectedLocation!.name,
      'deliveryAddress': _selectedLocation!.address,
      'paymentMethod': _paymentMethod,
      'momoProvider': _momoProvider,
      'items': itemsJson,
      'subtotal': _cartService.totalPrice,
      'deliveryFee': _orderType == 'Delivery' ? _selectedLocation!.deliveryFee : 0.0,
      'tax': _cartService.totalPrice * 0.08, // 8% tax
      'total': _cartService.totalPrice + 
              (_orderType == 'Delivery' ? _selectedLocation!.deliveryFee : 0.0) + 
              (_cartService.totalPrice * 0.08),
      'orderDate': DateTime.now().toString(),
      'notes': _notesController.text,
      'status': 'Pending',
      'paymentStatus': _paymentMethod == 'Cash on Delivery' ? 'Pending' : 'Processing',
    };
    
    // Add reservation details if order type is Reservation
    if (_orderType == 'Reservation') {
      orderData['reservationDate'] = _reservationDate.toString();
      orderData['reservationTime'] = '${_reservationTime.hour}:${_reservationTime.minute}';
    }
    
    return orderData;
  }

  Future<void> _saveOrderToDatabase(Map<String, dynamic> orderData) async {
    try {
      final databases = Databases(widget.account.client);
      
      // Save order to database
      await databases.createDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.ordersId,
        documentId: ID.unique(),
        data: orderData,
      );
    } catch (e) {
      print('Error saving order to database: $e');
      rethrow;
    }
  }

 void _processMomoPayment(Map<String, dynamic> orderData) {
  // Reset loading state
  setState(() {
    _isProcessingOrder = false;
  });

    // Calculate total amount
    final totalAmount = orderData['total'];
    
    // Navigate to the appropriate payment page based on provider
     if (_momoProvider == 'MTN') {
    // Show MTN payment page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MtnPaymentPage(
          orderData: orderData, // Pass complete order data
          account: widget.account,
          user: widget.user,
          onPaymentComplete: (success, updatedOrderData) {
            if (success && updatedOrderData != null) {
              // Clear cart after successful payment
              _cartService.clearCart();
              // Payment successful, receipt already shown
              print('MTN payment completed successfully');
            } else {
              // Payment failed
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('MTN payment failed. Please try again.')),
              );
            }
          },
        ),
      ),
    );
  } else if (_momoProvider == 'Orange') {
    // Show Orange Money payment page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrangeMoneyPage(
          orderData: orderData, // Pass complete order data
          account: widget.account,
          user: widget.user,
          onPaymentComplete: (success, updatedOrderData) {
            if (success && updatedOrderData != null) {
              // Clear cart after successful payment
              _cartService.clearCart();
              // Payment successful, receipt already shown
              print('Orange Money payment completed successfully');
            } else {
              // Payment failed
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Orange Money payment failed. Please try again.')),
              );
            }
          },
        ),
      ),
    );
  } else {
    _showError('Please select a Mobile Money provider');
  }
}

  void _showReceipt(Map<String, dynamic> orderData) {
    // Reset loading state
    setState(() {
      _isProcessingOrder = false;
    });
    
    // Navigate to receipt page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptPage(
          orderData: orderData,
          account: widget.account,
          user: widget.user,
        ),
        fullscreenDialog: true,
      ),
    ).then((_) {
      // After viewing receipt, navigate back to home
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildCheckoutSummary() {
    final cartItems = _cartService.items;
    final itemCount = cartItems.fold<int>(0, (sum, item) => sum + item.quantity);
    final subtotal = _cartService.totalPrice;
    final deliveryFee = _orderType == 'Delivery' ? (_selectedLocation?.deliveryFee ?? 0.0) : 0.0;
    final tax = subtotal * 0.08; // 8% tax
    final total = subtotal + deliveryFee + tax;

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
              value: itemCount.toString(),
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatItem(
              icon: _orderType == 'Delivery' ? Icons.delivery_dining : Icons.restaurant,
              label: _orderType,
              value: _orderType == 'Delivery' ? 'Home' : 'Table',
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatItem(
              icon: Icons.attach_money_rounded,
              label: 'Total',
              value: '${total.toStringAsFixed(0)} Frs',
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
          size: 18,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Curved App Bar
          CurvedAppBar(
            title: 'Checkout',
            subtitle: _orderType == 'Delivery' 
                ? 'Complete your delivery order' 
                : 'Complete your table reservation',
            gradientColors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
              Colors.blue.shade800,
            ],
            expandedHeight: 200,
            flexibleContent: _buildCheckoutSummary(),
          ),

          // Content
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading checkout information...'),
                      ],
                    ),
                  ),
                )
              : _errorMessage != null
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchLocations,
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Order Summary
                            _buildSectionTitle('Order Summary'),
                            _buildOrderSummary(),
                            SizedBox(height: 24),
                            
                            // Contact Information
                            _buildSectionTitle('Contact Information'),
                            _buildContactForm(),
                            SizedBox(height: 24),
                            
                            // Order Type Selection
                            _buildSectionTitle('Order Type'),
                            _buildOrderTypeSelector(),
                            SizedBox(height: 24),
                            
                            // Delivery Location
                            _buildSectionTitle(_orderType == 'Delivery' ? 'Delivery Location' : 'Pickup Location'),
                            _buildLocationDropdown(),
                            SizedBox(height: 24),
                    
                            // Reservation Date and Time (only if Reservation is selected)
                            if (_orderType == 'Reservation') ...[
                              _buildSectionTitle('Reservation Date & Time'),
                              _buildReservationDateTimePicker(),
                              SizedBox(height: 24),
                            ],
                            
                            // Payment Method
                            _buildSectionTitle('Payment Method'),
                            _buildPaymentMethodSelector(),
                            SizedBox(height: 24),
                            
                            // Additional Notes
                            _buildSectionTitle('Additional Notes'),
                            TextField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                hintText: _orderType == 'Delivery' 
                                    ? 'Special instructions for delivery' 
                                    : 'Special instructions for your reservation',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            SizedBox(height: 32),
                            
                            // Place Order Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isProcessingOrder ? null : _placeOrder,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isProcessingOrder
                                    ? CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                        _orderType == 'Delivery' ? 'PLACE DELIVERY ORDER' : 'MAKE RESERVATION',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final cartItems = _cartService.items;
    final subtotal = _cartService.totalPrice;
    final deliveryFee = _orderType == 'Delivery' ? (_selectedLocation?.deliveryFee ?? 0.0) : 0.0;
    final tax = subtotal * 0.08; // 8% tax
    final total = subtotal + deliveryFee + tax;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Items summary
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '${cartItems.length} items in your order',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // List of items (limited to first 3)
            ...cartItems.take(3).map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.quantity}x',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.meal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(item.meal.price * item.quantity).toStringAsFixed(0)} Frs',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )),
            
            // Show "more items" if there are more than 3
            if (cartItems.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '+ ${cartItems.length - 3} more items',
                  style: TextStyle(
                    color: Colors.blue,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
            
            Divider(height: 24),
            
            // Price breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal'),
                Text('${subtotal.toStringAsFixed(0)} Frs'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_orderType == 'Delivery' ? 'Delivery Fee' : 'Reservation Fee'),
                Text('${deliveryFee.toStringAsFixed(0)} Frs'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tax (8%)'),
                Text('${tax.toStringAsFixed(0)} Frs'),
              ],
            ),
            Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${total.toStringAsFixed(0)} Frs',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person, color: Colors.blue),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone, color: Colors.blue),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email, color: Colors.blue),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: false, // Email is pre-filled and not editable
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTypeSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How would you like to receive your order?',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOrderTypeOption(
                    title: 'Delivery',
                    icon: Icons.delivery_dining,
                    description: 'Get your order delivered to your location',
                    isSelected: _orderType == 'Delivery',
                    onTap: () {
                      setState(() {
                        _orderType = 'Delivery';
                      });
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildOrderTypeOption(
                    title: 'Reservation',
                    icon: Icons.restaurant,
                    description: 'Reserve a table and dine at our restaurant',
                    isSelected: _orderType == 'Reservation',
                    onTap: () {
                      setState(() {
                        _orderType = 'Reservation';
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTypeOption({
    required String title,
    required IconData icon,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected ? Colors.blue : Colors.grey.shade700,
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected ? Colors.blue.shade800 : Colors.black,
              ),
            ),
            SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDropdown() {
    if (_locations.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.location_off,
                  size: 48,
                  color: Colors.grey,
                ),
                SizedBox(height: 8),
                Text(
                  'No locations available',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to add location page
                    // This would need to be implemented
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Add New Location'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _orderType == 'Delivery' ? Icons.location_on : Icons.store,
                  color: Colors.blue,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  _orderType == 'Delivery' ? 'Select Delivery Location' : 'Select Pickup Location',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Dropdown for location selection
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DeliveryLocation>(
                  value: _selectedLocation,
                  hint: Text(
                    _orderType == 'Delivery' ? 'Choose delivery location' : 'Choose pickup location',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: Colors.blue),
                  items: _locations.map((location) {
                    return DropdownMenuItem<DeliveryLocation>(
                      value: location,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  location.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (location.isDefault)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Default',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 0,),
                          Text(
                            location.address,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_orderType == 'Delivery')
                            Text(
                              'Fee: ${location.deliveryFee.toStringAsFixed(0)} Frs',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (DeliveryLocation? newLocation) {
                    setState(() {
                      _selectedLocation = newLocation;
                    });
                  },
                ),
              ),
            ),
            
            // Show selected location details
            if (_selectedLocation != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.blue.shade700,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Selected Location',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _selectedLocation!.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _selectedLocation!.address,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    if (_orderType == 'Delivery') ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.delivery_dining,
                            color: Colors.blue.shade700,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delivery Fee: ${_selectedLocation!.deliveryFee.toStringAsFixed(0)} Frs',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReservationDateTimePicker() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Picker
            InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _reservationDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 30)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: Colors.blue,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null && picked != _reservationDate) {
                  setState(() {
                    _reservationDate = picked;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reservation Date',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${_reservationDate.day}/${_reservationDate.month}/${_reservationDate.year}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Time Picker
            InkWell(
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: _reservationTime,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: Colors.blue,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null && picked != _reservationTime) {
                  setState(() {
                    _reservationTime = picked;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.blue),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reservation Time',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _reservationTime.format(context),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Payment Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ...List.generate(_paymentMethods.length, (index) {
              final method = _paymentMethods[index];
              final isSelected = _paymentMethod == method;
              
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                ),
                child: RadioListTile<String>(
                  title: Text(
                    method,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  value: method,
                  groupValue: _paymentMethod,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() {
                      _paymentMethod = value!;
                      // Reset MoMo provider when switching payment methods
                      if (_paymentMethod != 'Mobile Money (MoMo)') {
                        _momoProvider = '';
                      } else {
                        // Show MoMo provider selection dialog
                        _showMomoProviderDialog();
                      }
                    });
                  },
                ),
              );
            }),
            
            // Show selected MoMo provider if applicable
            if (_paymentMethod == 'Mobile Money (MoMo)' && _momoProvider.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _momoProvider == 'MTN' 
                      ? Colors.yellow.shade50 
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _momoProvider == 'MTN' 
                        ? Colors.yellow.shade800 
                        : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _momoProvider == 'MTN' 
                          ? Colors.yellow.shade800 
                          : Colors.orange,
                      child: Text(
                        _momoProvider == 'MTN' ? 'MTN' : 'OM',
                        style: TextStyle(
                          color: _momoProvider == 'MTN' ? Colors.black : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _momoProvider == 'MTN' ? 'MTN Mobile Money' : 'Orange Money',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Selected for payment',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _showMomoProviderDialog,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade800,
                      ),
                      child: Text('Change'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMomoProviderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Mobile Money Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.yellow.shade800,
                child: Text('MTN', style: TextStyle(color: Colors.black, fontSize: 12)),
              ),
              title: Text('MTN Mobile Money'),
              onTap: () {
                setState(() {
                  _momoProvider = 'MTN';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange,
                child: Text('OM', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              title: Text('Orange Money'),
              onTap: () {
                setState(() {
                  _momoProvider = 'Orange';
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Add this function to validate payment method selection
  bool _validatePaymentMethod() {
    if (_paymentMethod == 'Mobile Money (MoMo)' && _momoProvider.isEmpty) {
      _showError('Please select a Mobile Money provider');
      return false;
    }
    return true;
  }
}
