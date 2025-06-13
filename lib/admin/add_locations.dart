import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:meal/env/app_config.dart';
import 'package:meal/addons/curved_app_bar.dart';

class AddLocationPage extends StatefulWidget {
  final Account account;
  final models.User user;

  const AddLocationPage({
    super.key,
    required this.account,
    required this.user,
  });

  @override
  _AddLocationPageState createState() => _AddLocationPageState();
}

class _AddLocationPageState extends State<AddLocationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  
  // Form controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  
  // Form values
  bool _isDefault = false;
  
  // Existing locations count for validation
  int _existingLocationsCount = 0;
  bool _hasDefaultLocation = false;

  @override
  void initState() {
    super.initState();
    _checkExistingLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingLocations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final databases = Databases(widget.account.client);
      
      // Get existing locations to check if there's already a default
      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.locationsCollectionId,
      );

      setState(() {
        _existingLocationsCount = response.documents.length;
        _hasDefaultLocation = response.documents.any((doc) => doc.data['isDefault'] == true);
        
        // If no locations exist, make this the default
        if (_existingLocationsCount == 0) {
          _isDefault = true;
        }
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking existing locations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final databases = Databases(widget.account.client);
      
      // If this location is being set as default, update existing default location
      if (_isDefault && _hasDefaultLocation) {
        await _updateExistingDefaultLocation();
      }
      
      // Create the new location
      final locationData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'deliveryFee': double.parse(_deliveryFeeController.text.trim()),
        'isDefault': _isDefault,
      };

      await databases.createDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.locationsCollectionId,
        documentId: ID.unique(),
        data: locationData,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back
      Navigator.pop(context, true); // Return true to indicate success
      
    } catch (e) {
      print('Error saving location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add location: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _updateExistingDefaultLocation() async {
    try {
      final databases = Databases(widget.account.client);
      
      // Find the current default location
      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.locationsCollectionId,
        queries: [Query.equal('isDefault', true)],
      );

      // Update existing default location to not be default
      for (var doc in response.documents) {
        await databases.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.locationsCollectionId,
          documentId: doc.$id,
          data: {'isDefault': false},
        );
      }
    } catch (e) {
      print('Error updating existing default location: $e');
      rethrow;
    }
  }

  Widget _buildLocationStats() {
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
              icon: Icons.location_on,
              label: 'Existing',
              value: _existingLocationsCount.toString(),
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatItem(
              icon: Icons.star,
              label: 'Default',
              value: _hasDefaultLocation ? 'Yes' : 'None',
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatItem(
              icon: Icons.add_location,
              label: 'Adding',
              value: 'New',
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
            title: 'Add Location',
            subtitle: 'Create a new delivery/pickup location',
            gradientColors: [
              Colors.green.shade400,
              Colors.green.shade600,
              Colors.green.shade800,
            ],
            expandedHeight: 200,
            flexibleContent: _buildLocationStats(),
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
                        Text('Loading location information...'),
                      ],
                    ),
                  ),
                )
              : SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Location Information Card
                          _buildSectionTitle('Location Information'),
                          _buildLocationInfoCard(),
                          const SizedBox(height: 24),

                          // Delivery Settings Card
                          _buildSectionTitle('Delivery Settings'),
                          _buildDeliverySettingsCard(),
                          const SizedBox(height: 24),

                          // Default Location Setting
                          _buildSectionTitle('Location Priority'),
                          _buildDefaultLocationCard(),
                          const SizedBox(height: 32),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSaving
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Saving Location...'),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.save),
                                        SizedBox(width: 8),
                                        Text(
                                          'SAVE LOCATION',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.green.shade700,
        ),
      ),
    );
  }

  Widget _buildLocationInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Basic Information',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Location Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Location Name *',
                hintText: 'e.g., Downtown Office, Main Branch',
                prefixIcon: Icon(Icons.business, color: Colors.green.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.green.shade600),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a location name';
                }
                if (value.trim().length < 3) {
                  return 'Location name must be at least 3 characters';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            
            // Address
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Full Address *',
                hintText: 'Enter complete address with landmarks',
                prefixIcon: Icon(Icons.location_city, color: Colors.green.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.green.shade600),
                ),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the address';
                }
                if (value.trim().length < 10) {
                  return 'Please enter a more detailed address';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.delivery_dining,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Delivery Configuration',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Delivery Fee
            TextFormField(
              controller: _deliveryFeeController,
              decoration: InputDecoration(
                labelText: 'Delivery Fee (Frs) *',
                hintText: 'Enter delivery fee amount',
                prefixIcon: Icon(Icons.attach_money, color: Colors.green.shade600),
                suffixText: 'Frs',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.green.shade600),
                ),
                helperText: 'Set to 0 for free delivery to this location',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the delivery fee';
                }
                final fee = double.tryParse(value.trim());
                if (fee == null) {
                  return 'Please enter a valid number';
                }
                if (fee < 0) {
                  return 'Delivery fee cannot be negative';
                }
                if (fee > 10000) {
                  return 'Delivery fee seems too high';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            
            // Fee Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This fee will be added to orders delivered to this location',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultLocationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Default Location Setting',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Default Location Switch
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDefault ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isDefault ? Colors.green.shade200 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isDefault ? Icons.star : Icons.star_border,
                    color: _isDefault ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set as Default Location',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _isDefault ? Colors.green.shade800 : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isDefault 
                              ? 'This will be the default location for new orders'
                              : 'Make this the default location for customers',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isDefault,
                    onChanged: _existingLocationsCount == 0 
                        ? null // Disable if this is the first location
                        : (value) {
                            setState(() {
                              _isDefault = value;
                            });
                          },
                    activeColor: Colors.green.shade600,
                  ),
                ],
              ),
            ),
            
            // Information about default location
            const SizedBox(height: 12),
            if (_existingLocationsCount == 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will be set as default since it\'s your first location',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_hasDefaultLocation && _isDefault)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: Colors.amber.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will replace the current default location',
                        style: TextStyle(
                          color: Colors.amber.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
