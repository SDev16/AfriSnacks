import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:meal/screens/pages/receipt_detailed_page.dart';
import 'package:meal/env/app_config.dart';
import 'package:intl/intl.dart';

class AdminReceiptsManagement extends StatefulWidget {
  final Account account;
  final models.User user;
  final Client client;

  const AdminReceiptsManagement({
    super.key,
    required this.account,
    required this.user,
    required this.client,
  });

  @override
  _AdminReceiptsManagementState createState() =>
      _AdminReceiptsManagementState();
}

class _AdminReceiptsManagementState extends State<AdminReceiptsManagement> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allReceipts = [];
  String? _errorMessage;

  // Filtering
  String _filterStatus = 'All'; // 'All', 'Pending', 'Processing', 'Completed', 'Cancelled'
  String _filterType = 'All'; // 'All', 'Delivery', 'Reservation'

  // Sorting
  String _sortBy = 'Date (Newest)'; // 'Date (Newest)', 'Date (Oldest)', 'Total (High)', 'Total (Low)'

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Valid status options for consistency
  final List<String> _validStatuses = ['Pending', 'Processing', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _fetchAllReceipts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllReceipts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final databases = Databases(widget.account.client);

      // Fetch all orders (admin can see all orders)
      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.ordersId,
        queries: [
          Query.orderDesc('\$createdAt'),
          Query.limit(100), // Limit to prevent too much data
        ],
      );

      final fetchedReceipts = response.documents
          .map((doc) => {...doc.data, '\$id': doc.$id})
          .toList();

      setState(() {
        _allReceipts = fetchedReceipts;
        _isLoading = false;
      });

      // Apply initial sorting
      _sortReceipts();
    } catch (e) {
      print('Error fetching receipts: $e');
      setState(() {
        _errorMessage = 'Failed to load receipts. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _sortReceipts() {
    setState(() {
      switch (_sortBy) {
        case 'Date (Newest)':
          _allReceipts.sort((a, b) {
            final dateA = DateTime.parse(a['orderDate'] ?? '');
            final dateB = DateTime.parse(b['orderDate'] ?? '');
            return dateB.compareTo(dateA);
          });
          break;
        case 'Date (Oldest)':
          _allReceipts.sort((a, b) {
            final dateA = DateTime.parse(a['orderDate'] ?? '');
            final dateB = DateTime.parse(b['orderDate'] ?? '');
            return dateA.compareTo(dateB);
          });
          break;
        case 'Total (High)':
          _allReceipts.sort((a, b) {
            final totalA = a['total'] ?? 0.0;
            final totalB = b['total'] ?? 0.0;
            return totalB.compareTo(totalA);
          });
          break;
        case 'Total (Low)':
          _allReceipts.sort((a, b) {
            final totalA = a['total'] ?? 0.0;
            final totalB = b['total'] ?? 0.0;
            return totalA.compareTo(totalB);
          });
          break;
      }
    });
  }

  List<Map<String, dynamic>> get _filteredReceipts {
    var filtered = _allReceipts.where((receipt) {
      // Filter by status
      if (_filterStatus != 'All' && receipt['status'] != _filterStatus) {
        return false;
      }

      // Filter by type
      if (_filterType != 'All' && receipt['orderType'] != _filterType) {
        return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final orderId = receipt['orderId']?.toString().toLowerCase() ?? '';
        final userName = receipt['userName']?.toString().toLowerCase() ?? '';
        final userEmail = receipt['userEmail']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        if (!orderId.contains(query) &&
            !userName.contains(query) &&
            !userEmail.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    return filtered;
  }

  Future<void> _updateReceiptStatus(String receiptId, String newStatus) async {
    try {
      final databases = Databases(widget.account.client);

      await databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.ordersId,
        documentId: receiptId,
        data: {
          'status': newStatus,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      // Update local data
      setState(() {
        final index =
            _allReceipts.indexWhere((receipt) => receipt['\$id'] == receiptId);
        if (index != -1) {
          _allReceipts[index]['status'] = newStatus;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating receipt status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update receipt status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteReceipt(String receiptId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Receipt'),
        content: Text(
            'Are you sure you want to delete this receipt? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final databases = Databases(widget.account.client);

      await databases.deleteDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.ordersId,
        documentId: receiptId,
      );

      // Remove from local data
      setState(() {
        _allReceipts.removeWhere((receipt) => receipt['\$id'] == receiptId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting receipt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete receipt'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStatusUpdateDialog(Map<String, dynamic> receipt) {
    final currentStatus = receipt['status'] ?? 'Pending';
    
    // Ensure the current status is one of the valid options
    String selectedStatus = currentStatus;
    
    // If current status is not in valid list, default to 'Pending'
    if (!_validStatuses.contains(currentStatus)) {
      selectedStatus = 'Pending';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update Order Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order #${receipt['orderId']}'),
              SizedBox(height: 16),
              Text('Current Status: $currentStatus'),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'New Status',
                  border: OutlineInputBorder(),
                ),
                value: selectedStatus,
                items: _validStatuses.map((status) => 
                  DropdownMenuItem(
                    value: status, 
                    child: Text(status)
                  )
                ).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedStatus = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedStatus != currentStatus
                  ? () {
                      Navigator.pop(context);
                      _updateReceiptStatus(receipt['\$id'], selectedStatus);
                    }
                  : null,
              child: Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'success': // Handle the SUCCESS status from payment
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _normalizeStatus(String status) {
    // Convert non-standard statuses to standard ones
    switch (status.toLowerCase()) {
      case 'success':
        return 'Payed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt Management'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchAllReceipts,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _allReceipts.isEmpty
                  ? _buildEmptyView()
                  : _buildReceiptsList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
            onPressed: _fetchAllReceipts,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No receipts found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Customer receipts will appear here',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsList() {
    final filteredList = _filteredReceipts;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Order ID, Customer Name, or Email',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Filter and sort controls
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Status filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _filterStatus,
                  items: [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    ..._validStatuses.map((status) => 
                      DropdownMenuItem(value: status, child: Text(status))
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value!;
                    });
                  },
                ),
              ),
              SizedBox(width: 8),

              // Type filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _filterType,
                  items: [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Delivery', child: Text('Delivery')),
                    DropdownMenuItem(value: 'Reservation', child: Text('Reservation')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterType = value!;
                    });
                  },
                ),
              ),
              SizedBox(width: 8),

              // Sort dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Sort',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _sortBy,
                  items: [
                    DropdownMenuItem(value: 'Date (Newest)', child: Text('Newest')),
                    DropdownMenuItem(value: 'Date (Oldest)', child: Text('Oldest')),
                    DropdownMenuItem(value: 'Total (High)', child: Text('High')),
                    DropdownMenuItem(value: 'Total (Low)', child: Text('Low')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                      _sortReceipts();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        // Results count
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Showing ${filteredList.length} of ${_allReceipts.length} receipt${filteredList.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Receipts list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: filteredList.length,
            itemBuilder: (context, index) {
              final receipt = filteredList[index];
              return _buildReceiptCard(receipt);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final formatter = DateFormat('MMM dd, yyyy hh:mm a');
    final orderDate =
        DateTime.parse(receipt['orderDate'] ?? DateTime.now().toString());
    final formattedDate = formatter.format(orderDate);

    final isReservation = receipt['orderType'] == 'Reservation';
    final rawStatus = receipt['status'] ?? 'Pending';
    final status = _normalizeStatus(rawStatus);
    final total = receipt['total'] ?? 0.0;

    // Determine status color
    final statusColor = _getStatusColor(status);

    // Parse items count
    int itemsCount = 0;
    try {
      if (receipt['items'] is String) {
        final itemsList = jsonDecode(receipt['items']) as List;
        itemsCount = itemsList.length;
      } else if (receipt['items'] is List) {
        itemsCount = (receipt['items'] as List).length;
      }
    } catch (e) {
      print('Error parsing items: $e');
      itemsCount = 0;
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptDetailPage(
                receipt: receipt,
                account: widget.account,
                user: widget.user,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${receipt['orderId']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Customer: ${receipt['userName'] ?? 'N/A'}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Order details row
              Row(
                children: [
                  Icon(
                    isReservation ? Icons.restaurant : Icons.delivery_dining,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 4),
                  Text(
                    isReservation ? 'Reservation' : 'Delivery',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Payment info
              if (receipt['paymentMethod'] != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.payment,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${receipt['paymentMethod']}${receipt['momoProvider'] != null && receipt['momoProvider'].isNotEmpty ? ' (${receipt['momoProvider']})' : ''}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      if (receipt['paymentStatus'] != null) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: receipt['paymentStatus'] == 'Completed' 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            receipt['paymentStatus'],
                            style: TextStyle(
                              color: receipt['paymentStatus'] == 'Completed' 
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              
              // Items and total row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$itemsCount item${itemsCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '${total.toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showStatusUpdateDialog(receipt),
                      icon: Icon(Icons.edit, size: 16),
                      label: Text('Update Status'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade600,
                        side: BorderSide(color: Colors.blue.shade300),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteReceipt(receipt['\$id']),
                      icon: Icon(Icons.delete, size: 16),
                      label: Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}