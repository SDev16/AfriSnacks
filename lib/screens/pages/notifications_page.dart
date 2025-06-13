import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:meal/env/app_config.dart';
import 'package:meal/services/local_notification_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class UserNotificationsPage extends StatefulWidget {
  final Account account;
  final models.User user;
  final Client client;

  const UserNotificationsPage({
    super.key,
    required this.account,
    required this.user,
    required this.client,
  });

  @override
  _UserNotificationsPageState createState() => _UserNotificationsPageState();
}

class _UserNotificationsPageState extends State<UserNotificationsPage>
    with SingleTickerProviderStateMixin {
  late Databases _databases;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  List<models.Document> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _unreadCount = 0;
  String _selectedFilter = 'all'; // all, unread, read

  @override
  void initState() {
    super.initState();
    _databases = Databases(widget.client);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadNotifications();
    
    // Initialize local notifications
    LocalNotificationService.initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get user registration date
      final userRegistrationDate = DateTime.parse(widget.user.$createdAt);
      
      print('User registered at: $userRegistrationDate');
      
      // Load notifications created after user registration
      final allNotifications = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.notificationId,
        queries: [
          Query.orderDesc('\$createdAt'),
          Query.greaterThanEqual('\$createdAt', userRegistrationDate.toIso8601String()),
          Query.limit(100),
        ],
      );

      print('Found ${allNotifications.documents.length} notifications after user registration');

      // Get deleted notifications for this user
      final deletedNotifications = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.deleteNotificationsId,
        queries: [
          Query.equal('userId', widget.user.$id),
        ],
      );

      // Create a set of deleted notification IDs for quick lookup
      final deletedNotificationIds = deletedNotifications.documents
          .map((doc) => doc.data['notificationId'] as String)
          .toSet();

      // Filter out deleted notifications
      final visibleNotifications = allNotifications.documents
          .where((notification) => !deletedNotificationIds.contains(notification.$id))
          .toList();

      // Count unread notifications for this user
      int unreadCount = 0;
      for (final notif in visibleNotifications) {
        final isRead = await _isNotificationRead(notif.$id);
        if (!isRead) unreadCount++;
      }

      setState(() {
        _notifications = visibleNotifications;
        _unreadCount = unreadCount;
        _isLoading = false;
      });

      _animationController.forward();

      print('Loaded ${visibleNotifications.length} visible notifications for user');
      print('Unread count: $unreadCount');

    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _errorMessage = 'Failed to load notifications: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<bool> _isNotificationRead(String notificationId) async {
    try {
      final readStatus = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.readNotificationId,
        queries: [
          Query.equal('userId', widget.user.$id),
          Query.equal('notificationId', notificationId),
        ],
      );
      return readStatus.documents.isNotEmpty;
    } catch (e) {
      print('Error checking read status: $e');
      return false;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      // Check if already marked as read
      final isRead = await _isNotificationRead(notificationId);
      if (isRead) return;

      // Create read status record
      await _databases.createDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.readNotificationId,
        documentId: ID.unique(),
        data: {
          'userId': widget.user.$id,
          'notificationId': notificationId,
          'readAt': DateTime.now().toIso8601String(),
        },
      );

      // Update local state
      setState(() {
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      });

      print('Marked notification $notificationId as read');

    } catch (e) {
      print('Error marking as read: $e');
      _showSnackBar('Failed to mark as read', isError: true);
    }
  }

  Future<void> _deleteNotificationForUser(String notificationId) async {
    try {
      // Check if already deleted
      final existingDeleted = await _databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.deleteNotificationsId,
        queries: [
          Query.equal('userId', widget.user.$id),
          Query.equal('notificationId', notificationId),
        ],
      );

      if (existingDeleted.documents.isNotEmpty) {
        print('Notification already marked as deleted');
        return;
      }

      // Create a deleted status record for this user
      await _databases.createDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.deleteNotificationsId,
        documentId: ID.unique(),
        data: {
          'userId': widget.user.$id,
          'notificationId': notificationId,
          'deletedAt': DateTime.now().toIso8601String(),
        },
      );

      // Update local state immediately
      setState(() {
        final index = _notifications.indexWhere((n) => n.$id == notificationId);
        if (index != -1) {
          // Check if it was unread before removing
          _isNotificationRead(notificationId).then((isRead) {
            if (!isRead && _unreadCount > 0) {
              setState(() {
                _unreadCount = _unreadCount - 1;
              });
            }
          });
          _notifications.removeAt(index);
        }
      });

      print('Deleted notification $notificationId for user');
      _showSnackBar('Notification removed');

    } catch (e) {
      print('Error deleting notification: $e');
      _showSnackBar('Failed to remove notification', isError: true);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final unreadNotifications = <String>[];
      
      // Find all unread notifications
      for (final notification in _notifications) {
        final isRead = await _isNotificationRead(notification.$id);
        if (!isRead) {
          unreadNotifications.add(notification.$id);
        }
      }

      // Mark all unread notifications as read
      for (final notificationId in unreadNotifications) {
        await _databases.createDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.readNotificationId,
          documentId: ID.unique(),
          data: {
            'userId': widget.user.$id,
            'notificationId': notificationId,
            'readAt': DateTime.now().toIso8601String(),
          },
        );
      }

      // Update local state
      setState(() {
        _unreadCount = 0;
      });

      print('Marked ${unreadNotifications.length} notifications as read');
      _showSnackBar('All notifications marked as read');

    } catch (e) {
      print('Error marking all as read: $e');
      _showSnackBar('Failed to mark all as read', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<models.Document> get _filteredNotifications {
    switch (_selectedFilter) {
      case 'unread':
        return _notifications.where((notification) {
          // This is a simplified check - in a real app you'd cache read status
          return true; // You'd need to implement proper filtering
        }).toList();
      case 'read':
        return _notifications.where((notification) {
          // This is a simplified check - in a real app you'd cache read status
          return true; // You'd need to implement proper filtering
        }).toList();
      default:
        return _notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Curved App Bar
          SliverAppBar(
            expandedHeight: 70,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  if (_unreadCount > 0)
                    Text(
                      '$_unreadCount unread',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade400,
                      Colors.blue.shade600,
                      Colors.blue.shade800,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    // Curved bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (_unreadCount > 0)
                IconButton(
                  icon: const Icon(Icons.done_all_rounded),
                  onPressed: _markAllAsRead,
                  tooltip: 'Mark all as read',
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadNotifications,
                tooltip: 'Refresh',
              ),
            ],
          ),

          // Filter Chips
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Unread', 'unread'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Read', 'read'),
                ],
              ),
            ),
          ),

          // Content
          _buildSliverBody(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSliverBody() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading notifications...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 48,
                  color: Colors.blue.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ll see notifications here when they become available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final notification = _filteredNotifications[index];
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    index * 0.1,
                    1.0,
                    curve: Curves.easeOutCubic,
                  ),
                )),
                child: FutureBuilder<bool>(
                  future: _isNotificationRead(notification.$id),
                  builder: (context, snapshot) {
                    final isRead = snapshot.data ?? false;
                    return _buildNotificationCard(notification, isRead, index);
                  },
                ),
              ),
            );
          },
          childCount: _filteredNotifications.length,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(models.Document notification, bool isRead, int index) {
    final title = notification.data['title'] ?? 'Notification';
    final body = notification.data['body'] ?? '';
    final sentBy = notification.data['sentBy'] ?? 'System';
    final type = notification.data['type'] ?? 'general';
    final createdAt = DateTime.parse(notification.$createdAt);
    final timeAgo = timeago.format(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: isRead 
            ? null 
            : Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!isRead) {
              _markAsRead(notification.$id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Type indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTypeColor(type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getTypeColor(type),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: Colors.grey.shade400,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'read':
                            if (!isRead) {
                              _markAsRead(notification.$id);
                            }
                            break;
                          case 'delete':
                            _showDeleteConfirmation(notification.$id);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (!isRead)
                          const PopupMenuItem(
                            value: 'read',
                            child: Row(
                              children: [
                                Icon(Icons.mark_email_read_rounded),
                                SizedBox(width: 8),
                                Text('Mark as read'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Remove', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                    color: isRead ? Colors.grey.shade700 : Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    color: isRead ? Colors.grey.shade500 : Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'By $sentBy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'promotion':
        return Colors.orange;
      case 'order_update':
        return Colors.green;
      case 'system':
        return Colors.red;
      case 'announcement':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  void _showDeleteConfirmation(String notificationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Notification'),
        content: const Text('Are you sure you want to remove this notification from your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNotificationForUser(notificationId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}