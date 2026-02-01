// lib/providers/csv_settings_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CsvSettings {
  final int lfdNummerSpalte;
  final int nameSpalte;
  final int gewerkSpalte;
  final int? etageSpalte;
  final int? anlageBauteilSpalte;
  final int? parameterSpalte;
  final String delimiterMode;
  final String anlageKuerzel;
  final String bauteilKuerzel;
  final bool useDisciplineGrouping;
  final String labelGewerk;
  final String labelAnlage;
  final String labelBauteil;

  const CsvSettings({
    required this.lfdNummerSpalte,
    required this.nameSpalte,
    required this.gewerkSpalte,
    this.etageSpalte,
    this.anlageBauteilSpalte,
    this.parameterSpalte,
    required this.delimiterMode,
    required this.anlageKuerzel,
    required this.bauteilKuerzel,
    required this.useDisciplineGrouping,
    required this.labelGewerk,
    required this.labelAnlage,
    required this.labelBauteil,
  });

  factory CsvSettings.defaults() {
    return const CsvSettings(
      lfdNummerSpalte: 0,
      nameSpalte: 1,
      gewerkSpalte: 2,
      etageSpalte: null,
      anlageBauteilSpalte: null,
      parameterSpalte: null,
      delimiterMode: 'auto',
      anlageKuerzel: 'A,Anlage',
      bauteilKuerzel: 'B,Bauteil',
      useDisciplineGrouping: true,
      labelGewerk: 'Gewerk',
      labelAnlage: 'Anlage',
      labelBauteil: 'Bauteil',
    );
  }

  CsvSettings copyWith({
    int? lfdNummerSpalte,
    int? nameSpalte,
    int? gewerkSpalte,
    int? etageSpalte,
    int? anlageBauteilSpalte,
    int? parameterSpalte,
    String? delimiterMode,
    String? anlageKuerzel,
    String? bauteilKuerzel,
    bool? useDisciplineGrouping,
    String? labelGewerk,
    String? labelAnlage,
    String? labelBauteil,
  }) {
    return CsvSettings(
      lfdNummerSpalte: lfdNummerSpalte ?? this.lfdNummerSpalte,
      nameSpalte: nameSpalte ?? this.nameSpalte,
      gewerkSpalte: gewerkSpalte ?? this.gewerkSpalte,
      etageSpalte: etageSpalte ?? this.etageSpalte,
      anlageBauteilSpalte: anlageBauteilSpalte ?? this.anlageBauteilSpalte,
      parameterSpalte: parameterSpalte ?? this.parameterSpalte,
      delimiterMode: delimiterMode ?? this.delimiterMode,
      anlageKuerzel: anlageKuerzel ?? this.anlageKuerzel,
      bauteilKuerzel: bauteilKuerzel ?? this.bauteilKuerzel,
      useDisciplineGrouping: useDisciplineGrouping ?? this.useDisciplineGrouping,
      labelGewerk: labelGewerk ?? this.labelGewerk,
      labelAnlage: labelAnlage ?? this.labelAnlage,
      labelBauteil: labelBauteil ?? this.labelBauteil,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lfdNummerSpalte': lfdNummerSpalte,
      'nameSpalte': nameSpalte,
      'gewerkSpalte': gewerkSpalte,
      'etageSpalte': etageSpalte,
      'anlageBauteilSpalte': anlageBauteilSpalte,
      'parameterSpalte': parameterSpalte,
      'delimiterMode': delimiterMode,
      'anlageKuerzel': anlageKuerzel,
      'bauteilKuerzel': bauteilKuerzel,
      'useDisciplineGrouping': useDisciplineGrouping,
      'labelGewerk': labelGewerk,
      'labelAnlage': labelAnlage,
      'labelBauteil': labelBauteil,
    };
  }

  factory CsvSettings.fromJson(Map<String, dynamic> json) {
    return CsvSettings(
      lfdNummerSpalte: json['lfdNummerSpalte'] as int? ?? 0,
      nameSpalte: json['nameSpalte'] as int? ?? 1,
      gewerkSpalte: json['gewerkSpalte'] as int? ?? 2,
      etageSpalte: json['etageSpalte'] as int?,
      anlageBauteilSpalte: json['anlageBauteilSpalte'] as int?,
      parameterSpalte: json['parameterSpalte'] as int?,
      delimiterMode: json['delimiterMode'] as String? ?? 'auto',
      anlageKuerzel: json['anlageKuerzel'] as String? ?? 'A,Anlage',
      bauteilKuerzel: json['bauteilKuerzel'] as String? ?? 'B,Bauteil',
      useDisciplineGrouping: json['useDisciplineGrouping'] as bool? ?? true,
      labelGewerk: json['labelGewerk'] as String? ?? 'Gewerk',
      labelAnlage: json['labelAnlage'] as String? ?? 'Anlage',
      labelBauteil: json['labelBauteil'] as String? ?? 'Bauteil',
    );
  }
}

class CsvSettingsCache {
  static final Map<String, CsvSettings> _cache = {};

  static CsvSettings? get(String projectId) => _cache[projectId];

  static void set(String projectId, CsvSettings settings) {
    _cache[projectId] = settings;
  }
}

class CsvSettingsNotifier extends StateNotifier<CsvSettings> {
  final String projectId;

  CsvSettingsNotifier(this.projectId) : super(CsvSettings.defaults());

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'csv_settings_$projectId';
      final settingsJson = prefs.getString(key);
      if (settingsJson != null) {
        final decoded = json.decode(settingsJson) as Map<String, dynamic>;
        state = CsvSettings.fromJson(decoded);
        CsvSettingsCache.set(projectId, state);
        return;
      }
    } catch (_) {}
    CsvSettingsCache.set(projectId, state);
  }

  Future<void> save(CsvSettings settings) async {
    state = settings;
    CsvSettingsCache.set(projectId, state);
    final prefs = await SharedPreferences.getInstance();
    final key = 'csv_settings_$projectId';
    await prefs.setString(key, json.encode(settings.toJson()));
  }
}

final csvSettingsProvider =
    StateNotifierProviderFamily<CsvSettingsNotifier, CsvSettings, String>(
  (ref, projectId) => CsvSettingsNotifier(projectId),
);




