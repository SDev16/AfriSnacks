import 'package:flutter/material.dart';
import 'package:meal/provider/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:meal/l10n/app_localizations.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            localizations.language,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        RadioListTile<String>(
          title: Text(localizations.english),
          value: 'en',
          groupValue: languageProvider.currentLocale.languageCode,
          onChanged: (value) {
            if (value != null) {
              languageProvider.changeLanguage(value);
            }
          },
        ),
        RadioListTile<String>(
          title: Text(localizations.french),
          value: 'fr',
          groupValue: languageProvider.currentLocale.languageCode,
          onChanged: (value) {
            if (value != null) {
              languageProvider.changeLanguage(value);
            }
          },
        ),
      ],
    );
  }
}
