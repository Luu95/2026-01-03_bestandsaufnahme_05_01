// TextEditingController für die bearbeitbaren Felder der CSV-Settings-Page.
// Synchronisiert nur sichtbare Formularfelder mit einem [CsvSettings]-Draft.
// Legacy-Felder ohne UI (Kürzel, Grouping-Controller, displayNameSpalte) fehlen absichtlich.

import 'package:flutter/material.dart';

import 'package:bestandsaufnahme_01/features/csv/providers/csv_settings_provider.dart';

/// Hält stabile Controller über Rebuilds (Cursor/Fokus bleiben erhalten).
class CsvSettingsFormControllers {
  CsvSettingsFormControllers();

  late final TextEditingController labelGewerk;
  late final TextEditingController labelAnlage;
  late final TextEditingController labelBauteil;
  late final TextEditingController listTitleFieldIndex;
  late final TextEditingController listSubtitleFieldIndex;
  late final TextEditingController foto1;
  late final TextEditingController foto2;
  late final TextEditingController foto3;
  late final TextEditingController foto4;
  late final TextEditingController qrCode;
  late final TextEditingController attrRangeStart;
  late final TextEditingController attrRangeEnd;

  bool _initialized = false;

  void init(CsvSettings settings) {
    if (_initialized) return;
    _initialized = true;
    labelGewerk = TextEditingController(text: settings.labelGewerk);
    labelAnlage = TextEditingController(text: settings.labelAnlage);
    labelBauteil = TextEditingController(text: settings.labelBauteil);
    listTitleFieldIndex = TextEditingController(
      text: '${settings.listTitleInputFieldIndex}',
    );
    listSubtitleFieldIndex = TextEditingController(
      text: '${settings.listSubtitleInputFieldIndex}',
    );
    foto1 = TextEditingController(text: settings.foto1SpalteLabel ?? '');
    foto2 = TextEditingController(text: settings.foto2SpalteLabel ?? '');
    foto3 = TextEditingController(text: settings.foto3SpalteLabel ?? '');
    foto4 = TextEditingController(text: settings.foto4SpalteLabel ?? '');
    qrCode = TextEditingController(text: settings.qrCodeNummerSpalteLabel ?? '');
    attrRangeStart = TextEditingController(text: '4');
    attrRangeEnd = TextEditingController(text: '63');
    syncAttributeRangeFrom(settings);
  }

  void dispose() {
    if (!_initialized) return;
    labelGewerk.dispose();
    labelAnlage.dispose();
    labelBauteil.dispose();
    listTitleFieldIndex.dispose();
    listSubtitleFieldIndex.dispose();
    foto1.dispose();
    foto2.dispose();
    foto3.dispose();
    foto4.dispose();
    qrCode.dispose();
    attrRangeStart.dispose();
    attrRangeEnd.dispose();
  }

  /// Übernimmt Draft → Controller, ohne Selection beim Tippen zu zerstören.
  void syncFrom(CsvSettings settings) {
    if (!_initialized) {
      init(settings);
      return;
    }
    _setIfChanged(labelGewerk, settings.labelGewerk);
    _setIfChanged(labelAnlage, settings.labelAnlage);
    _setIfChanged(labelBauteil, settings.labelBauteil);
    _setIfChanged(listTitleFieldIndex, '${settings.listTitleInputFieldIndex}');
    _setIfChanged(
      listSubtitleFieldIndex,
      '${settings.listSubtitleInputFieldIndex}',
    );
    _setIfChanged(foto1, settings.foto1SpalteLabel ?? '');
    _setIfChanged(foto2, settings.foto2SpalteLabel ?? '');
    _setIfChanged(foto3, settings.foto3SpalteLabel ?? '');
    _setIfChanged(foto4, settings.foto4SpalteLabel ?? '');
    _setIfChanged(qrCode, settings.qrCodeNummerSpalteLabel ?? '');
    syncAttributeRangeFrom(settings);
  }

  void syncAttributeRangeFrom(CsvSettings settings) {
    var start0 = settings.attributeStartColumn;
    var count = settings.attributeCount;
    if (start0 == null && settings.attributeTripletColumns.isNotEmpty) {
      start0 = settings.attributeTripletColumns.first.nameColumn;
      count ??= settings.attributeTripletColumns.length;
    }
    if (start0 != null) {
      _setIfChanged(attrRangeStart, '${start0 + 1}');
    }
    if (start0 != null && count != null && count > 0) {
      _setIfChanged(attrRangeEnd, '${start0 + count * 3}');
    }
  }

  static void _setIfChanged(TextEditingController ctrl, String text) {
    if (ctrl.text == text) return;
    ctrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
