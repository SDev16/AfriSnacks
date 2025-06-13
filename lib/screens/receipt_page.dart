import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:intl/intl.dart';

class ReceiptPage extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final Account account;
  final models.User user;

  const ReceiptPage({
    super.key,
    required this.orderData,
    required this.account,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM dd, yyyy hh:mm a');
    final orderDate = DateTime.parse(orderData['orderDate'] ?? DateTime.now().toString());
    final formattedDate = formatter.format(orderDate);
    
   final rawItems = orderData['items'];
    final items = rawItems is String
        ? jsonDecode(rawItems) as List
        : (rawItems as List?) ?? [];
    final subtotal = orderData['subtotal'] ?? 0.0;
    final deliveryFee = orderData['deliveryFee'] ?? 0.0;
    final tax = orderData['tax'] ?? 0.0;
    final total = orderData['total'] ?? 0.0;
    
    final isReservation = orderData['orderType'] == 'Reservation';
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold),),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator
            _buildStatusBadge(orderData['status'] ?? 'Pending'),
            SizedBox(height: 16),
            
            // Receipt header
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${orderData['orderId']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        
                      ],
                    ),
                    Divider(height: 24),
                    Row(
                      children: [
                        Icon(
                          isReservation ? Icons.restaurant : Icons.delivery_dining,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 8),
                        Text(
                          isReservation ? 'Reservation' : 'Delivery',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          orderData['paymentMethod'] == 'Cash on Delivery' 
                              ? Icons.payments 
                              : Icons.phone_android,
                          color: Colors.green,
                        ),
                        SizedBox(width: 8),
                        Text(
                          orderData['paymentMethod'] ?? 'N/A',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (orderData['momoProvider']?.isNotEmpty ?? false) ...[
                          Text(' - '),
                          Text(
                            orderData['momoProvider'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: orderData['momoProvider'] == 'MTN' 
                                  ? Colors.yellow.shade800 
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8,),
                    Text(
                          formattedDate,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                  ],
                ),
              ),
              
            ),
            SizedBox(height: 16),
            
            // Customer information
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildInfoRow('Name', orderData['userName'] ?? 'N/A'),
                    SizedBox(height: 4),
                    _buildInfoRow('Phone', orderData['userPhone'] ?? 'N/A'),
                    SizedBox(height: 4),
                    _buildInfoRow('Email', orderData['userEmail'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Delivery or Reservation information
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReservation ? 'Reservation Details' : 'Delivery Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildInfoRow(
                      'Location', 
                      orderData['deliveryLocation'] ?? 'N/A'
                    ),
                    SizedBox(height: 4),
                    _buildInfoRow(
                      'Address', 
                      orderData['deliveryAddress'] ?? 'N/A'
                    ),
                    
                    if (isReservation) ...[
                      SizedBox(height: 4),
                      _buildInfoRow(
                        'Date',
                        _formatReservationDate(orderData['reservationDate']),
                      ),
                      SizedBox(height: 4),
                      _buildInfoRow(
                        'Time',
                        _formatReservationTime(orderData['reservationTime']),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Order items
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Items',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    ...items.map<Widget>((item) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            '${item['quantity']}x',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(item['name'] ?? 'Unknown Item'),
                          ),
                          Text(
                            '${(item['price'] * item['quantity']).toStringAsFixed(0)} Frs',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    ),
                    Divider(height: 24),
                    _buildPriceRow('Subtotal', subtotal),
                    SizedBox(height: 4),
                    _buildPriceRow(
                      isReservation ? 'Reservation Fee' : 'Delivery Fee', 
                      deliveryFee
                    ),
                    SizedBox(height: 4),
                    _buildPriceRow('Tax (8%)', tax),
                    Divider(height: 16),
                    _buildPriceRow(
                      'Total', 
                      total,
                      isBold: true,
                      textColor: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Notes
            if (orderData['notes']?.isNotEmpty ?? false)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(orderData['notes']),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 24),
            
            // Support information
            Center(
              child: Column(
                children: [
                  Text(
                    'Thank you for your order!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'For any questions or support, please contact us:',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'support@example.com | +1 234 567 890',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case 'processing':
        color = Colors.blue;
        icon = Icons.sync;
        break;
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, dynamic amount, {
    bool isBold = false,
    Color? textColor,
  }) {
    final formattedAmount = '${(amount is num ? amount : 0.0).toStringAsFixed(0)} Frs';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
        Text(
          formattedAmount,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textColor,
            fontSize: isBold ? 16 : null,
          ),
        ),
      ],
    );
  }

  String _formatReservationDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatReservationTime(String? timeString) {
    if (timeString == null) return 'N/A';
    
    // Handle time in format "HH:MM"
    final parts = timeString.split(':');
    if (parts.length == 2) {
      try {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final time = TimeOfDay(hour: hour, minute: minute);
        
        final period = time.period == DayPeriod.am ? 'AM' : 'PM';
        final hourIn12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
        return '$hourIn12:${time.minute.toString().padLeft(2, '0')} $period';
      } catch (e) {
        return timeString;
      }
    }
    
    return timeString;
  }
}
