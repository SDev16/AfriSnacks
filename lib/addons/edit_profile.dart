import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:meal/env/app_config.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfilePage extends StatefulWidget {
  final Account account;
  final models.User user;
  final Map<String, dynamic>? profileData;

  const EditProfilePage({
    super.key,
    required this.account,
    required this.user,
    this.profileData,
  });

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool isLoading = false;
  bool isUpdatingImage = false;
  File? _imageFile;
  String? _currentImageUrl;
  String? _oldImageFileId; // Store the old image file ID for deletion
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // Prioritize database data over account data for name
    if (widget.profileData != null && widget.profileData!.containsKey('name') && widget.profileData!['name'] != null) {
      _nameController.text = widget.profileData!['name'];
    } else {
      _nameController.text = widget.user.name;
    }
    
    // Prioritize database data over account data for email
    if (widget.profileData != null && widget.profileData!.containsKey('email') && widget.profileData!['email'] != null) {
      _emailController.text = widget.profileData!['email'];
    } else {
      _emailController.text = widget.user.email;
    }
    
    if (widget.profileData != null) {
      _phoneController.text = widget.profileData!['phone'] ?? '';
      _currentImageUrl = widget.profileData!['profile_image'];
      
      // Extract file ID from the current image URL for deletion
      if (_currentImageUrl != null) {
        _oldImageFileId = _extractFileIdFromUrl(_currentImageUrl!);
      }
    }
  }

  // Helper method to extract file ID from Appwrite storage URL
  String? _extractFileIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final filesIndex = pathSegments.indexOf('files');
      if (filesIndex != -1 && filesIndex + 1 < pathSegments.length) {
        return pathSegments[filesIndex + 1];
      }
    } catch (e) {
      print('Error extracting file ID from URL: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
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

  Future<void> _deleteOldImage() async {
    if (_oldImageFileId == null) return;
    
    try {
      final storage = Storage(widget.account.client);
      await storage.deleteFile(
        bucketId: AppConfig.bucketId,
        fileId: _oldImageFileId!,
      );
      print('Old image deleted successfully: $_oldImageFileId');
    } catch (e) {
      print('Error deleting old image: $e');
      // Don't throw error here as it shouldn't prevent the new image upload
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_imageFile == null) return _currentImageUrl;
    
    try {
      setState(() {
        isUpdatingImage = true;
      });
      
      final storage = Storage(widget.account.client);
      
      // Delete old image first if it exists
      if (_oldImageFileId != null) {
        await _deleteOldImage();
      }
      
      // Upload new file to storage
      final fileName = '${widget.user.$id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadResult = await storage.createFile(
        bucketId: AppConfig.bucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(
          path: _imageFile!.path,
          filename: fileName,
        ),
      );
      
      // Construct the file URL manually
      final endpoint = widget.account.client.endPoint;
      final projectId = widget.account.client.config['project'];
      final bucketId = AppConfig.bucketId;
      final fileId = uploadResult.$id;
      
      final newImageUrl = '$endpoint/storage/buckets/$bucketId/files/$fileId/view?project=$projectId';
      
      // Update the old image file ID for future deletions
      _oldImageFileId = fileId;
      
      return newImageUrl;
    } catch (e) {
      throw Exception('Failed to upload image: ${e.toString()}');
    } finally {
      setState(() {
        isUpdatingImage = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Upload image if changed
      String? imageUrl = await _uploadProfileImage();
      
      final databases = Databases(widget.account.client);
      
      // Check if profile document exists
      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.databaseCollectionId,
        queries: [
          Query.equal('user_id', widget.user.$id),
        ],
      );
      
      // Include name and email in the database profile data
      final profileData = {
        'user_id': widget.user.$id,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'profile_image': imageUrl,
      };
      
      if (response.documents.isNotEmpty) {
        // Update existing profile
        await databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.databaseCollectionId,
          documentId: response.documents.first.$id,
          data: profileData,
        );
      } else {
        // Create new profile document
        await databases.createDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.databaseCollectionId,
          documentId: ID.unique(),
          data: profileData,
        );
      }
      
      // Update account name if changed (for Appwrite account consistency)
      if (_nameController.text.trim() != widget.user.name) {
        try {
          await widget.account.updateName(name: _nameController.text.trim());
        } catch (e) {
          // Log the error but don't fail the entire update
          print('Warning: Could not update account name: ${e.toString()}');
        }
      }
      
      // Update email if changed (this will require email verification)
      if (_emailController.text.trim() != widget.user.email) {
        try {
          await widget.account.updateEmail(
            email: _emailController.text.trim(),
            password: '', // You might want to ask for password confirmation
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email update requires verification. Please check your email.'),
              backgroundColor: Colors.orange,
            ),
          );
        } catch (e) {
          // Log the error but don't fail the entire update
          print('Warning: Could not update account email: ${e.toString()}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile updated, but email change failed. Please try again later.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Return updated data to previous screen
      Navigator.of(context).pop({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'profile_image': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: isLoading ? null : _updateProfile,
            child: Text(
              'Save',
              style: TextStyle(
                color: isLoading ? Colors.grey : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Image Section
              GestureDetector(
                onTap: isUpdatingImage ? null : _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: _imageFile != null 
                          ? FileImage(_imageFile!) 
                          : null,
                      child: _imageFile == null
                          ? (_currentImageUrl != null)
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: _currentImageUrl!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => CircularProgressIndicator(),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              )
                            : Text(
                                _nameController.text.isNotEmpty 
                                    ? _nameController.text[0].toUpperCase() 
                                    : '?',
                                style: TextStyle(fontSize: 40, color: Colors.blue.shade800),
                              )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    if (isUpdatingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tap to change photo',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 32),
              
              // Form Fields
              _buildFormSection(
                title: 'Personal Information',
                children: [
                  _buildTextFormField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        if (!RegExp(r'^\+?[\d\s\-()]+$').hasMatch(value)) {
                          return 'Please enter a valid phone number';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
              
              SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Cancel Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}