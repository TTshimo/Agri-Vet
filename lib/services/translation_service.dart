import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english('en', 'English', '🇬🇧'),
  setswana('tn', 'Setswana', '🇧🇼'),
  swahili('sw', 'Kiswahili', '🇰🇪'),
  portuguese('pt', 'Português', '🇦🇴');

  final String code;
  final String label;
  final String flag;
  const AppLanguage(this.code, this.label, this.flag);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.english,
    );
  }

  static AppLanguage fromLocale(Locale locale) {
    final lang = locale.languageCode;
    switch (lang) {
      case 'tn':
        return AppLanguage.setswana;
      case 'sw':
        return AppLanguage.swahili;
      case 'pt':
        return AppLanguage.portuguese;
      default:
        return AppLanguage.english;
    }
  }
}

class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  AppLanguage _language = AppLanguage.english;
  Map<String, dynamic> _setswanaStrings = {};
  bool _loaded = false;

  AppLanguage get language => _language;
  bool get isSetswana => _language == AppLanguage.setswana;

  Future<void> init() async {
    if (_loaded) return;

    final raw = await rootBundle
        .loadString('assets/translation/setswana.json');
    _setswanaStrings = json.decode(raw) as Map<String, dynamic>;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language');

    if (saved != null) {
      _language = AppLanguage.fromCode(saved);
    } else {
      // Auto-detect from device locale
      final locale = PlatformDispatcher.instance.locale;
      _language = AppLanguage.fromLocale(locale);
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang.code);
    notifyListeners();
  }

  // Getters
  String get(String key) {
    if (_language != AppLanguage.setswana) return _englishFallback(key);
    return _getSetswana(key) ?? _englishFallback(key);
  }

  /// Get disease info in current language
  Map<String, String> getDiseaseInfo(String diseaseKey) {
    switch (_language) {
      case AppLanguage.setswana:
        return _getSetswanaDiseaseInfo(diseaseKey);
      case AppLanguage.swahili:
        return _getSwahiliDiseaseInfo(diseaseKey);
      case AppLanguage.portuguese:
        return _getPortugueseDiseaseInfo(diseaseKey);
      default:
        return _getEnglishDiseaseInfo(diseaseKey);
    }
  }

  // Setswana lookup 
  String? _getSetswana(String key) {
    final parts = key.split('.');
    dynamic current = _setswanaStrings;
    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current?.toString();
  }

  Map<String, String> _getSetswanaDiseaseInfo(String diseaseKey) {
    final diseases =
        _setswanaStrings['diseases'] as Map<String, dynamic>? ?? {};
    final disease =
        diseases[diseaseKey.toLowerCase()] as Map<String, dynamic>? ?? {};
    return {
      'display_name': disease['display_name']?.toString() ??
          _getEnglishDiseaseInfo(diseaseKey)['display_name'] ?? diseaseKey,
      'affects': disease['affects']?.toString() ?? '',
      'spreads_by': disease['spreads_by']?.toString() ?? '',
      'urgency': disease['urgency']?.toString() ?? '',
      'what_to_do': disease['what_to_do']?.toString() ?? '',
      'symptoms': disease['symptoms']?.toString() ?? '',
      'prevention': disease['prevention']?.toString() ?? '',
    };
  }

  // Swahili disease info
  Map<String, String> _getSwahiliDiseaseInfo(String diseaseKey) {
    final swahiliDiseases = <String, Map<String, String>>{
      'foot and mouth': {
        'display_name': 'Ugonjwa wa Miguu na Mdomo',
        'affects': 'Ng\'ombe, mbuzi, kondoo',
        'spreads_by': 'Mawasiliano ya moja kwa moja, nyuso zilizochafuliwa',
        'urgency': 'Tenga mara moja',
        'what_to_do':
            'Tenga wanyama walioathirika mara moja. Wasiliana na daktari wa mifugo au ofisi ya DVS. Usisogeze wanyama kutoka shambani.',
        'symptoms':
            'Malengelenge kwenye kwato, mdomo na ulimi. Mate mengi, udhaifu, kupungua uzalishaji wa maziwa.',
        'prevention':
            'Chanjo, punguza harakati za wanyama, hatua za usalama wa kibiolojia.',
      },
      'lumpy cow disease': {
        'display_name': 'Ugonjwa wa Uvimbe wa Ngozi ya Ng\'ombe',
        'affects': 'Ng\'ombe',
        'spreads_by': 'Kuumwa na wadudu, mawasiliano ya moja kwa moja',
        'urgency': 'Tibu na fuatilia',
        'what_to_do':
            'Tenga wanyama walioathirika. Wasiliana na daktari wa mifugo. Chanjo mifugo iliyosalia.',
        'symptoms':
            'Uvimbe wa ngozi mwilini, homa, kutokwa na kamasi, kupungua uzalishaji wa maziwa.',
        'prevention': 'Chanjo ya kila mwaka, kudhibiti wadudu.',
      },
      'watermelon mosaic virus': {
        'display_name': 'Virusi vya Mosaic ya Tikiti',
        'affects': 'Tikiti, matango, boga',
        'spreads_by': 'Wadudu aphid, mimea iliyoathirika',
        'urgency': 'Simamia na fuatilia',
        'what_to_do':
            'Ondoa na uharibu mimea iliyoathirika. Dhibiti wadudu aphid kwa dawa ya wadudu.',
        'symptoms':
            'Mosaic ya njano-kijani kwenye majani, matunda yaliyopotoka, ukuaji mdogo.',
        'prevention':
            'Tumia aina zinazostahimili virusi, dhibiti aphid, ondoa magugu.',
      },
    };

    return swahiliDiseases[diseaseKey.toLowerCase()] ??
        _getEnglishDiseaseInfo(diseaseKey);
  }

  // Portuguese disease info
  Map<String, String> _getPortugueseDiseaseInfo(String diseaseKey) {
    final portugueseDiseases = <String, Map<String, String>>{
      'foot and mouth': {
        'display_name': 'Febre Aftosa',
        'affects': 'Bovinos, caprinos, ovinos',
        'spreads_by': 'Contacto directo, superfícies contaminadas',
        'urgency': 'Isolar imediatamente',
        'what_to_do':
            'Isole os animais afectados imediatamente. Contacte o veterinário ou os serviços veterinários. Não mova animais da quinta.',
        'symptoms':
            'Bolhas nos cascos, boca e língua. Salivação excessiva, coxeira, redução da produção de leite.',
        'prevention':
            'Vacinação, restrição de movimentos de animais, medidas de biossegurança.',
      },
      'lumpy cow disease': {
        'display_name': 'Dermatose Nodular Contagiosa',
        'affects': 'Bovinos',
        'spreads_by': 'Picadas de insectos, contacto directo',
        'urgency': 'Tratar e monitorizar',
        'what_to_do':
            'Isole os animais afectados. Contacte um veterinário para tratamento. Vacine o restante do rebanho.',
        'symptoms':
            'Nódulos na pele, febre, corrimento nasal, redução da produção de leite.',
        'prevention': 'Vacinação anual, controlo de insectos.',
      },
      'watermelon mosaic virus': {
        'display_name': 'Vírus do Mosaico da Melancia',
        'affects': 'Melancias, pepinos, abóboras',
        'spreads_by': 'Pulgões, material vegetal infectado',
        'urgency': 'Gerir e monitorizar',
        'what_to_do':
            'Remova e destrua as plantas infectadas. Controle os pulgões com inseticida.',
        'symptoms':
            'Mosaico amarelo-verde nas folhas, fruto deformado, crescimento atrofiado.',
        'prevention':
            'Use variedades resistentes ao vírus, controle pulgões, remova ervas daninhas.',
      },
    };

    return portugueseDiseases[diseaseKey.toLowerCase()] ??
        _getEnglishDiseaseInfo(diseaseKey);
  }

  static Map<String, dynamic> _englishDiseaseData = {};

  static Future<void> loadEnglishDiseaseData() async {
    final raw =
        await rootBundle.loadString('assets/data/disease_info.json');
    _englishDiseaseData = json.decode(raw) as Map<String, dynamic>;
  }

  Map<String, String> _getEnglishDiseaseInfo(String diseaseKey) {
    final disease = _englishDiseaseData[diseaseKey.toLowerCase()]
        as Map<String, dynamic>? ?? {};
    return {
      'display_name': disease['display_name']?.toString() ?? diseaseKey,
      'affects': disease['affects']?.toString() ?? '',
      'spreads_by': disease['spreads_by']?.toString() ?? '',
      'urgency': disease['urgency']?.toString() ?? '',
      'what_to_do': disease['what_to_do']?.toString() ?? '',
      'symptoms': disease['symptoms']?.toString() ?? '',
      'prevention': disease['prevention']?.toString() ?? '',
      'risk_level': disease['risk_level']?.toString() ?? 'none',
    };
  }

  String _englishFallback(String key) {
    const strings = <String, String>{
      'nav.home': 'Home',
      'nav.diagnose': 'Diagnose',
      'nav.community': 'Community',
      'nav.learn': 'Learn',
      'nav.profile': 'Profile',
      'home.attention': 'What needs attention today?',
      'home.run_diagnosis': 'Run a diagnosis',
      'home.animal_diagnosis': 'Animal diagnosis',
      'home.animal_subtitle': 'Cattle, goats, poultry',
      'home.plant_diagnosis': 'Plant diagnosis',
      'home.plant_subtitle': 'Maize, sorghum, watermelon',
      'home.recent_activity': 'Recent activity',
      'home.no_diagnoses': 'No diagnoses yet',
      'home.no_diagnoses_sub':
          'Run your first diagnosis using the buttons above.',
      'diagnosis.upload_prompt':
          'Take a photo or upload from your gallery',
      'diagnosis.upload_tip':
          'Best results: clear lighting, close up of affected area',
      'diagnosis.camera': 'Camera',
      'diagnosis.gallery': 'Gallery',
      'diagnosis.analyse': 'Analyse photo',
      'diagnosis.result_title': 'Diagnosis result',
      'diagnosis.english': 'English',
      'diagnosis.setswana': 'Setswana',
      'diagnosis.confidence': 'confidence',
      'diagnosis.affects': 'Affects',
      'diagnosis.spreads_by': 'Spreads by',
      'diagnosis.urgency': 'Urgency',
      'diagnosis.what_to_do': 'What to do now',
      'diagnosis.symptoms': 'Symptoms',
      'diagnosis.prevention': 'Prevention',
      'diagnosis.risk_high': 'High risk',
      'diagnosis.risk_medium': 'Monitor',
      'diagnosis.risk_none': 'Healthy',
      'diagnosis.urgent': 'Urgent',
      'diagnosis.monitor': 'Monitor',
      'diagnosis.healthy': 'Healthy',
      'community.title': 'Community',
      'community.subtitle': 'Share knowledge with other farmers',
      'community.new_post': 'New post',
      'community.no_posts': 'No posts yet',
      'learn.title': 'Learn',
      'learn.subtitle': 'Stay informed about diseases',
      'learn.animal_diseases': 'Animal diseases',
      'learn.crop_diseases': 'Crop diseases',
      'profile.title': 'Profile',
      'profile.verified_farmer': 'Verified Farmer',
      'profile.diagnoses': 'Diagnoses',
      'profile.posts': 'Posts',
      'profile.crops': 'Crops',
      'profile.farm_details': 'Farm details',
      'profile.farm_name': 'Farm name',
      'profile.location': 'Location',
      'profile.animals_kept': 'Animals kept',
      'profile.settings': 'Settings',
      'settings.title': 'Settings',
      'settings.preferences': 'Preferences',
      'settings.default_language': 'Default language',
      'settings.diagnosis_language': 'Diagnosis output language',
      'settings.dark_mode': 'Dark mode',
      'settings.dark_mode_sub': 'Change app appearance',
      'settings.offline_mode': 'Offline mode',
      'settings.offline_mode_sub': 'Run models without internet',
      'settings.notifications': 'Notifications',
      'settings.disease_alerts': 'Disease alerts',
      'settings.disease_alerts_sub': 'Outbreaks in your region',
      'settings.community_replies': 'Community replies',
      'settings.community_replies_sub': 'When someone replies to your post',
      'settings.account': 'Account',
      'settings.change_password': 'Change password',
      'settings.sign_out': 'Sign out',
      'news.title': 'News',
      'news.subtitle': 'Agricultural updates for Botswana',
      'common.cancel': 'Cancel',
      'common.save': 'Save',
      'common.loading': 'Loading...',
      'common.error': 'Error',
      'common.try_again': 'Try again',
    };
    return strings[key] ?? key;
  }
}

extension TranslationExtension on BuildContext {
  String tr(String key) => TranslationService().get(key);
}