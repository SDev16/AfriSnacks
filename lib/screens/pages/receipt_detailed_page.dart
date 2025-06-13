import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReceiptDetailPage extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final Account account;
  final models.User user;

  const ReceiptDetailPage({
    super.key,
    required this.receipt,
    required this.account,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM dd, yyyy hh:mm a');
    final orderDate =
        DateTime.parse(receipt['orderDate'] ?? DateTime.now().toString());
    final formattedDate = formatter.format(orderDate);

    final rawItems = receipt['items'];
    final items = rawItems is String
        ? jsonDecode(rawItems) as List
        : (rawItems as List?) ?? [];
    final subtotal = receipt['subtotal'] ?? 0.0;
    final deliveryFee = receipt['deliveryFee'] ?? 0.0;
    final tax = receipt['tax'] ?? 0.0;
    final total = receipt['total'] ?? 0.0;

    final isReservation = receipt['orderType'] == 'Reservation';

    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () => _shareReceipt(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator
            _buildStatusBadge(receipt['status'] ?? 'Pending'),
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
                          'Order #${receipt['orderId']}',
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
                          isReservation
                              ? Icons.restaurant
                              : Icons.delivery_dining,
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
                          receipt['paymentMethod'] == 'Cash on Delivery'
                              ? Icons.payments
                              : Icons.phone_android,
                          color: Colors.green,
                        ),
                        SizedBox(width: 8),
                        Text(
                          receipt['paymentMethod'] ?? 'N/A',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (receipt['momoProvider']?.isNotEmpty ?? false) ...[
                          Text(' - '),
                          Text(
                            receipt['momoProvider'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: receipt['momoProvider'] == 'MTN'
                                  ? Colors.yellow.shade800
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 8),
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
                    _buildInfoRow('Name', receipt['userName'] ?? 'N/A'),
                    SizedBox(height: 4),
                    _buildInfoRow('Phone', receipt['userPhone'] ?? 'N/A'),
                    SizedBox(height: 4),
                    _buildInfoRow('Email', receipt['userEmail'] ?? 'N/A'),
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
                      isReservation
                          ? 'Reservation Details'
                          : 'Delivery Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildInfoRow(
                        'Location', receipt['deliveryLocation'] ?? 'N/A'),
                    SizedBox(height: 4),
                    _buildInfoRow(
                        'Address', receipt['deliveryAddress'] ?? 'N/A'),
                    if (isReservation) ...[
                      SizedBox(height: 4),
                      _buildInfoRow(
                        'Date',
                        _formatReservationDate(receipt['reservationDate']),
                      ),
                      SizedBox(height: 4),
                      _buildInfoRow(
                        'Time',
                        _formatReservationTime(receipt['reservationTime']),
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
                        )),
                    Divider(height: 24),
                    _buildPriceRow('Subtotal', subtotal),
                    SizedBox(height: 4),
                    _buildPriceRow(
                        isReservation ? 'Reservation Fee' : 'Delivery Fee',
                        deliveryFee),
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
            if (receipt['notes']?.isNotEmpty ?? false)
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
                      Text(receipt['notes']),
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

  Widget _buildPriceRow(
    String label,
    dynamic amount, {
    bool isBold = false,
    Color? textColor,
  }) {
    final formattedAmount =
        '${(amount is num ? amount : 0.0).toStringAsFixed(0)} Frs';

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

  Future<void> _shareReceipt(BuildContext context) async {
    try {
      final pdf = await _generatePdf();
      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/receipt_${receipt['orderId']}.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Your order receipt #${receipt['orderId']}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share receipt: $e')),
      );
    }
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    final rawItems = receipt['items'];
    final items = rawItems is String
        ? jsonDecode(rawItems) as List
        : (rawItems as List?) ?? [];
    final subtotal = receipt['subtotal'] ?? 0.0;
    final deliveryFee = receipt['deliveryFee'] ?? 0.0;
    final tax = receipt['tax'] ?? 0.0;
    final total = receipt['total'] ?? 0.0;

    final isReservation = receipt['orderType'] == 'Reservation';
    final formatter = DateFormat('MMM dd, yyyy hh:mm a');
    final orderDate =
        DateTime.parse(receipt['orderDate'] ?? DateTime.now().toString());
    final formattedDate = formatter.format(orderDate);

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Order info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Order #${receipt['orderId']}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  pw.Text(formattedDate),
                ],
              ),
              pw.Divider(),

              // Customer info
              pw.Text(
                'Customer Information',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text('Name: ${receipt['userName'] ?? 'N/A'}'),
              pw.Text('Phone: ${receipt['userPhone'] ?? 'N/A'}'),
              pw.Text('Email: ${receipt['userEmail'] ?? 'N/A'}'),
              pw.SizedBox(height: 10),

              // Delivery/Reservation info
              pw.Text(
                isReservation ? 'Reservation Details' : 'Delivery Details',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text('Location: ${receipt['deliveryLocation'] ?? 'N/A'}'),
              pw.Text('Address: ${receipt['deliveryAddress'] ?? 'N/A'}'),

              if (isReservation) ...[
                pw.Text(
                    'Date: ${_formatReservationDate(receipt['reservationDate'])}'),
                pw.Text(
                    'Time: ${_formatReservationTime(receipt['reservationTime'])}'),
              ],

              pw.SizedBox(height: 10),

              // Payment info
              pw.Text(
                'Payment Information',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text('Method: ${receipt['paymentMethod'] ?? 'N/A'}'),
              if (receipt['momoProvider']?.isNotEmpty ?? false)
                pw.Text('Provider: ${receipt['momoProvider']}'),

              pw.SizedBox(height: 15),

              // Order items
              pw.Text(
                'Order Items',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 5),

              // Items table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  // Table header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Item',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Price',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),

                  // Table rows for items
                  ...items.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: pw.EdgeInsets.all(5),
                            child: pw.Text('${item['quantity']}'),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(5),
                            child: pw.Text(item['name'] ?? 'Unknown Item'),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(5),
                            child: pw.Text(
                              '\$${(item['price'] ?? 0.0).toStringAsFixed(0)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(5),
                            child: pw.Text(
                              '\$${((item['price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(0)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      )),
                ],
              ),

              pw.SizedBox(height: 15),

              // Order summary
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text('Subtotal:'),
                        ),
                        pw.Text('\$${subtotal.toStringAsFixed(0)}'),
                      ],
                    ),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(isReservation
                              ? 'Reservation Fee:'
                              : 'Delivery Fee:'),
                        ),
                        pw.Text('\$${deliveryFee.toStringAsFixed(0)}'),
                      ],
                    ),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text('Tax (8%):'),
                        ),
                        pw.Text('\$${tax.toStringAsFixed(0)}'),
                      ],
                    ),
                    pw.Divider(thickness: 0.5),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(
                            'Total:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Text(
                          '\$${total.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your order!',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text('For any questions or support, please contact us:'),
                    pw.Text('support@example.com | +1 234 567 890'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }
}
