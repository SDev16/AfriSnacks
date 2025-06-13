// ignore_for_file: unused_local_variable

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
// ignore: unused_import
import 'package:appwrite/models.dart' as models;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:meal/addons/main_screen.dart';
import 'package:meal/env/app_config.dart';

class RegisterPage extends StatefulWidget {
  final Account account;

  const RegisterPage({super.key, required this.account});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

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

  Future<void> register(
      String email, String password, String name, String phone) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Create the user account
      final user = await widget.account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );

      // Create a session (log in)
      await widget.account.createEmailPasswordSession(
        email: email,
        password: password,
      );

      // Get the user details
      final loggedInUser = await widget.account.get();


      // Create storage and database clients
      final storage = Storage(widget.account.client);
      final databases = Databases(widget.account.client);

      // Profile data to store
      Map<String, dynamic> profileData = {
        'user_id': loggedInUser.$id,
        'name': name,
        'email': email,
        'phone': phone,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Upload profile picture if selected
      if (_imageFile != null) {
        final fileName =
            '${loggedInUser.$id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Upload file to storage
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

        // Create a direct URL to the file
        final imageUrl =
            '$endpoint/storage/buckets/$bucketId/files/$fileId/view?project=$projectId';

        // Add image URL to profile data
        profileData['profile_image'] = imageUrl;
      }

      // Store user profile in database
      final document = await databases.createDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.databaseCollectionId,
        documentId: ID.unique(),
        data: profileData,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainScreen(
              account: widget.account,
              user: loggedInUser,
              profileData: profileData,
            ),
          ),
          (route) =>
              false, // This predicate ensures all previous routes are removed
        );
      }
      final fcmToken = await FirebaseMessaging.instance.getToken();
      await widget.account.createPushTarget(
          targetId: ID.unique(),
          identifier: fcmToken!,
          providerId: AppConfig.fcmId);
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('Sign Up'),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),

                  // Profile Image Picker
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : null,
                            child: _imageFile == null
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey.shade800,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(4),
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
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  if (errorMessage != null)
                    Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () => register(
                              emailController.text,
                              passwordController.text,
                              nameController.text,
                              phoneController.text,
                            ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                    ),
                    child: isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Sign Up',style: TextStyle(color: Colors.white),),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Already have an account? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
