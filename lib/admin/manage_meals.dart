import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:meal/admin/edit_meal.dart';
import 'package:meal/l10n/app_localizations.dart';
import 'package:meal/models/meals.dart';
import 'package:meal/env/app_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:meal/provider/language_provider.dart';
import 'package:provider/provider.dart';

class ManageMealsPage extends StatefulWidget {
  final Account account;
  final models.User user;
  final Client client;

  const ManageMealsPage({
    super.key,
    required this.account,
    required this.user,
    required this.client,
  });

  @override
  _ManageMealsPageState createState() => _ManageMealsPageState();
}

class _ManageMealsPageState extends State<ManageMealsPage> {
  bool isLoading = false;
  List<Meal> meals = [];
  String? errorMessage;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchMeals();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final databases = Databases(widget.client);
      
      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.categoriesCollectionId,
      );

      final categories = response.documents
          .map((doc) => doc.data['name'] as String)
          .toList();

      setState(() {
        _categories = ['All', ...categories];
      });
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  Future<void> _fetchMeals() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final databases = Databases(widget.client);
      
      List<String> queries = [];
      
      // Add search query if provided
      if (_searchQuery.isNotEmpty) {
        queries.add(Query.search('name', _searchQuery));
      }
      
      // Add category filter if selected
      if (_selectedCategory != 'All') {
        queries.add(Query.equal('category', _selectedCategory));
      }
      
      final response = await databases.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.mealsCollectionId,
        queries: queries,
      );

      final fetchedMeals = response.documents
          .map((doc) => Meal.fromJson({...doc.data, '\$id': doc.$id}))
          .toList();

      setState(() {
        meals = fetchedMeals;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching meals: $e');
      final localizations = AppLocalizations.of(context);
      setState(() {
        errorMessage = '${localizations.errorFetchingMeals}: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _deleteMeal(Meal meal) async {
    final localizations = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final currentLanguage = languageProvider.currentLocale.languageCode;
    final displayName = meal.getLocalizedName(currentLanguage);
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentLanguage == 'fr' ? 'Supprimer le plat' : 'Delete Meal'),
        content: Text(currentLanguage == 'fr' 
            ? 'Êtes-vous sûr de vouloir supprimer "$displayName"? Cette action ne peut pas être annulée.'
            : 'Are you sure you want to delete "$displayName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(currentLanguage == 'fr' ? 'Annuler' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(currentLanguage == 'fr' ? 'Supprimer' : 'Delete'),
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
      
      // Delete the meal from the database
      await databases.deleteDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.mealsCollectionId,
        documentId: meal.id,
      );

      // If the meal has a fileId, delete it from storage
      if (meal.fileId != null) {
        try {
          final storage = Storage(widget.client);
          await storage.deleteFile(
            bucketId: meal.bucketId ?? AppConfig.bucketId,
            fileId: meal.fileId!,
          );
        } catch (e) {
          print('Error deleting image: $e');
          // Continue even if image deletion fails
        }
      }

      // Refresh the list
      await _fetchMeals();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(currentLanguage == 'fr' 
            ? 'Plat supprimé avec succès' 
            : 'Meal deleted successfully')),
      );
    } catch (e) {
      print('Error deleting meal: $e');
      setState(() {
        isLoading = false;
        errorMessage = currentLanguage == 'fr' 
            ? 'Échec de la suppression du plat: ${e.toString()}'
            : 'Failed to delete meal: ${e.toString()}';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentLanguage == 'fr' 
              ? 'Échec de la suppression du plat: ${e.toString()}'
              : 'Failed to delete meal: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleFeatured(Meal meal) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final currentLanguage = languageProvider.currentLocale.languageCode;
    final displayName = meal.getLocalizedName(currentLanguage);
    
    try {
      final databases = Databases(widget.client);
      
      await databases.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.mealsCollectionId,
        documentId: meal.id,
        data: {
          'isFeatured': !meal.isFeatured,
        },
      );
      
      // Refresh the list
      await _fetchMeals();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            meal.isFeatured
                ? (currentLanguage == 'fr' 
                    ? '$displayName retiré des plats en vedette'
                    : '$displayName removed from featured')
                : (currentLanguage == 'fr' 
                    ? '$displayName ajouté aux plats en vedette'
                    : '$displayName added to featured'),
          ),
        ),
      );
    } catch (e) {
      print('Error toggling featured status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentLanguage == 'fr' 
              ? 'Échec de la mise à jour du statut en vedette: ${e.toString()}'
              : 'Failed to update featured status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLocale.languageCode;
    
    return Scaffold(
      body: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: currentLanguage == 'fr' 
                        ? 'Rechercher des plats...' 
                        : 'Search meals...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  onSubmitted: (_) => _fetchMeals(),
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(category == 'All' 
                              ? (currentLanguage == 'fr' ? 'Tous' : 'All')
                              : category),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                              _fetchMeals();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Meals list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchMeals,
              child: isLoading && meals.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : errorMessage != null && meals.isEmpty
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
                                  onPressed: _fetchMeals,
                                  child: Text(localizations.retry),
                                ),
                              ],
                            ),
                          ),
                        )
                      : meals.isEmpty
                          ? Center(
                              child: Text(currentLanguage == 'fr' 
                                  ? 'Aucun plat trouvé. Ajoutez votre premier plat!'
                                  : 'No meals found. Add your first meal!'),
                            )
                          : ListView.builder(
                              itemCount: meals.length,
                              padding: EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final meal = meals[index];
                                return _buildMealItem(meal, currentLanguage);
                              },
                            ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditMealPage(
                client: widget.client,
                meal: null, // null means we're creating a new meal
              ),
            ),
          );
          
          if (result == true) {
            await _fetchMeals();
          }
        },
        tooltip: currentLanguage == 'fr' ? 'Ajouter un plat' : 'Add Meal',
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildMealItem(Meal meal, String currentLanguage) {
    final displayName = meal.getLocalizedName(currentLanguage);
    final displayDescription = meal.getLocalizedDescription(currentLanguage);
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: meal.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade300,
                  child: Icon(
                    Icons.image,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName, // Use localized name
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      // Show both English and French names for admin reference
                      if (currentLanguage == 'fr' && meal.name != displayName)
                        Text(
                          '(EN: ${meal.name})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      if (currentLanguage == 'en' && meal.nameFr.isNotEmpty)
                        Text(
                          '(FR: ${meal.nameFr})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (meal.isFeatured)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        SizedBox(width: 4),
                        Text(
                          currentLanguage == 'fr' ? 'En vedette' : 'Featured',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  '${meal.price.toStringAsFixed(0)} Frs',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    meal.category,
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                // Translation status indicator
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: meal.nameFr.isNotEmpty && meal.descriptionFr.isNotEmpty
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        meal.nameFr.isNotEmpty && meal.descriptionFr.isNotEmpty
                            ? (currentLanguage == 'fr' ? 'Traduit' : 'Translated')
                            : (currentLanguage == 'fr' ? 'Traduction partielle' : 'Partial Translation'),
                        style: TextStyle(
                          color: meal.nameFr.isNotEmpty && meal.descriptionFr.isNotEmpty
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    meal.isFeatured ? Icons.star : Icons.star_border,
                    color: meal.isFeatured ? Colors.amber : null,
                  ),
                  tooltip: meal.isFeatured 
                      ? (currentLanguage == 'fr' ? 'Retirer des plats en vedette' : 'Remove from featured')
                      : (currentLanguage == 'fr' ? 'Ajouter aux plats en vedette' : 'Add to featured'),
                  onPressed: () => _toggleFeatured(meal),
                ),
                IconButton(
                  icon: Icon(Icons.edit),
                  tooltip: currentLanguage == 'fr' ? 'Modifier' : 'Edit',
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditMealPage(
                          client: widget.client,
                          meal: meal,
                        ),
                      ),
                    );
                    
                    if (result == true) {
                      await _fetchMeals();
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  tooltip: currentLanguage == 'fr' ? 'Supprimer' : 'Delete',
                  onPressed: () => _deleteMeal(meal),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayDescription, // Use localized description
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Show translation status for descriptions
                if (currentLanguage == 'en' && meal.descriptionFr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'FR: ${meal.descriptionFr}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (currentLanguage == 'fr' && meal.description != displayDescription)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'EN: ${meal.description}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
