import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class VoiceConfig {
  final String version;
  final DefaultConfig defaultConfig;
  final Map<String, LanguageConfig> languages;
  
  VoiceConfig({
    required this.version,
    required this.defaultConfig,
    required this.languages,
  });
  
  factory VoiceConfig.fromJson(Map<String, dynamic> json) {
    final languagesMap = <String, LanguageConfig>{};
    final languages = json['languages'] as Map<String, dynamic>;
    
    languages.forEach((key, value) {
      languagesMap[key] = LanguageConfig.fromJson(value);
    });
    
    return VoiceConfig(
      version: json['version'].toString(),
      defaultConfig: DefaultConfig.fromJson(json['default']),
      languages: languagesMap,
    );
  }
}

class DefaultConfig {
  final String xmlLang;
  final String rate;
  final String pitch;
  final String style;
  final Map<String, String> model;
  final FlutterTtsConfig flutterTts;
  
  DefaultConfig({
    required this.xmlLang,
    required this.rate,
    required this.pitch,
    required this.style,
    required this.model,
    required this.flutterTts,
  });
  
  factory DefaultConfig.fromJson(Map<String, dynamic> json) {
    return DefaultConfig(
      xmlLang: json['xmlLang'],
      rate: json['rate'],
      pitch: json['pitch'],
      style: json['style'],
      model: Map<String, String>.from(json['model']),
      flutterTts: FlutterTtsConfig.fromJson(json['flutterTts']),
    );
  }
}

class LanguageConfig {
  final String xmlLang;
  final List<AgeRule> ageRules;
  
  LanguageConfig({
    required this.xmlLang,
    required this.ageRules,
  });
  
  factory LanguageConfig.fromJson(Map<String, dynamic> json) {
    return LanguageConfig(
      xmlLang: json['xmlLang'],
      ageRules: (json['ageRules'] as List)
          .map((e) => AgeRule.fromJson(e))
          .toList(),
    );
  }
  
  AgeRule? getAgeRule(int age) {
    for (var rule in ageRules) {
      if (age <= rule.max) {
        return rule;
      }
    }
    return ageRules.isNotEmpty ? ageRules.last : null;
  }
}

class AgeRule {
  final int max;
  final String rate;
  final String pitch;
  final String style;
  final Map<String, String> model;
  final FlutterTtsConfig flutterTts;
  
  AgeRule({
    required this.max,
    required this.rate,
    required this.pitch,
    required this.style,
    required this.model,
    required this.flutterTts,
  });
  
  factory AgeRule.fromJson(Map<String, dynamic> json) {
    return AgeRule(
      max: json['max'],
      rate: json['rate'],
      pitch: json['pitch'],
      style: json['style'],
      model: Map<String, String>.from(json['model']),
      flutterTts: FlutterTtsConfig.fromJson(json['flutterTts']),
    );
  }
}

class FlutterTtsConfig {
  final double rate;
  final double pitch;
  final int? pauseMs;
  
  FlutterTtsConfig({
    required this.rate,
    required this.pitch,
    this.pauseMs,
  });
  
  factory FlutterTtsConfig.fromJson(Map<String, dynamic> json) {
    return FlutterTtsConfig(
      rate: (json['rate'] as num).toDouble(),
      pitch: (json['pitch'] as num).toDouble(),
      pauseMs: json['pauseMs'],
    );
  }
}

extension VoiceConfigLoader on VoiceConfig {
  static Future<VoiceConfig> loadFromAsset() async {
    final jsonStr = await rootBundle.loadString('assets/voice_config.json');
    final jsonData = json.decode(jsonStr);
    return VoiceConfig.fromJson(jsonData);
  }
}
