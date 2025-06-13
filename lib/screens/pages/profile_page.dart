import 'package:double_back_to_close/double_back_to_close.dart';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meal/addons/edit_profile.dart';
import 'package:meal/admin/admin_page.dart';
import 'package:meal/l10n/app_localizations.dart';
import 'package:meal/l10n/language_selector.dart';
import 'package:meal/screens/pages/help_center.dart';
import 'dart:io';
import 'package:meal/env/app_config.dart';
import 'package:meal/screens/login_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:meal/addons/curved_app_bar.dart';

class ProfilePage extends StatefulWidget {
  final Account account;
  final models.User user;
  final Map<String, dynamic>? profileData;

  const ProfilePage({
    super.key,
    required this.account,
    required this.user,
    this.profileData,
  });

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = false;
  bool isLoadingProfile = false;
  Map<String, dynamic>? userProfile;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    if (widget.profileData == null) {
      _fetchUserProfile();
    } else {
      userProfile = widget.profileData;
    }
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      isLoadingProfile = true;
    });

    try {
      final databases = Databases(widget.account.client);

      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.databaseCollectionId,
        queries: [
          Query.equal('user_id', widget.user.$id),
        ],
      );

      if (response.documents.isNotEmpty) {
        setState(() {
          userProfile = response.documents.first.data;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching profile: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoadingProfile = false;
      });
    }
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
      await _updateProfileImage();
    }
  }

  Future<void> _updateProfileImage() async {
    if (_imageFile == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final storage = Storage(widget.account.client);
      final databases = Databases(widget.account.client);

      final fileName =
          '${widget.user.$id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadResult = await storage.createFile(
        bucketId: AppConfig.bucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(
          path: _imageFile!.path,
          filename: fileName,
        ),
      );

      final endpoint = widget.account.client.endPoint;
      final projectId = widget.account.client.config['project'];
      final bucketId = AppConfig.bucketId;
      final fileId = uploadResult.$id;

      final imageUrl =
          '$endpoint/storage/buckets/$bucketId/files/$fileId/view?project=$projectId';

      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.databaseCollectionId,
        queries: [
          Query.equal('user_id', widget.user.$id),
        ],
      );

      if (response.documents.isNotEmpty) {
        final documentId = response.documents.first.$id;

        await databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.databaseCollectionId,
          documentId: documentId,
          data: {
            'profile_image': imageUrl,
          },
        );

        setState(() {
          if (userProfile != null) {
            userProfile!['profile_image'] = imageUrl;
          } else {
            userProfile = {
              'profile_image': imageUrl,
            };
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile picture updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error updating profile picture: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> logout() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Use the improved signOutGoogle method from AuthHelper
      // Create an instance of AuthHelper if you don't have it already
      final authHelper = AuthHelper();
      
      // This handles both Google and Appwrite logout with proper error handling
      await authHelper.signOutGoogle();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                DoubleBack(child: LoginPage(account: widget.account)),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // This should rarely happen now with our improved error handling
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during logout: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String get displayName {
    if (userProfile != null && 
        userProfile!.containsKey('name') && 
        userProfile!['name'] != null && 
        userProfile!['name'].toString().isNotEmpty) {
      return userProfile!['name'];
    }
    return widget.user.name;
  }

  String get displayEmail {
    if (userProfile != null && 
        userProfile!.containsKey('email') && 
        userProfile!['email'] != null && 
        userProfile!['email'].toString().isNotEmpty) {
      return userProfile!['email'];
    }
    return widget.user.email;
  }

  void _showFullScreenImage() {
    if (userProfile != null && 
        userProfile!.containsKey('profile_image') && 
        userProfile!['profile_image'] != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenImageViewer(
            imageUrl: userProfile!['profile_image'],
            heroTag: 'profile_image',
          ),
        ),
      );
    }
  }

  Widget _buildProfileHeader() {
    final localizations = AppLocalizations.of(context);
    
    return Positioned(
      bottom: 40,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            // Profile Image
            GestureDetector(
              onTap: (userProfile != null && 
                      userProfile!.containsKey('profile_image') && 
                      userProfile!['profile_image'] != null) 
                  ? _showFullScreenImage 
                  : _pickImage,
              child: Hero(
                tag: 'profile_image',
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : null,
                      child: _imageFile == null
                          ? (userProfile != null &&
                                  userProfile!.containsKey('profile_image') &&
                                  userProfile!['profile_image'] != null &&
                                  userProfile!['profile_image'] is String)
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: userProfile!['profile_image'],
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        CircularProgressIndicator(color: Colors.white),
                                    errorWidget: (context, url, error) =>
                                        Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      fontSize: 36,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                )
                          : null,
                    ),
                    Positioned(
                      bottom: 30,
                      right: 30,
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: Icon(
                          (userProfile != null && 
                                  userProfile!.containsKey('profile_image') && 
                                  userProfile!['profile_image'] != null) 
                              ? Icons.visibility 
                              : Iconsax.camera,
                          color: Colors.blue,
                          size: 16,
                        ),
                      ),
                    ),
                    if (isLoading)
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
            ),
            SizedBox(height: 16),
            Text(
              displayName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              displayEmail,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Curved App Bar
          CurvedAppBar(
            title: localizations.profile,
            subtitle: localizations.manageAccount,
            gradientColors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
              Colors.blue.shade800,
            ],
            expandedHeight: 280,
            flexibleContent: _buildProfileHeader(),
            showBackButton: false,
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (isLoadingProfile)
                  Center(child: CircularProgressIndicator())
                else ...[
                  SizedBox(height: 16),

                  // Account Information
                  _buildSection(
                    title: localizations.accountInformation,
                    children: [
                      _buildInfoItem(
                        icon: Iconsax.people,
                        title: localizations.name,
                        value: displayName,
                      ),
                      _buildInfoItem(
                        icon: Iconsax.box,
                        title: localizations.email,
                        value: displayEmail,
                      ),
                      if (userProfile != null &&
                          userProfile!.containsKey('phone'))
                        _buildInfoItem(
                          icon: Iconsax.call,
                          title: localizations.phone,
                          value: userProfile!['phone'],
                        ),
                      _buildInfoItem(
                        icon: Iconsax.verify,
                        title: localizations.verifiedOn,
                        value: 'AfriSnacks',
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Preferences
                  _buildSection(
                    title: localizations.preferences,
                    children: [
                      _buildSettingItem(
                        icon: Iconsax.notification,
                        title: localizations.notifications,
                        trailing: Switch(
                          value: true,
                          onChanged: (value) {},
                          activeColor: Colors.blue,
                        ),
                      ),
                      _buildSettingItem(
                        icon: Iconsax.language_circle,
                        title: localizations.language,
                        trailing: Text(
                          Localizations.localeOf(context).languageCode == 'en' 
                              ? localizations.english 
                              : localizations.french
                        ),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => Container(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: LanguageSelector(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // // Admin Access
                  // _buildSection(
                  //   title: localizations.admin,
                  //   children: [
                  //     _buildActionItem(
                  //       icon: Iconsax.cpu,
                  //       title: localizations.adminDashboard,
                  //       onTap: () {
                  //         Navigator.push(
                  //           context,
                  //           MaterialPageRoute(
                  //             builder: (context) => AdminPage(
                  //               account: widget.account,
                  //               user: widget.user,
                  //               client: widget.account.client,
                  //             ),
                  //           ),
                  //         );
                  //       },
                  //     ),
                  //   ],
                  // ),

                  // Account Actions
                  _buildSection(
                    title: localizations.account,
                    children: [
                      _buildActionItem(
                        icon: Icons.edit,
                        title: localizations.editProfile,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfilePage(
                                account: widget.account,
                                user: widget.user,
                                profileData: userProfile,
                              ),
                            ),
                          );

                          if (result != null && result is Map<String, dynamic>) {
                            setState(() {
                              if (userProfile != null) {
                                userProfile!.addAll(result);
                              } else {
                                userProfile = result;
                              }
                            });
                          }
                        },
                      ),
                      _buildActionItem(
                        icon: Iconsax.hospital,
                        title: localizations.helpAndSupport,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => HelpCenterPage()));
                        },
                      ),
                      _buildActionItem(
                        icon: Iconsax.logout,
                        title: localizations.logout,
                        onTap: logout,
                        isDestructive: true,
                      ),
                    ],
                  ),

                  SizedBox(height: 32),

                  Text(
                    localizations.appVersion,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
      required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoItem(
      {required IconData icon, required String title, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.blue,
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Colors.blue,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? Colors.red : Colors.blue,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isDestructive ? Colors.red : null,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// Full Screen Image Viewer Widget
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => CircularProgressIndicator(
                color: Colors.white,
              ),
              errorWidget: (context, url, error) => Icon(
                Icons.error,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
