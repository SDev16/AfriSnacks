import 'package:flutter/material.dart';
import 'package:meal/env/mesomb.dart';
import 'package:mesomb/mesomb.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:meal/env/app_config.dart';
import 'package:meal/screens/receipt_page.dart';
import 'dart:math';

class OrangeMoneyPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final Account account;
  final models.User user;
  final Function(bool success, Map<String, dynamic>? orderData) onPaymentComplete;

  const OrangeMoneyPage({
    super.key,
    required this.orderData,
    required this.account,
    required this.user,
    required this.onPaymentComplete,
  });

  @override
  _OrangeMoneyPageState createState() => _OrangeMoneyPageState();
}

class _OrangeMoneyPageState extends State<OrangeMoneyPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  
  // Replace with your actual Orange Money API credentials
  final String applicationKey = Mesomb.applicationKey;
  final String accessKey = Mesomb.accessKey;
  final String secretKey = Mesomb.secretKey;
  
  bool _isLoading = false;
  String? _errorMessage;

  // Get total amount from order data
  double get totalAmount => widget.orderData['total']?.toDouble() ?? 0.0;
  String get orderId => widget.orderData['orderId'] ?? '';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_isLoading) {
      return false; // Prevent back navigation during payment processing
    }
    
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment'),
        content: const Text('Are you sure you want to cancel the Orange Money payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Payment'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      widget.onPaymentComplete(false, null);
    }
    
    return shouldExit ?? false;
  }

  Future<void> _processPayment() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final payment = PaymentOperation(applicationKey, accessKey, secretKey);
    
    final response = await payment.makeCollect(
        amount: totalAmount,
        service: 'ORANGE',
        payer: _phoneController.text.trim(),
        nonce: Random().nextInt(1 << 32).toString(),
        trxID: orderId,
      );

    if (!mounted) return;

    if (response.isOperationSuccess() && response.isTransactionSuccess()) {
      // Payment successful - update order data with extracted values
      final updatedOrderData = Map<String, dynamic>.from(widget.orderData);
      updatedOrderData['paymentStatus'] = 'Completed';
      
      // Extract specific values from the response instead of saving the whole object
        updatedOrderData['transactionId'] = response.toString();
        updatedOrderData['transactionReference'] = response.reference?.toString() ?? '';
        updatedOrderData['status'] = response.status.toString();
        updatedOrderData['paymentDate'] = DateTime.now().toIso8601String();
        updatedOrderData['momoProvider'] = 'ORANGE';
        updatedOrderData['userPhone'] = _phoneController.text.trim();
      
      // Save order to database
      await _saveOrderToDatabase(updatedOrderData);
      
      // Show success dialog
      await _showSuccessDialog();
      
      // Navigate to receipt page
      _showReceipt(updatedOrderData);
      
    } else {
      setState(() {
        _errorMessage = 'Payment failed. Please check your phone number and try again.';
      });
    }
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _errorMessage = 'Payment error: ${e.toString()}';
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

Future<void> _saveOrderToDatabase(Map<String, dynamic> orderData) async {
  try {
    final databases = Databases(widget.account.client);
    
    // Ensure all values are JSON serializable
    final cleanOrderData = <String, dynamic>{};
    
    orderData.forEach((key, value) {
      if (value != null) {
        // Convert all values to basic types
        if (value is String || value is num || value is bool) {
          cleanOrderData[key] = value;
        } else if (value is DateTime) {
          cleanOrderData[key] = value.toIso8601String();
        } else {
          cleanOrderData[key] = value.toString();
        }
      }
    });
    
    print('Saving order data: $cleanOrderData'); // Debug log
    
    // Save order to database
    await databases.createDocument(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.ordersId,
      documentId: ID.unique(),
      data: cleanOrderData,
    );
    
    print('Order saved successfully to database');
  } catch (e) {
    print('Error saving order to database: $e');
    rethrow;
  }
}

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: Colors.green.shade800,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Orange Money payment of ${totalAmount.toStringAsFixed(0)} FCFA has been processed successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('View Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceipt(Map<String, dynamic> orderData) {
    // Navigate to receipt page
    Navigator.pushReplacement(
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
      // Call completion callback
      widget.onPaymentComplete(true, orderData);
    });
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your Orange phone number';
    }
    
    // Remove any spaces or special characters
    final cleanNumber = value.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Check if it's a valid Cameroon Orange number
    if (!cleanNumber.startsWith('237') && !cleanNumber.startsWith('+237')) {
      return 'Please include country code (237)';
    }
    
    // Orange numbers in Cameroon typically start with 69, 65, 66
    final numberWithoutCountryCode = cleanNumber.replaceFirst(RegExp(r'^\+?237'), '');
    if (!RegExp(r'^6[569]\d{7}$').hasMatch(numberWithoutCountryCode)) {
      return 'Please enter a valid Orange number (65, 66, or 69)';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orange MoMo'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: _isLoading 
              ? null 
              : IconButton(
                  icon: const Icon(Icons.stop,color: Colors.transparent,),
                  onPressed: () => _onWillPop(),
                ),
        ),
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF6600), Color(0xFFFF8C00)], // Orange gradient
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [ 
                  // Payment Info Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Payment Amount',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                  
                          Text(
                            '${totalAmount.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF6600),
                            ),
                          ),
                     
                          Text(
                            'Order ID: $orderId',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Order details summary
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Subtotal:', style: TextStyle(color: Colors.grey.shade700)),
                                    Text('${widget.orderData['subtotal']?.toStringAsFixed(0) ?? '0'} FCFA'),
                                  ],
                                ),
                          
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Delivery Fee:', style: TextStyle(color: Colors.grey.shade700)),
                                    Text('${widget.orderData['deliveryFee']?.toStringAsFixed(0) ?? '0'} FCFA'),
                                  ],
                                ),
                         
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Tax:', style: TextStyle(color: Colors.grey.shade700)),
                                    Text('${widget.orderData['tax']?.toStringAsFixed(0) ?? '0'} FCFA'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Phone Number Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enter your Orange phone number',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Make sure to include country code (237)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            hintText: '237 6X XXX XXXX',
                            prefixIcon: const Icon(Icons.phone, color: Color(0xFFFF6600)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone,
                          enabled: !_isLoading,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Error Message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const Spacer(),
                  
                  // Pay Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFF6600),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6600)),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Processing Payment...',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        : Text(
                            'Pay ${totalAmount.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}