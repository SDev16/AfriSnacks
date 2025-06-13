import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import 'package:meal/admin/edit_category.dart';
import 'package:meal/models/category.dart';

import 'package:meal/env/app_config.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ManageCategoriesPage extends StatefulWidget {
  final Account account;
  final models.User user;
  final Client client;

  const ManageCategoriesPage({
    super.key,
    required this.account,
    required this.user,
    required this.client,
  });

  @override
  _ManageCategoriesPageState createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  bool isLoading = false;
  List<Category> categories = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final databases = Databases(widget.client);
      
      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.categoriesCollectionId,
      );

      final fetchedCategories = response.documents
          .map((doc) => Category.fromJson({...doc.data, '\$id': doc.$id}))
          .toList();

      setState(() {
        categories = fetchedCategories;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() {
        errorMessage = 'Failed to load categories: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _deleteCategory(Category category) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      isLoading = true;
    });

    try {
      final databases = Databases(widget.client);
      
      // Delete the category from the database
      await databases.deleteDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.categoriesCollectionId,
        documentId: category.id,
      );

      // If the category has an image, delete it from storage
      if (category.imageUrl.isNotEmpty) {
        try {
          // Extract the file ID from the URL
          final uri = Uri.parse(category.imageUrl);
          final pathSegments = uri.pathSegments;
          final fileId = pathSegments[pathSegments.length - 2];
          
          final storage = Storage(widget.client);
          await storage.deleteFile(
            bucketId: AppConfig.bucketId,
            fileId: fileId,
          );
        } catch (e) {
          print('Error deleting image: $e');
          // Continue even if image deletion fails
        }
      }

      // Refresh the list
      await _fetchCategories();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category deleted successfully')),
      );
    } catch (e) {
      print('Error deleting category: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to delete category: ${e.toString()}';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete category: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchCategories,
        child: isLoading && categories.isEmpty
            ? Center(child: CircularProgressIndicator())
            : errorMessage != null && categories.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchCategories,
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : categories.isEmpty
                    ? Center(
                        child: Text('No categories found. Add your first category!'),
                      )
                    : ListView.builder(
                        itemCount: categories.length,
                        padding: EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return _buildCategoryItem(category);
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditCategoryPage(
                client: widget.client,
                category: null, // null means we're creating a new category
              ),
            ),
          );
          
          if (result == true) {
            await _fetchCategories();
          }
        },
        tooltip: 'Add Category',
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryItem(Category category) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: category.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 60,
              height: 60,
              color: Colors.grey.shade200,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 60,
              height: 60,
              color: Colors.grey.shade300,
              child: Icon(
                Icons.image,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
        title: Text(
          category.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditCategoryPage(
                      client: widget.client,
                      category: category,
                    ),
                  ),
                );
                
                if (result == true) {
                  await _fetchCategories();
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteCategory(category),
            ),
          ],
        ),
      ),
    );
  }
}
