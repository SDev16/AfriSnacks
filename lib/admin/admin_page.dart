import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:meal/admin/add_locations.dart';
import 'package:meal/admin/add_notifications.dart';
import 'package:meal/admin/manage_category.dart';
import 'package:meal/admin/manage_meals.dart';
import 'package:meal/admin/reciepts_management.dart';

class AdminPage extends StatefulWidget {
  final Account account;
  final models.User user;
  final Client client;

  const AdminPage({
    super.key,
    required this.account,
    required this.user,
    required this.client,
  });

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Meals', icon: Icon(Icons.restaurant)),
            Tab(text: 'Categories', icon: Icon(Icons.category)),
            Tab(text: 'Receipts', icon: Icon(Icons.receipt_long)),
            Tab(text: 'Notif', icon: Icon(Icons.notifications)),
            Tab(text: 'Loc', icon: Icon(Icons.local_activity)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ManageMealsPage(
            account: widget.account,
            user: widget.user,
            client: widget.client,
          ),
          ManageCategoriesPage(
            account: widget.account,
            user: widget.user,
            client: widget.client,
          ),
          AdminReceiptsManagement(
            account: widget.account,
            user: widget.user,
            client: widget.client,
          ),
          AddNotificationPage(
              account: widget.account,
              user: widget.user,
              client: widget.client),
          // AdminPushNotificationsFinal(
          //   account: widget.account,
          //   user: widget.user,
          //   client: widget.client,
          // ),
          AddLocationPage(account: widget.account, user: widget.user)
        ],
      ),
    );
  }
}
