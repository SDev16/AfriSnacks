import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:meal/addons/curved_app_bar.dart';
import 'package:meal/screens/pages/receipt_detailed_page.dart';
import 'package:meal/env/app_config.dart';
import 'package:intl/intl.dart';

class ReceiptsManagementPage extends StatefulWidget {
  final Account account;
  final models.User user;

  const ReceiptsManagementPage({
    super.key,
    required this.account,
    required this.user,
  });

  @override
  _ReceiptsManagementPageState createState() => _ReceiptsManagementPageState();
}

class _ReceiptsManagementPageState extends State<ReceiptsManagementPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _receipts = [];
  String? _errorMessage;

  // Filtering
  String _filterType = 'All'; // 'All', 'Delivery', 'Reservation'

  // Sorting
  String _sortBy =
      'Date (Newest)'; // 'Date (Newest)', 'Date (Oldest)', 'Total (High)', 'Total (Low)'

  @override
  void initState() {
    super.initState();
    _fetchReceipts();
  }

  Future<void> _fetchReceipts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final databases = Databases(widget.account.client);

      // Fetch orders for the current user
      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId:
            AppConfig.ordersId, // Make sure you have an 'orders' collection
        queries: [
          Query.equal('userId', widget.user.$id),
        ],
      );

      final fetchedReceipts = response.documents
          .map((doc) => {...doc.data, '\$id': doc.$id})
          .toList();

      setState(() {
        _receipts = fetchedReceipts;
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
          _receipts.sort((a, b) {
            final dateA = DateTime.parse(a['orderDate'] ?? '');
            final dateB = DateTime.parse(b['orderDate'] ?? '');
            return dateB.compareTo(dateA);
          });
          break;
        case 'Date (Oldest)':
          _receipts.sort((a, b) {
            final dateA = DateTime.parse(a['orderDate'] ?? '');
            final dateB = DateTime.parse(b['orderDate'] ?? '');
            return dateA.compareTo(dateB);
          });
          break;
        case 'Total (High)':
          _receipts.sort((a, b) {
            final totalA = a['total'] ?? 0.0;
            final totalB = b['total'] ?? 0.0;
            return totalB.compareTo(totalA);
          });
          break;
        case 'Total (Low)':
          _receipts.sort((a, b) {
            final totalA = a['total'] ?? 0.0;
            final totalB = b['total'] ?? 0.0;
            return totalA.compareTo(totalB);
          });
          break;
      }
    });
  }

  List<Map<String, dynamic>> get _filteredReceipts {
    if (_filterType == 'All') {
      return _receipts;
    }

    return _receipts
        .where((receipt) => receipt['orderType'] == _filterType)
        .toList();
  }

  Widget _buildReceiptStats() {
    final totalReceipts = _receipts.length;
    final pendingCount = _receipts.where((r) => r['status'] == 'Pending').length;
    final completedCount = _receipts.where((r) => r['status'] == 'Completed').length;
    final totalSpent = _receipts.fold<double>(0.0, (sum, r) => sum + (r['total'] ?? 0.0));

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
              icon: Icons.receipt_long_rounded,
              label: 'Total',
              value: totalReceipts.toString(),
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatItem(
              icon: Icons.pending_rounded,
              label: 'Pending',
              value: pendingCount.toString(),
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatItem(
              icon: Icons.check_circle_rounded,
              label: 'Completed',
              value: completedCount.toString(),
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatItem(
              icon: Icons.attach_money_rounded,
              label: 'Spent',
              value: totalSpent.toStringAsFixed(0),
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
            title: 'My Receipts',
            subtitle: _receipts.isNotEmpty 
                ? '${_receipts.length} order${_receipts.length != 1 ? 's' : ''} found'
                : null,
            gradientColors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
              Colors.blue.shade800,
            ],
            expandedHeight: 200,
            flexibleContent: _receipts.isNotEmpty ? _buildReceiptStats() : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded,color: Colors.white,),
                onPressed: _fetchReceipts,
                tooltip: 'Refresh',
              ),
            ],
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
                        Text('Loading receipts...'),
                      ],
                    ),
                  ),
                )
              : _errorMessage != null
                  ? SliverFillRemaining(child: _buildErrorView())
                  : _receipts.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyView())
                      : _buildReceiptsList(),
        ],
      ),
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
            onPressed: _fetchReceipts,
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long,
              size: 48,
              color: Colors.indigo.shade400,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No receipts found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your order receipts will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.shopping_bag_rounded),
            label: const Text('Start Shopping'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
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

  Widget _buildReceiptsList() {
    final filteredList = _filteredReceipts;

    return SliverToBoxAdapter(
      child: Column(
        children: [
          // Filter and sort controls
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Filter dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Filter',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _filterType,
                    items: [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(
                          value: 'Delivery', child: Text('Delivery')),
                      DropdownMenuItem(
                          value: 'Reservation', child: Text('Reservation')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterType = value!;
                      });
                    },
                  ),
                ),
                SizedBox(width: 12),

                // Sort dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Sort By',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _sortBy,
                    items: [
                      DropdownMenuItem(
                          value: 'Date (Newest)', child: Text('Date (Newest)')),
                      DropdownMenuItem(
                          value: 'Date (Oldest)', child: Text('Date (Oldest)')),
                      DropdownMenuItem(
                          value: 'Total (High)', child: Text('Total (High)')),
                      DropdownMenuItem(
                          value: 'Total (Low)', child: Text('Total (Low)')),
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

          // Results count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Showing ${filteredList.length} receipt${filteredList.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Receipts list
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(8),
            itemCount: filteredList.length,
            itemBuilder: (context, index) {
              final receipt = filteredList[index];
              return _buildReceiptCard(receipt);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final formatter = DateFormat('MMM dd, yyyy');
    final orderDate =
        DateTime.parse(receipt['orderDate'] ?? DateTime.now().toString());
    final formattedDate = formatter.format(orderDate);

    final isReservation = receipt['orderType'] == 'Reservation';
    final status = receipt['status'] ?? 'Pending';
    final total = receipt['total'] ?? 0.0;

    // Determine status color
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'processing':
        statusColor = Colors.blue;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Order #${receipt['orderId']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
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
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isReservation 
                          ? Colors.blue.shade50 
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isReservation ? Icons.restaurant : Icons.delivery_dining,
                      size: 16,
                      color: isReservation 
                          ? Colors.blue.shade600 
                          : Colors.blue.shade600,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    isReservation ? 'Reservation' : 'Delivery',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (isReservation && receipt['reservationDate'] != null) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.orange.shade600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _formatReservationDateTime(receipt['reservationDate'],
                          receipt['reservationTime']),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Tap to view details',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${total.toStringAsFixed(0)} Frs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo.shade700,
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

  String _formatReservationDateTime(String? dateString, String? timeString) {
    if (dateString == null) return 'N/A';

    try {
      final date = DateTime.parse(dateString);
      final formattedDate = DateFormat('MMM dd').format(date);

      if (timeString == null) return formattedDate;

      // Handle time in format "HH:MM"
      final parts = timeString.split(':');
      if (parts.length == 2) {
        try {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          final time = TimeOfDay(hour: hour, minute: minute);

          final period = time.period == DayPeriod.am ? 'AM' : 'PM';
          final hourIn12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
          return '$formattedDate, $hourIn12:${time.minute.toString().padLeft(2, '0')} $period';
        } catch (e) {
          return '$formattedDate, $timeString';
        }
      }

      return '$formattedDate, $timeString';
    } catch (e) {
      return 'N/A';
    }
  }
}