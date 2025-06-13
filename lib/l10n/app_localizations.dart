import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Locale;
import 'package:flutter/widgets.dart' as widgets show Locale;
import 'package:intl/intl.dart';

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// Use Flutter's Locale explicitly
typedef FlutterLocale = widgets.Locale;

abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = Intl.canonicalizedLocale(locale);

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // Common strings
  String get appTitle;
  String get welcome;
  String get welcomeBack;
  String get discoverMeals;
  String get notifications;
  String get receipts;
  String get categories;
  String get featuredMeals;
  String get noFeaturedMeals;
  String get noCategories;
  String get profile;
  String get settings;
  String get logout;
  String get language;
  String get english;
  String get french;
  String get accountInformation;
  String get name;
  String get email;
  String get phone;
  String get verifiedOn;
  String get preferences;
  String get admin;
  String get adminDashboard;
  String get account;
  String get editProfile;
  String get helpAndSupport;
  String get appVersion;
  String get shop;
  String get browseAllProducts;
  String get categoryPrefix;
  String get products;
  String get inCart;
  String get noMealsFound;
  String get imageNotAvailable;
  String get retry;
  String get errorFetchingCategories;
  String get errorFetchingMeals;
  String get manageAccount;
  String get getHome;
  String get getShop;
  String get getWhishlist;
  String get getMore;
  // Product details specific strings
  String get description;
  String get quantity;
  String get total;
  String get addToCart;
  String get viewCart;
  String get addedToCart;
  String get failedToAddToCart;
  String get addedToWishlist;
  String get removedFromWishlist;
  String get pleaseLoginForWishlist;
  String get login;

  // Admin/Management specific strings
  String get searchMeals;
  String get all;
  String get deleteMeal;
  String get deleteMealConfirmation;
  String get cancel;
  String get delete;
  String get mealDeletedSuccessfully;
  String get failedToDeleteMeal;
  String get removedFromFeatured;
  String get addedToFeatured;
  String get failedToUpdateFeaturedStatus;
  String get noMealsFoundAddFirst;
  String get addMeal;
  String get edit;
  String get removeFromFeatured;
  String get addToFeatured;
  String get featured;
  String get translated;
  String get partialTranslation;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(FlutterLocale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(FlutterLocale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(FlutterLocale locale) {
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue on GitHub with a '
    'reproducible sample app and the gen-l10n configuration that was used.'
  );
}
