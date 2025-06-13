import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:meal/models/category.dart';
import 'package:meal/env/app_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:meal/env/app_constants.dart'; // Import AppConstants

class EditCategoryPage extends StatefulWidget {
  final Client client;
  final Category? category; // null for new category, non-null for editing

  const EditCategoryPage({
    super.key,
    required this.client,
    this.category,
  });

  @override
  _EditCategoryPageState createState() => _EditCategoryPageState();
}

class _EditCategoryPageState extends State<EditCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  File? _imageFile;
  String? _currentImageUrl;
  String? _currentFileId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // If editing an existing category, populate the form
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _currentImageUrl = widget.category!.imageUrl;
      
      // Extract file ID from the URL if possible
      if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
        try {
          final uri = Uri.parse(_currentImageUrl!);
          final pathSegments = uri.pathSegments;
          _currentFileId = pathSegments[pathSegments.length - 2];
        } catch (e) {
          print('Error extracting file ID: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_imageFile == null && _currentFileId == null) {
      setState(() {
        _errorMessage = 'Please select an image for the category';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final databases = Databases(widget.client);
      final storage = Storage(widget.client);
      
      // Handle image upload and file ID management
      String? fileId = _currentFileId;
      
      if (_imageFile != null) {
        // If we're updating and there's an existing image, delete it
        if (widget.category != null && _currentFileId != null) {
          try {
            await storage.deleteFile(
              bucketId: AppConfig.bucketId,
              fileId: _currentFileId!,
            );
          } catch (e) {
            print('Error deleting old image: $e');
            // Continue even if deletion fails
          }
        }
        
        // Upload the new image
        final fileName = 'category_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadResult = await storage.createFile(
          bucketId: AppConfig.bucketId,
          fileId: ID.unique(),
          file: InputFile.fromPath(
            path: _imageFile!.path,
            filename: fileName,
          ),
        );
        
        // Store the file ID
        fileId = uploadResult.$id;
      }
      
      // Prepare category data
      final categoryData = {
        'name': _nameController.text.trim(),
        'fileId': fileId, // Store file ID instead of full URL
        'bucketId': AppConfig.bucketId, // Store bucket ID for reference
      };
      
      // If we have a file ID, also store the full image URL for backward compatibility
      if (fileId != null) {
        // Construct the file URL with the correct project ID
        final endpoint = widget.client.endPoint;
        final bucketId = AppConfig.bucketId;
        
        // Create a direct URL to the file
        final imageUrl = '$endpoint/storage/buckets/$bucketId/files/$fileId/view?project=${AppConstants.projectId}';
        categoryData['imageUrl'] = imageUrl;
      }
      
      if (widget.category == null) {
        // Create new category
        await databases.createDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.categoriesCollectionId,
          documentId: ID.unique(),
          data: categoryData,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category created successfully')),
        );
      } else {
        // Update existing category
        await databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.categoriesCollectionId,
          documentId: widget.category!.id,
          data: categoryData,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category updated successfully')),
        );
      }
      
      // Return to previous screen with success result
      Navigator.of(context).pop(true);
    } catch (e) {
      print('Error saving category: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save category: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewCategory = widget.category == null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewCategory ? 'Add Category' : 'Edit Category'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(8),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              
              // Category name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              
              // Category image
              Text(
                'Category Image',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: _isLoading ? null : _pickImage,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _imageFile!,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          )
                        : _currentImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: _currentImageUrl!,
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 80,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate,
                                      size: 80,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Tap to select image',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                  ),
                ),
              ),
              SizedBox(height: 32),
              
              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCategory,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isNewCategory ? 'Create Category' : 'Update Category',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
