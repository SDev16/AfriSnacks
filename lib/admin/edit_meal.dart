import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:meal/models/category.dart';
import 'package:meal/models/meals.dart';
import 'package:meal/env/app_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:meal/env/app_constants.dart';

class EditMealPage extends StatefulWidget {
  final Client client;
  final Meal? meal; // null for new meal, non-null for editing

  const EditMealPage({
    super.key,
    required this.client,
    this.meal,
  });

  @override
  _EditMealPageState createState() => _EditMealPageState();
}

class _EditMealPageState extends State<EditMealPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedCategory = '';
  List<Category> _categories = [];
  bool _isFeatured = false;
  double _rating = 0.0;
  
  File? _imageFile;
  String? _currentImageUrl;
  String? _currentFileId;
  bool _isLoading = false;
  bool _isLoadingCategories = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    
    // If editing an existing meal, populate the form
    if (widget.meal != null) {
      _nameController.text = widget.meal!.name;
      _priceController.text = widget.meal!.price.toString();
      _descriptionController.text = widget.meal!.description;
      _selectedCategory = widget.meal!.category;
      _isFeatured = widget.meal!.isFeatured;
      _rating = widget.meal!.rating;
      _currentImageUrl = widget.meal!.imageUrl;
      _currentFileId = widget.meal!.fileId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
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
        _categories = fetchedCategories;
        _isLoadingCategories = false;
        
        // If no category is selected and we have categories, select the first one
        if (_selectedCategory.isEmpty && _categories.isNotEmpty) {
          _selectedCategory = _categories.first.name;
        }
      });
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() {
        _isLoadingCategories = false;
        _errorMessage = 'Failed to load categories: ${e.toString()}';
      });
    }
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

  Future<void> _saveMeal() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_imageFile == null && _currentFileId == null) {
      setState(() {
        _errorMessage = 'Please select an image for the meal';
      });
      return;
    }

    if (_selectedCategory.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a category';
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
        if (widget.meal != null && _currentFileId != null) {
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
        final fileName = 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      
      // Parse price - convert to integer (cents)
      int priceInCents = 0;
      try {
        // Parse as double first, then convert to cents (integer)
        double priceValue = double.parse(_priceController.text);
        priceInCents = (priceValue * 100).round(); // Convert to cents
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid price format';
        });
        return;
      }
      
      // Prepare meal data
      final mealData = {
        'name': _nameController.text.trim(),
        'price': priceInCents, // Store as integer (cents)
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'fileId': fileId, // Store file ID instead of full URL
        'bucketId': AppConfig.bucketId, // Store bucket ID for reference
        'isFeatured': _isFeatured,
        'rating': _rating.round(), // Store as integer if needed
      };
      
      // If we have a file ID, also store the full image URL for backward compatibility
      if (fileId != null) {
        // Construct the file URL manually
        final endpoint = widget.client.endPoint;
        final bucketId = AppConfig.bucketId;
        
        // Create a direct URL to the file
        final imageUrl = '$endpoint/storage/buckets/$bucketId/files/$fileId/view?project=${AppConstants.projectId}';
        mealData['imageUrl'] = imageUrl;
      }
      
      if (widget.meal == null) {
        // Create new meal
        await databases.createDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.mealsCollectionId,
          documentId: ID.unique(),
          data: mealData,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meal created successfully')),
        );
      } else {
        // Update existing meal
        await databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.mealsCollectionId,
          documentId: widget.meal!.id,
          data: mealData,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meal updated successfully')),
        );
      }
      
      // Return to previous screen with success result
      Navigator.of(context).pop(true);
    } catch (e) {
      print('Error saving meal: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save meal: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewMeal = widget.meal == null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewMeal ? 'Add Meal' : 'Edit Meal'),
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
              
              // Meal image
              Text(
                'Meal Image',
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
              SizedBox(height: 24),
              
              // Meal name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Meal Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a meal name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Price
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                  helperText: 'Enter price in dollars (e.g., 12.99)',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a price';
                  }
                  try {
                    double.parse(value);
                  } catch (e) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Category dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                value: _selectedCategory.isNotEmpty ? _selectedCategory : null,
                hint: Text('Select a category'),
                isExpanded: true,
                items: _isLoadingCategories
                    ? []
                    : _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.name,
                          child: Text(category.name),
                        );
                      }).toList(),
                onChanged: _isLoadingCategories
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              if (_isLoadingCategories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Rating
              Text(
                'Rating: ${_rating.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                value: _rating,
                min: 0,
                max: 5,
                divisions: 10,
                label: _rating.toStringAsFixed(1),
                onChanged: (value) {
                  setState(() {
                    _rating = value;
                  });
                },
              ),
              SizedBox(height: 16),
              
              // Featured checkbox
              CheckboxListTile(
                title: Text('Featured Meal'),
                subtitle: Text('Show this meal on the home page'),
                value: _isFeatured,
                onChanged: (value) {
                  setState(() {
                    _isFeatured = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              SizedBox(height: 32),
              
              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMeal,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isNewMeal ? 'Create Meal' : 'Update Meal',
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
