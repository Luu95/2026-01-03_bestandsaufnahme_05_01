/// CSV-Einstellungen: Mapping, Hierarchie und Persistenz.
///
/// Einstieg: Modelle unter `lib/features/csv/models/`; Instanz-Logik als Extensions
/// (`part`): hierarchy/, display/, schema/, params/. ATT-Slots:
/// [AnlageAttSlots]. Riverpod: `lib/features/csv/providers/csv_settings_provider.dart`.
///
/// Inhaltsverzeichnis:
/// 1–2 Felder/Konstruktor (diese Datei)
/// 3 Hierarchie-Instanz → hierarchy/hierarchy_keys.dart (+ static hier)
/// 4 Display-Instanz → display/display_name.dart (+ static hier)
/// 5 ATT-Header & Mapping (diese Datei)
/// 6 Dialog-Schema (diese Datei)
/// 7 ATT-Slots → params/anlage_att_slots.dart (dünne Wrapper hier)
/// 8 Listen-Titel-Instanz → display/list_title.dart (+ static hier)
/// 9 Schema-Item-Instanz → schema/schema_item_labels.dart (+ static hier)
/// 10 Persistenz (diese Datei)

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:bestandsaufnahme_01/features/csv/models/csv_hierarchy_level.dart';
import 'package:bestandsaufnahme_01/core/logging/app_log.dart';
import 'package:bestandsaufnahme_01/features/csv/models/attribute_column_pair.dart';
import 'package:bestandsaufnahme_01/features/csv/models/attribute_triplet_column.dart';
import 'package:bestandsaufnahme_01/features/csv/models/import_attribute_mapping.dart';

part 'hierarchy/hierarchy_keys.dart';
part 'display/display_name.dart';
part 'display/list_title.dart';
part 'schema/schema_item_labels.dart';
part 'params/anlage_att_slots.dart';

/// Projektbezogene CSV-Import-/Export-Konfiguration inkl. ATT-Mapping und Schema-Helfern.
class CsvSettings {
  // --- Abschnitt: 1 Param-Keys & ATT-Slots ---
  /// Interner Param-Key für die QR-Code-Nummer in Anlagen-Params.
  static const qrCodeNummerParamKey = 'qrCodeNummer';

  /// Rohe CSV-Zellen pro Header-Label (Import → Export 1:1).
  static const csvRowCellsParamKey = '__csvRowCells';

  /// Import-Reihenfolge (0-basiert, keine Sortierung beim Export).
  static const csvRowIndexParamKey = '__csvRowIndex';

  /// Merkt sich den ATT-Slot (Spaltenposition) je Attribut-Param-Key.
  static const attSlotParamKeyPrefix = '_att_slot_';

  /// Baut den internen Param-Key für den ATT-Slot von [paramKey].
  static String attSlotParamKey(String paramKey) =>
      '$attSlotParamKeyPrefix$paramKey';

  /// True, wenn [key] ein interner `_att_slot_*`-Metadaten-Key ist.
  static bool isAttSlotParamKey(String key) =>
      key.startsWith(attSlotParamKeyPrefix);

  /// Liest den gespeicherten ATT-Slot für [paramKey] aus [params].
  static int? attSlotForParam(Map<String, dynamic> params, String paramKey) {
    final raw = params[attSlotParamKey(paramKey)];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  /// Speichert den ATT-Slot für [paramKey] in [params].
  static void writeAttSlotForParam(
    Map<String, dynamic> params,
    String paramKey,
    int attSlot,
  ) {
    params[attSlotParamKey(paramKey)] = attSlot;
  }

  // --- Abschnitt: 2 Felder / Konstruktor / Range ---
  /// Konfiguration Hierarchie-Ebene 1 (typisch Gewerk/Disziplin).
  final HierarchyLevelConfig level1;
  /// Konfiguration Hierarchie-Ebene 2 (typisch Anlage/Schema-Item).
  final HierarchyLevelConfig level2;
  /// Konfiguration Hierarchie-Ebene 3 (typisch Bauteil/Blatt).
  final HierarchyLevelConfig level3;
  /// Trennzeichen-Modus beim Import (`auto`, `;`, `,`, …).
  final String delimiterMode;
  /// Kürzel-Liste zur Erkennung von Anlagen-Zeilen (kommagetrennt).
  final String anlageKuerzel;
  /// Kürzel-Liste zur Erkennung von Bauteil-Zeilen (kommagetrennt).
  final String bauteilKuerzel;
  /// True: Ebene 1 als Disziplin-Tab statt Listen-Gruppierung.
  final bool useDisciplineGrouping;
  /// Anzeige-Label für Ebene 1 / Disziplin.
  final String labelGewerk;
  /// Anzeige-Label für Ebene 2 / Schema-Item.
  final String labelAnlage;
  /// Anzeige-Label für Ebene 3 / Blatt.
  final String labelBauteil;
  /// Manuell konfigurierte Name/Wert-Paare (Anlagen-Zweierformat).
  final List<AttributeColumnPair> attributeColumnPairs;
  /// Attribut-Dreiergruppen: Name, Typ, Wert/Art (wird aus Header erkannt, falls leer).
  final List<AttributeTripletColumn> attributeTripletColumns;
  /// Manuelle Attribut-Range (0-basiert): erste Spalte der ersten Dreiergruppe.
  /// Wenn gesetzt zusammen mit [attributeCount], hat das Vorrang vor Header-Erkennung.
  final int? attributeStartColumn;
  /// Anzahl Attribute (= Anzahl Dreiergruppen Name/Typ/Wert).
  final int? attributeCount;
  /// Spalten-Label für Foto 1 beim CSV-Export; null/leer = Spalte weglassen.
  final String? foto1SpalteLabel;
  /// Spalten-Label für Foto 2 beim CSV-Export; null/leer = Spalte weglassen.
  final String? foto2SpalteLabel;
  /// Spalten-Label für Foto 3 beim CSV-Export; null/leer = Spalte weglassen.
  final String? foto3SpalteLabel;
  /// Spalten-Label für Foto 4 beim CSV-Export; null/leer = Spalte weglassen.
  final String? foto4SpalteLabel;
  /// Spalten-Label für QR-Code-Nummer beim CSV-Export. Leer = Spalte nicht verwenden.
  final String? qrCodeNummerSpalteLabel;
  /// Zuletzt importierte Headerzeile (Anlagen- oder Gewerkevorlagen-CSV).
  final List<String> importHeaderRow;
  /// Trennzeichen beim Export (meist `;`).
  final String exportDelimiter;
  /// Optionaler Override-Param-Key für Gewerk-Gruppierung.
  final String groupingGewerkParamKey;
  /// Optionaler Override-Param-Key für Anlagen-/Schema-Gruppierung.
  final String groupingAnlageParamKey;
  /// Param-Key für Anzeige/Vorlagen (Legacy; Listen-Titel nutzt [listTitleInputFieldIndex]).
  final String displayNameParamKey;
  /// Optional: Spalte aus Anlagen-CSV-Import (nur wenn importHeaderRow gesetzt ist).
  final int? displayNameSpalte;
  /// Welches Eingabefeld (1-basiert, Dialogreihenfolge) als Listen-Titel dient.
  final int listTitleInputFieldIndex;
  /// Welches Eingabefeld (1-basiert) als Listen-Untertitel dient. 0 = keiner.
  final int listSubtitleInputFieldIndex;

  const CsvSettings({
    required this.level1,
    required this.level2,
    required this.level3,
    required this.delimiterMode,
    required this.anlageKuerzel,
    required this.bauteilKuerzel,
    required this.useDisciplineGrouping,
    required this.labelGewerk,
    required this.labelAnlage,
    required this.labelBauteil,
    this.attributeColumnPairs = const [],
    this.attributeTripletColumns = const [],
    this.attributeStartColumn,
    this.attributeCount,
    this.foto1SpalteLabel,
    this.foto2SpalteLabel,
    this.foto3SpalteLabel,
    this.foto4SpalteLabel,
    this.qrCodeNummerSpalteLabel,
    this.importHeaderRow = const [],
    this.exportDelimiter = ';',
    this.groupingGewerkParamKey = '',
    this.groupingAnlageParamKey = '',
    this.displayNameParamKey = 'Name',
    this.displayNameSpalte,
    this.listTitleInputFieldIndex = 1,
    this.listSubtitleInputFieldIndex = 0,
  });

  /// True, wenn mindestens einmal ein Anlagen-CSV-Import durchgeführt wurde.
  bool get hasAnlagenCsvImport => importHeaderRow.isNotEmpty;

  /// Manuelle Attribut-Range ist konfiguriert (Erste Spalte + Anzahl).
  bool get hasManualAttributeRange =>
      attributeStartColumn != null &&
      attributeStartColumn! >= 0 &&
      attributeCount != null &&
      attributeCount! > 0;

  /// Letzte Spalte der manuellen Range (0-basiert), sonst null.
  int? get attributeLastColumn {
    if (!hasManualAttributeRange) return null;
    return attributeStartColumn! + attributeCount! * 3 - 1;
  }

  /// Erzeugt [count] Dreiergruppen ab [startColumn] (0-basiert): Name, Typ, Wert.
  static List<AttributeTripletColumn> tripletsFromStartAndCount({
    required int startColumn,
    required int count,
  }) {
    if (startColumn < 0 || count <= 0) return const [];
    final groups = <AttributeTripletColumn>[];
    for (var i = 0; i < count; i++) {
      final base = startColumn + i * 3;
      groups.add(AttributeTripletColumn(
        nameColumn: base,
        typeColumn: base + 1,
        artColumn: base + 2,
      ));
    }
    return groups;
  }

  /// Erzeugt Dreiergruppen aus 1-basiertem Spaltenbereich (inkl. Ende).
  /// Wirft [ArgumentError], wenn der Bereich nicht durch 3 teilbar ist.
  static List<AttributeTripletColumn> tripletsFromInclusiveRange1Based({
    required int firstColumn1Based,
    required int lastColumn1Based,
  }) {
    if (firstColumn1Based < 1 || lastColumn1Based < firstColumn1Based) {
      throw ArgumentError('Ungültiger Spaltenbereich (Erste ≤ Letzte, ab 1).');
    }
    final columnCount = lastColumn1Based - firstColumn1Based + 1;
    if (columnCount % 3 != 0) {
      throw ArgumentError(
        'Anzahl Spalten ($columnCount) muss durch 3 teilbar sein.',
      );
    }
    return tripletsFromStartAndCount(
      startColumn: firstColumn1Based - 1,
      count: columnCount ~/ 3,
    );
  }

  // --- Abschnitt: 3 Hierarchie (static) ---
  /// Ob Header/Key eine generische Ebenen-Spalte ist (Ebene1, Ebene 2, …).
  static bool isEbeneHierarchyHeader(String key) {
    final t = key.trim().replaceAll(RegExp(r'\s+'), '');
    if (t.isEmpty) return false;
    return RegExp(r'^Ebene[1-3]$', caseSensitive: false).hasMatch(t);
  }
  // --- Abschnitt: 4 Display-Name (static) ---
  /// Markiert Anlagen, die ohne echten Titel gespeichert wurden.
  static const String listNamePlaceholderParamKey = '__listNamePlaceholder';
  /// Beim Speichern gesetzter Listen-Titel (Wert von Eingabefeld N).
  static const String listTitleParamKey = '__listTitle';

  /// Case-insensitive Key-Vergleich inkl. UUID-Suffix-Aliase (`Name` ≈ `Name_abc`).
  static bool paramKeysMatch(String a, String b) {
    final x = a.trim().toLowerCase();
    final y = b.trim().toLowerCase();
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    return x.startsWith('${y}_') || y.startsWith('${x}_');
  }
  // --- Abschnitt: 5 ATT-/Gewerke-Header & Mapping ---
  /// True bei Param-Keys, die CSV-Spaltennamen sind (ATT7, ATT7_wert, …).
  static bool isAnlagenCsvColumnParamKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;
    final lower = k.toLowerCase();
    if (RegExp(r'^att\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^att\d+_wert$').hasMatch(lower)) return true;
    if (RegExp(r'^att_wert\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^att\d+_art$').hasMatch(lower)) return true;
    if (RegExp(r'^att_art\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^att\d+_type$').hasMatch(lower)) return true;
    if (RegExp(r'^att_type\d+$').hasMatch(lower)) return true;
    if (RegExp(r'^att\d+_options$').hasMatch(lower)) return true;
    if (RegExp(r'^att_options\d+$').hasMatch(lower)) return true;
    return false;
  }

  /// true, wenn die Wertspalte `ATT*_WERT` ist (Anlagen-Feldwert).
  /// `ATT*_ART` ist in Gewerkevorlagen die Schema-Gruppe, kein Eingabewert.
  static bool isAnlagenWertColumnHeader(String header) {
    final h = normalizeAttHeaderToken(header);
    return RegExp(r'^ATT\d+_WERT$').hasMatch(h) ||
        RegExp(r'^ATT_WERT\d+$').hasMatch(h);
  }

  /// true bei `ATT*_ART` / `ATT_ART*` (Gewerke-Gruppierung).
  static bool isGewerkeArtGroupColumnHeader(String header) {
    final h = normalizeAttHeaderToken(header);
    return RegExp(r'^ATT\d+_ART$').hasMatch(h) ||
        RegExp(r'^ATT_ART\d+$').hasMatch(h);
  }

  /// Normalisiert CSV-Header für ATT-Erkennung (Leerzeichen → Unterstrich).
  static String normalizeAttHeaderToken(String header) {
    return header.trim().replaceAll(RegExp(r'\s+'), '_').toUpperCase();
  }

  /// Entfernt Zeilenumbrüche aus Feldbezeichnungen (CSV → Dialog-Anzeige).
  static String normalizeFieldLabelForDisplay(String? raw) {
    if (raw == null) return '';
    return raw
        .replaceAll(RegExp(r'[\r\n\u2028\u2029]+'), ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  /// Anlagen-Import: Header mit ATTn + ATTn_wert (Zweier-Format).
  static bool headerLooksLikeAnlagenWertFormat(List<String> headers) {
    for (final h in headers) {
      final u = normalizeAttHeaderToken(h);
      if (RegExp(r'^ATT\d+_WERT$').hasMatch(u)) return true;
      if (RegExp(r'^ATT_WERT\d+$').hasMatch(u)) return true;
    }
    return false;
  }

  /// Gewerkevorlagen: Header mit TYPE je Attribut (Dreier- oder Legacy-Vierer-Format).
  static bool headerLooksLikeGewerkeTripletFormat(List<String> headers) {
    for (final h in headers) {
      final u = normalizeAttHeaderToken(h);
      if (u.contains('_TYPE') ||
          u.contains('_OPTIONS') ||
          u.endsWith('_ART') ||
          u.endsWith('_WERT')) {
        return true;
      }
    }
    return false;
  }

  /// True, wenn der Header eine reine Typ-Definitions-Spalte ist (nicht exportieren).
  static bool isGewerkeTypeDefinitionHeader(String header) {
    final u = normalizeAttHeaderToken(header);
    return u.contains('_TYPE') || u.contains('_OPTIONS');
  }

  /// Header für Anlagen-Export: ohne TYPE/OPTIONS-Spalten, ART → WERT.
  static List<String> headersForAnlagenExport(List<String> importHeaders) {
    final result = <String>[];
    for (final raw in importHeaders) {
      if (isGewerkeTypeDefinitionHeader(raw)) continue;
      var h = raw.trim();
      final u = normalizeAttHeaderToken(h);
      if (u.endsWith('_ART')) {
        h = '${h.substring(0, h.length - 4)}_WERT';
      }
      result.add(h);
    }
    return result;
  }

  /// Parst TYPE-Zelle aus Gewerkevorlagen: Freitext, number oder Opt1|Opt2 → dropdown.
  static Map<String, dynamic> schemaFieldFromGewerkeTypeCell(
    String name,
    String typeStr, {
    String? legacyOptionsStr,
    String? artStr,
  }) {
    final entry = <String, dynamic>{
      'key': name,
      'label': normalizeFieldLabelForDisplay(name),
    };

    final trimmedType = typeStr.trim();
    final lowerType = trimmedType.toLowerCase();

    if (trimmedType.contains('|')) {
      entry['type'] = 'dropdown';
      entry['options'] = trimmedType
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (lowerType == 'freitext' || lowerType == 'text') {
      entry['type'] = 'text';
    } else if (lowerType == 'number' || lowerType == 'int') {
      entry['type'] = 'number';
    } else if (lowerType == 'date' || lowerType == 'datum') {
      entry['type'] = 'date';
    } else if (lowerType == 'multiline' || lowerType == 'bemerkung') {
      entry['type'] = 'multiline';
    } else if (lowerType == 'dropdown' ||
        lowerType == 'select' ||
        lowerType == 'option') {
      entry['type'] = 'dropdown';
      final legacy = parseGewerkeOptionsList(legacyOptionsStr);
      if (legacy.isNotEmpty) entry['options'] = legacy;
    } else {
      // Unbekannte TYPE-Zellen (z. B. versehentlich eingetragene Werte) → Freitext
      entry['type'] = 'text';
    }

    final art = normalizeFieldLabelForDisplay(artStr ?? '');
    if (art.isNotEmpty) entry['art'] = art;
    return entry;
  }

  /// Parst OPTIONS-Zellen (`a|b`, `a;b` oder `a,b`) zu einer Options-Liste.
  static List<String> parseGewerkeOptionsList(String? optionsStr) {
    if (optionsStr == null || optionsStr.trim().isEmpty) return [];
    final s = optionsStr.trim();
    final split = s.contains('|')
        ? s.split('|')
        : (s.contains(';') ? s.split(';') : s.split(','));
    return split.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Dreiergruppen aus Gewerke-Header (ATTn, ATTn_TYPE, ATTn_WERT/ART).
  static List<AttributeTripletColumn> detectTripletsFromHeader(
    List<String> headers,
  ) {
    final groups = <AttributeTripletColumn>[];
    for (var i = 0; i < headers.length; i++) {
      final h = normalizeAttHeaderToken(headers[i]);
      final m = RegExp(r'^ATT(\d+)$').firstMatch(h);
      if (m == null) continue;
      final n = int.parse(m.group(1)!);
      int indexWhere(String suffix) {
        return headers.indexWhere(
          (x) => normalizeAttHeaderToken(x) == 'ATT$n$suffix',
        );
      }

      final typeIdx = indexWhere('_TYPE');
      if (typeIdx < 0) continue;

      final optIdx = indexWhere('_OPTIONS');
      var valueIdx = indexWhere('_WERT');
      if (valueIdx < 0) valueIdx = indexWhere('_ART');

      groups.add(AttributeTripletColumn(
        nameColumn: i,
        typeColumn: typeIdx,
        optionsColumn: optIdx >= 0 ? optIdx : -1,
        artColumn: valueIdx >= 0 ? valueIdx : -1,
      ));
    }
    return groups;
  }

  /// Gespeicherte Dreiergruppen passen zum Header (Wertspalte ≠ TYPE/OPTIONS).
  static bool tripletsMatchHeader(
    List<AttributeTripletColumn> triplets,
    List<String> headers,
  ) {
    if (triplets.isEmpty || headers.isEmpty) return false;
    for (final g in triplets) {
      if (g.isPairDialect) return false;
      if (g.nameColumn < 0 || g.nameColumn >= headers.length) return false;
      if (g.typeColumn < 0 || g.typeColumn >= headers.length) return false;
      final typeToken = normalizeAttHeaderToken(headers[g.typeColumn]);
      if (!typeToken.contains('_TYPE')) return false;
      // Wertspalte muss ART/WERT sein – nie TYPE (sonst landen Typdefinitionen als Werte).
      if (g.artColumn < 0 || g.artColumn >= headers.length) return false;
      if (g.artColumn == g.typeColumn) return false;
      if (isGewerkeTypeDefinitionHeader(headers[g.artColumn])) return false;
      final artToken = normalizeAttHeaderToken(headers[g.artColumn]);
      if (!artToken.contains('_ART') && !artToken.contains('_WERT')) {
        return false;
      }
    }
    return true;
  }

  /// Pair-Dialekt-Triplets bzw. legacy [attributeColumnPairs] → Paare.
  List<AttributeColumnPair> get effectiveAttributePairs {
    final fromTriplets = attributeTripletColumns
        .where((t) => t.isPairDialect)
        .map((t) => t.toPair())
        .toList();
    if (fromTriplets.isNotEmpty) return fromTriplets;
    return attributeColumnPairs;
  }

  /// Kanonische Gruppen: Triplets, ggf. aus Pairs normalisiert.
  List<AttributeTripletColumn> get canonicalAttributeTriplets {
    if (attributeTripletColumns.isNotEmpty) return attributeTripletColumns;
    if (attributeColumnPairs.isEmpty) return const [];
    return attributeColumnPairs
        .map(AttributeTripletColumn.fromPair)
        .toList(growable: false);
  }

  /// Pairs → Triplets (typeColumn=-1); echte Triplets haben Vorrang.
  static CsvSettings canonicalizeAttributeMapping(CsvSettings settings) {
    final triplets = settings.attributeTripletColumns;
    final pairs = settings.attributeColumnPairs;
    if (pairs.isEmpty) return settings;

    final hasRealTriplets =
        triplets.any((t) => !t.isPairDialect);
    if (hasRealTriplets) {
      // Alte Pair-Liste droppen – Triplet-Dialekt ist kanonisch.
      return settings.copyWith(attributeColumnPairs: const []);
    }
    if (triplets.isNotEmpty) {
      // Bereits Pair-Triplets gespeichert.
      return settings.copyWith(attributeColumnPairs: const []);
    }
    return settings.copyWith(
      attributeColumnPairs: const [],
      attributeTripletColumns:
          pairs.map(AttributeTripletColumn.fromPair).toList(growable: false),
    );
  }

  /// Wählt Paar- oder Triplet-Mapping passend zum Import-Header.
  /// Ergebnis ist immer kanonisch: Triplets + [AttributeDialect].
  static ImportAttributeMapping resolveImportAttributeMapping({
    required List<String> headerRow,
    required CsvSettings settings,
  }) {
    ImportAttributeMapping manualOrSettings() {
      if (settings.hasManualAttributeRange) {
        final manual = settings.attributeTripletColumns.isNotEmpty
            ? settings.attributeTripletColumns
            : tripletsFromStartAndCount(
                startColumn: settings.attributeStartColumn!,
                count: settings.attributeCount!,
              );
        final dialect = manual.any((t) => t.isPairDialect)
            ? AttributeDialect.anlagenPair
            : AttributeDialect.gewerkeTriplet;
        return ImportAttributeMapping(triplets: manual, dialect: dialect);
      }
      final canon = canonicalizeAttributeMapping(settings);
      if (canon.attributeTripletColumns.isEmpty) {
        return const ImportAttributeMapping();
      }
      final dialect = canon.attributeTripletColumns.every((t) => t.isPairDialect)
          ? AttributeDialect.anlagenPair
          : AttributeDialect.gewerkeTriplet;
      return ImportAttributeMapping(
        triplets: canon.attributeTripletColumns,
        dialect: dialect,
      );
    }

    if (headerRow.isEmpty) {
      return manualOrSettings();
    }

    // Bekannte ATT-Formate: Header-Erkennung hat Vorrang vor manueller Range
    // (sonst bleibt _schema bei Gewerkevorlagen leer und Neuaufnahme ohne Felder).
    if (headerLooksLikeAnlagenWertFormat(headerRow)) {
      final detected = detectAnlagenAttributePairsFromHeader(headerRow);
      if (detected.isNotEmpty) {
        return ImportAttributeMapping.fromPairs(detected);
      }
      return manualOrSettings();
    }

    if (headerLooksLikeGewerkeTripletFormat(headerRow)) {
      final detected = detectTripletsFromHeader(headerRow);
      if (detected.isNotEmpty) {
        return ImportAttributeMapping.fromTriplets(detected);
      }
      if (tripletsMatchHeader(settings.attributeTripletColumns, headerRow)) {
        return ImportAttributeMapping.fromTriplets(
          settings.attributeTripletColumns,
        );
      }
      return manualOrSettings();
    }

    if (tripletsMatchHeader(settings.attributeTripletColumns, headerRow)) {
      return ImportAttributeMapping.fromTriplets(
        settings.attributeTripletColumns,
      );
    }

    // Kein ATT-Header: manuelle Range nutzen (z. B. freie Spalten als Dreiergruppen).
    return manualOrSettings();
  }

  /// Erkennt ATT/ATT_wert-Spaltenpaare aus der Import-Headerzeile (0-basierte Indizes).
  /// Erkennt auch ATT(n)_ART / ATT_ART(n) als Wertspalte (Gewerke-/Anlagen-Layout).
  static List<AttributeColumnPair> detectAnlagenAttributePairsFromHeader(
    List<String> headers,
  ) {
    final nameColByN = <int, int>{};
    final valueColByN = <int, int>{};

    for (var i = 0; i < headers.length; i++) {
      final raw = headers[i].trim();
      if (raw.isEmpty) continue;
      final upper = normalizeAttHeaderToken(raw);

      final attOnly = RegExp(r'^ATT(\d+)$').firstMatch(upper);
      if (attOnly != null) {
        nameColByN[int.parse(attOnly.group(1)!)] = i;
        continue;
      }
      final attWert = RegExp(r'^ATT(\d+)_WERT$').firstMatch(upper);
      if (attWert != null) {
        valueColByN[int.parse(attWert.group(1)!)] = i;
        continue;
      }
      final attWertAlt = RegExp(r'^ATT_WERT(\d+)$').firstMatch(upper);
      if (attWertAlt != null) {
        valueColByN[int.parse(attWertAlt.group(1)!)] = i;
        continue;
      }
      // ART nur als Wertspalte, wenn noch kein WERT für diesen Slot existiert.
      final attArt = RegExp(r'^ATT(\d+)_ART$').firstMatch(upper);
      if (attArt != null) {
        final n = int.parse(attArt.group(1)!);
        valueColByN.putIfAbsent(n, () => i);
        continue;
      }
      final attArtAlt = RegExp(r'^ATT_ART(\d+)$').firstMatch(upper);
      if (attArtAlt != null) {
        final n = int.parse(attArtAlt.group(1)!);
        valueColByN.putIfAbsent(n, () => i);
      }
    }

    final nums = {...nameColByN.keys, ...valueColByN.keys}.toList()..sort();
    final pairs = <AttributeColumnPair>[];
    for (final n in nums) {
      final valueCol = valueColByN[n];
      if (valueCol == null) continue;
      final nameCol = nameColByN[n] ?? valueCol;
      pairs.add(AttributeColumnPair(
        nameColumn: nameCol,
        valueColumn: valueCol,
        attNumber: n,
      ));
    }
    return pairs;
  }

  /// ATT-Nummer aus Header-Label (ATT7 / ATT7_WERT / ATT7_TYPE → 7).
  static int? attNumberFromHeaderLabel(String header) {
    final upper = normalizeAttHeaderToken(header);
    final m =
        RegExp(r'^ATT(\d+)(?:_(?:WERT|ART|TYPE|OPTIONS))?$').firstMatch(upper);
    if (m != null) return int.tryParse(m.group(1)!);
    final alt =
        RegExp(r'^ATT_(?:WERT|ART|TYPE|OPTIONS)(\d+)$').firstMatch(upper);
    if (alt != null) return int.tryParse(alt.group(1)!);
    return null;
  }

  /// ATT-Nummer aus Schema-Feld (1 = ATT1). Null bei Legacy-Daten ohne Slot.
  static int? attSlotFromSchemaField(Map<String, dynamic> field) {
    final raw = field['attSlot'] ?? field['attNumber'];
    if (raw is int && raw > 0) return raw;
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  /// Schema-Feld für festen ATT-Slot.
  /// Legacy: Listenindex nur wenn kein Feld attSlot gespeichert hat.
  static Map<String, dynamic>? schemaFieldAtAttSlot(
    int attSlot,
    List<Map<String, dynamic>> fields,
  ) {
    if (attSlot <= 0) return null;
    for (final f in fields) {
      if (attSlotFromSchemaField(f) == attSlot) return f;
    }
    final usesAttSlots = fields.any((f) => attSlotFromSchemaField(f) != null);
    if (usesAttSlots) return null;
    final idx = attSlot - 1;
    if (idx >= 0 && idx < fields.length) return fields[idx];
    return null;
  }

  /// ATT-Nummer für Spaltenpaar (Header-Nummer oder Listenposition).
  static int attSlotForPair(AttributeColumnPair pair, int pairIndex) =>
      pair.attNumber ?? (pairIndex + 1);

  /// Param-Keys, die nicht als Dialog-Felder angezeigt werden sollen.
  // --- Abschnitt: 6 Dialog-Schema ---
  static bool isReservedDialogParamKey(String key, CsvSettings? settings) {
    final k = key.trim();
    if (k.isEmpty || k.startsWith('_')) return true;
    if (k == 'lfdNummer' ||
        k == 'photoPaths' ||
        k == '__parentLfdNummer' ||
        k == '__syntheticParent' ||
        k == csvRowCellsParamKey ||
        k == csvRowIndexParamKey) {
      return true;
    }
    if (isAnlagenCsvColumnParamKey(k)) return true;
    if (settings != null) {
      if (settings.matchesReservedDialogParamKey(k)) return true;
    }
    return false;
  }

  /// Dialog-Schema aus ATT-Namen in gespeicherten CSV-Zellen (auch ohne Wert).
  static List<Map<String, dynamic>> schemaFieldsFromCsvAttRowCells(
    Map<String, dynamic> params, {
    required List<String> importHeaders,
  }) {
    if (importHeaders.isEmpty) return const [];
    final raw = params[csvRowCellsParamKey];
    if (raw is! Map) return const [];
    final cells = <String, String>{};
    for (final e in raw.entries) {
      final k = e.key.toString().trim();
      if (k.isEmpty) continue;
      cells[k] = e.value?.toString() ?? '';
    }
    if (cells.isEmpty) return const [];

    final triplets = detectTripletsFromHeader(importHeaders);
    if (triplets.isEmpty) {
      // Zweier-Format: Name-Spalte enthält Feldlabel
      final pairs = detectAnlagenAttributePairsFromHeader(importHeaders);
      final fields = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (var i = 0; i < pairs.length; i++) {
        final pair = pairs[i];
        if (pair.nameColumn < 0 || pair.nameColumn >= importHeaders.length) {
          continue;
        }
        final nameHeader = importHeaders[pair.nameColumn].trim();
        final name = (cells[nameHeader] ?? '').trim();
        if (name.isEmpty || isAnlagenCsvColumnParamKey(name)) continue;
        if (looksLikeTypeOrOptionsDefinition(name)) continue;
        if (seen.contains(name.toLowerCase())) continue;
        seen.add(name.toLowerCase());
        fields.add({
          'key': name,
          'label': normalizeFieldLabelForDisplay(name),
          'type': 'text',
          'attSlot': attSlotForPair(pair, i),
        });
      }
      return fields;
    }

    final fields = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (var i = 0; i < triplets.length; i++) {
      final t = triplets[i];
      if (t.nameColumn < 0 || t.nameColumn >= importHeaders.length) continue;
      final nameHeader = importHeaders[t.nameColumn].trim();
      final name = (cells[nameHeader] ?? '').trim();
      if (name.isEmpty || isAnlagenCsvColumnParamKey(name)) continue;
      if (looksLikeTypeOrOptionsDefinition(name)) continue;
      if (seen.contains(name.toLowerCase())) continue;
      seen.add(name.toLowerCase());

      var typeStr = '';
      if (t.typeColumn >= 0 && t.typeColumn < importHeaders.length) {
        typeStr = (cells[importHeaders[t.typeColumn].trim()] ?? '').trim();
      }
      var artStr = '';
      if (t.artColumn >= 0 && t.artColumn < importHeaders.length) {
        final artHeader = importHeaders[t.artColumn].trim();
        // Nur ATT*_ART als Schema-Gruppe; ATT*_WERT ist Anlagen-Feldwert.
        if (isGewerkeArtGroupColumnHeader(artHeader)) {
          artStr = (cells[artHeader] ?? '').trim();
        }
      }
      final entry = schemaFieldFromGewerkeTypeCell(
        name,
        typeStr,
        artStr: artStr,
      );
      entry['attSlot'] = attNumberFromHeaderLabel(nameHeader) ?? (i + 1);
      fields.add(entry);
    }
    return fields;
  }

  /// Dialog-Schema aus vorhandenen Parametern (Fallback ohne Gewerkevorlage).
  static List<Map<String, dynamic>> schemaFieldsFromParams(
    Map<String, dynamic> params, {
    CsvSettings? settings,
  }) {
    final fields = <Map<String, dynamic>>[];
    for (final entry in params.entries) {
      final key = entry.key.toString();
      if (isReservedDialogParamKey(key, settings)) continue;
      if (looksLikeTypeOrOptionsDefinition(key)) continue;
      final value = entry.value;
      if (value == null || value.toString().trim().isEmpty) continue;
      if (looksLikeTypeOrOptionsDefinition(value.toString())) continue;
      fields.add({
        'key': key,
        'label': normalizeFieldLabelForDisplay(key),
        'type': 'text',
      });
    }
    return fields;
  }

  /// Nummer aus Param-Key ATT7, ATT7_wert, ATT_WERT7, ATT7_TYPE (sonst null).
  static int? anlagenColumnIndexFromParamKey(String key) {
    final raw = key.trim();
    if (raw.isEmpty) return null;
    final att = RegExp(r'^ATT(\d+)$', caseSensitive: false).firstMatch(raw);
    if (att != null) return int.parse(att.group(1)!);
    final upper = raw.toUpperCase();
    final w1 = RegExp(r'^ATT(\d+)_WERT$').firstMatch(upper);
    if (w1 != null) return int.parse(w1.group(1)!);
    final w2 = RegExp(r'^ATT_WERT(\d+)$').firstMatch(upper);
    if (w2 != null) return int.parse(w2.group(1)!);
    final a1 = RegExp(r'^ATT(\d+)_ART$').firstMatch(upper);
    if (a1 != null) return int.parse(a1.group(1)!);
    final a2 = RegExp(r'^ATT_ART(\d+)$').firstMatch(upper);
    if (a2 != null) return int.parse(a2.group(1)!);
    final t1 = RegExp(r'^ATT(\d+)_TYPE$').firstMatch(upper);
    if (t1 != null) return int.parse(t1.group(1)!);
    final t2 = RegExp(r'^ATT_TYPE(\d+)$').firstMatch(upper);
    if (t2 != null) return int.parse(t2.group(1)!);
    final o1 = RegExp(r'^ATT(\d+)_OPTIONS$').firstMatch(upper);
    if (o1 != null) return int.parse(o1.group(1)!);
    final o2 = RegExp(r'^ATT_OPTIONS(\d+)$').firstMatch(upper);
    if (o2 != null) return int.parse(o2.group(1)!);
    return null;
  }

  /// Entfernt CSV-Spalten-Keys (ATT/ATT_wert) aus Schema-Listen für den Dialog.
  static List<Map<String, dynamic>> filterSchemaFieldsForDialog(
    List<Map<String, dynamic>> fields,
  ) {
    return fields
        .where((f) {
          final key = (f['key'] ?? '').toString();
          final label = (f['label'] ?? '').toString();
          if (isAnlagenCsvColumnParamKey(key) ||
              isAnlagenCsvColumnParamKey(label)) {
            return false;
          }
          // Options-/TYPE-Strings nie als eigenes Eingabefeld (gehören in dropdown options).
          if (looksLikeTypeOrOptionsDefinition(key) ||
              looksLikeTypeOrOptionsDefinition(label)) {
            return false;
          }
          return true;
        })
        .map((f) => Map<String, dynamic>.from(f))
        .toList();
  }

  /// true bei reinen Typ-Tokens oder Pipe-Optionslisten (ATT_TYPE-Inhalt).
  static bool looksLikeTypeOrOptionsDefinition(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return false;
    final lower = v.toLowerCase();
    const tokens = {
      'text',
      'freitext',
      'number',
      'int',
      'date',
      'datum',
      'multiline',
      'bemerkung',
      'dropdown',
      'select',
      'option',
    };
    if (tokens.contains(lower)) return true;
    if (!v.contains('|')) return false;
    final parts = v
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.length >= 2;
  }

  // --- Abschnitt: 7 ATT-Slots / Schema-art ---
  // Primärer Schreibpfad für Werte: CsvService. Implementierung: params/anlage_att_slots.dart

  /// Wrapper → [AnlageAttSlots.effectiveSchemaArtGroup].
  static String? effectiveSchemaArtGroup(Map<String, dynamic> fieldDef) =>
      AnlageAttSlots.effectiveSchemaArtGroup(fieldDef);

  /// Wrapper → [AnlageAttSlots.writeFromSchemaFields].
  static void writeAttSlotsFromSchemaFields(
    Map<String, dynamic> params,
    List<Map<String, dynamic>> schemaFields,
  ) =>
      AnlageAttSlots.writeFromSchemaFields(params, schemaFields);

  /// Wrapper → [AnlageAttSlots.writeFromImportHeader].
  static void writeAttSlotsFromImportHeader({
    required Map<String, dynamic> params,
    required List<String> importHeaders,
    required List<Map<String, dynamic>> schemaFields,
  }) =>
      AnlageAttSlots.writeFromImportHeader(
        params: params,
        importHeaders: importHeaders,
        schemaFields: schemaFields,
      );

  /// Wrapper → [AnlageAttSlots.ensureForDialog].
  static void ensureAttSlotsForDialog({
    required Map<String, dynamic> params,
    required List<Map<String, dynamic>> schemaFields,
    List<String> importHeaders = const [],
  }) =>
      AnlageAttSlots.ensureForDialog(
        params: params,
        schemaFields: schemaFields,
        importHeaders: importHeaders,
      );

  // --- Abschnitt: 8 Listen-Titel (static) ---
  /// Listen-Titel, wenn das gewählte Eingabefeld leer ist.
  static const String unknownAnlageListLabel = 'Unbekannte Anlage';
  // --- Abschnitt: 9 Schema-Item (static) ---
  /// Legacy-Param-Keys – nur zum Lesen älterer importierter Daten.
  static const List<String> legacySchemaItemParamKeys = [
    'Revisionsobjekt',
    'Anlagentyp',
    'Anlage',
  ];
  // --- Abschnitt: 10 Persistenz ---
  /// Standard-Einstellungen (Ebene1–3 in Spalte 0/1/2, Semikolon-Export).
  factory CsvSettings.defaults() {
    // Erste drei Spalten = Ebene1 / Ebene2 / Ebene3 (Anlagen- & Vorlagen-CSV).
    return const CsvSettings(
      level1: HierarchyLevelConfig(enabled: true, nameColumn: 0),
      level2: HierarchyLevelConfig(enabled: true, nameColumn: 1),
      level3: HierarchyLevelConfig(
        enabled: true,
        nameColumn: 2,
        useIdColumn: false,
      ),
      delimiterMode: 'auto',
      anlageKuerzel: 'A,Anlage',
      bauteilKuerzel: 'B,Bauteil',
      useDisciplineGrouping: true,
      labelGewerk: 'Gewerk',
      labelAnlage: 'Anlage',
      labelBauteil: 'Bauteil',
      attributeColumnPairs: [],
      importHeaderRow: [],
      exportDelimiter: ';',
    );
  }

  /// Kopie mit optional überschriebenen Feldern.
  ///
  /// Sentinel: „Feld nicht ändern“ in [copyWith] (unterscheidet von explizitem `null`).
  static const Object _unset = Object();

  /// [clearDisplayNameSpalte] / [clearAttributeRange] setzen die jeweiligen
  /// Felder explizit auf null (sonst würde `?? this.…` den alten Wert behalten).
  ///
  /// Nullable Export-Labels (`foto*`, `qrCode*`): `null` übergibt → Feld leeren;
  /// Parameter weglassen → unverändert.
  CsvSettings copyWith({
    HierarchyLevelConfig? level1,
    HierarchyLevelConfig? level2,
    HierarchyLevelConfig? level3,
    String? delimiterMode,
    String? anlageKuerzel,
    String? bauteilKuerzel,
    bool? useDisciplineGrouping,
    String? labelGewerk,
    String? labelAnlage,
    String? labelBauteil,
    List<AttributeColumnPair>? attributeColumnPairs,
    List<AttributeTripletColumn>? attributeTripletColumns,
    int? attributeStartColumn,
    int? attributeCount,
    Object? foto1SpalteLabel = _unset,
    Object? foto2SpalteLabel = _unset,
    Object? foto3SpalteLabel = _unset,
    Object? foto4SpalteLabel = _unset,
    Object? qrCodeNummerSpalteLabel = _unset,
    List<String>? importHeaderRow,
    String? exportDelimiter,
    String? groupingGewerkParamKey,
    String? groupingAnlageParamKey,
    String? displayNameParamKey,
    int? displayNameSpalte,
    int? listTitleInputFieldIndex,
    int? listSubtitleInputFieldIndex,
    bool clearDisplayNameSpalte = false,
    bool clearAttributeRange = false,
  }) {
    String? pickNullableLabel(Object? value, String? current) =>
        identical(value, _unset) ? current : value as String?;

    return CsvSettings(
      level1: level1 ?? this.level1,
      level2: level2 ?? this.level2,
      level3: level3 ?? this.level3,
      delimiterMode: delimiterMode ?? this.delimiterMode,
      anlageKuerzel: anlageKuerzel ?? this.anlageKuerzel,
      bauteilKuerzel: bauteilKuerzel ?? this.bauteilKuerzel,
      useDisciplineGrouping: useDisciplineGrouping ?? this.useDisciplineGrouping,
      labelGewerk: labelGewerk ?? this.labelGewerk,
      labelAnlage: labelAnlage ?? this.labelAnlage,
      labelBauteil: labelBauteil ?? this.labelBauteil,
      attributeColumnPairs: attributeColumnPairs ?? this.attributeColumnPairs,
      attributeTripletColumns:
          attributeTripletColumns ?? this.attributeTripletColumns,
      attributeStartColumn: clearAttributeRange
          ? null
          : (attributeStartColumn ?? this.attributeStartColumn),
      attributeCount:
          clearAttributeRange ? null : (attributeCount ?? this.attributeCount),
      foto1SpalteLabel: pickNullableLabel(foto1SpalteLabel, this.foto1SpalteLabel),
      foto2SpalteLabel: pickNullableLabel(foto2SpalteLabel, this.foto2SpalteLabel),
      foto3SpalteLabel: pickNullableLabel(foto3SpalteLabel, this.foto3SpalteLabel),
      foto4SpalteLabel: pickNullableLabel(foto4SpalteLabel, this.foto4SpalteLabel),
      qrCodeNummerSpalteLabel:
          pickNullableLabel(qrCodeNummerSpalteLabel, this.qrCodeNummerSpalteLabel),
      importHeaderRow: importHeaderRow ?? this.importHeaderRow,
      exportDelimiter: exportDelimiter ?? this.exportDelimiter,
      groupingGewerkParamKey: groupingGewerkParamKey ?? this.groupingGewerkParamKey,
      groupingAnlageParamKey: groupingAnlageParamKey ?? this.groupingAnlageParamKey,
      displayNameParamKey: displayNameParamKey ?? this.displayNameParamKey,
      displayNameSpalte: clearDisplayNameSpalte
          ? null
          : (displayNameSpalte ?? this.displayNameSpalte),
      listTitleInputFieldIndex:
          listTitleInputFieldIndex ?? this.listTitleInputFieldIndex,
      listSubtitleInputFieldIndex:
          listSubtitleInputFieldIndex ?? this.listSubtitleInputFieldIndex,
    );
  }

  /// Serialisiert die Einstellungen für SharedPreferences.
  Map<String, dynamic> toJson() {
    final canon = canonicalizeAttributeMapping(this);
    // Soft-Rollback: Pair-Dialekt zusätzlich als attributeColumnPairs schreiben.
    final pairView = canon.attributeTripletColumns
        .where((t) => t.isPairDialect)
        .map((t) => t.toPair().toJson())
        .toList();
    return {
      'level1': level1.toJson(),
      'level2': level2.toJson(),
      'level3': level3.toJson(),
      'delimiterMode': delimiterMode,
      'anlageKuerzel': anlageKuerzel,
      'bauteilKuerzel': bauteilKuerzel,
      'useDisciplineGrouping': useDisciplineGrouping,
      'labelGewerk': labelGewerk,
      'labelAnlage': labelAnlage,
      'labelBauteil': labelBauteil,
      'attributeColumnPairs': pairView,
      'attributeTripletColumns':
          canon.attributeTripletColumns.map((t) => t.toJson()).toList(),
      'attributeStartColumn': attributeStartColumn,
      'attributeCount': attributeCount,
      'foto1SpalteLabel': foto1SpalteLabel,
      'foto2SpalteLabel': foto2SpalteLabel,
      'foto3SpalteLabel': foto3SpalteLabel,
      'foto4SpalteLabel': foto4SpalteLabel,
      'qrCodeNummerSpalteLabel': qrCodeNummerSpalteLabel,
      'importHeaderRow': importHeaderRow,
      'exportDelimiter': exportDelimiter,
      'groupingGewerkParamKey': groupingGewerkParamKey,
      'groupingAnlageParamKey': groupingAnlageParamKey,
      'displayNameParamKey': displayNameParamKey,
      'displayNameSpalte': displayNameSpalte,
      'listTitleInputFieldIndex': listTitleInputFieldIndex,
      'listSubtitleInputFieldIndex': listSubtitleInputFieldIndex,
    };
  }

  /// Deserialisiert aktuelle oder Legacy-JSON-Formate.
  factory CsvSettings.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('level1')) {
      return _fromNewJson(json);
    }
    return _migrateFromLegacyJson(json);
  }

  static CsvSettings _fromNewJson(Map<String, dynamic> json) {
    final pairsRaw = json['attributeColumnPairs'];
    final List<AttributeColumnPair> pairs = [];
    if (pairsRaw is List) {
      for (final e in pairsRaw) {
        if (e is Map<String, dynamic>) {
          pairs.add(AttributeColumnPair.fromJson(e));
        } else if (e is Map) {
          pairs.add(AttributeColumnPair.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final tripletsRaw = json['attributeTripletColumns'];
    final List<AttributeTripletColumn> triplets = [];
    if (tripletsRaw is List) {
      for (final e in tripletsRaw) {
        if (e is Map<String, dynamic>) {
          triplets.add(AttributeTripletColumn.fromJson(e));
        } else if (e is Map) {
          triplets.add(AttributeTripletColumn.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return canonicalizeAttributeMapping(
      CsvSettings(
        level1: HierarchyLevelConfig.fromJson(
          json['level1'] is Map
              ? Map<String, dynamic>.from(json['level1'] as Map)
              : null,
        ),
        level2: HierarchyLevelConfig.fromJson(
          json['level2'] is Map
              ? Map<String, dynamic>.from(json['level2'] as Map)
              : null,
        ),
        level3: HierarchyLevelConfig.fromJson(
          json['level3'] is Map
              ? Map<String, dynamic>.from(json['level3'] as Map)
              : null,
        ),
        delimiterMode: json['delimiterMode'] as String? ?? 'auto',
        anlageKuerzel: json['anlageKuerzel'] as String? ?? 'A,Anlage',
        bauteilKuerzel: json['bauteilKuerzel'] as String? ?? 'B,Bauteil',
        useDisciplineGrouping: json['useDisciplineGrouping'] as bool? ?? true,
        labelGewerk: json['labelGewerk'] as String? ?? 'Gewerk',
        labelAnlage: json['labelAnlage'] as String? ?? 'Anlage',
        labelBauteil: json['labelBauteil'] as String? ?? 'Bauteil',
        attributeColumnPairs: pairs,
        attributeTripletColumns: triplets,
        attributeStartColumn: json['attributeStartColumn'] as int?,
        attributeCount: json['attributeCount'] as int?,
        foto1SpalteLabel: json['foto1SpalteLabel'] as String?,
        foto2SpalteLabel: json['foto2SpalteLabel'] as String?,
        foto3SpalteLabel: json['foto3SpalteLabel'] as String?,
        foto4SpalteLabel: json['foto4SpalteLabel'] as String?,
        qrCodeNummerSpalteLabel: json['qrCodeNummerSpalteLabel'] as String?,
        importHeaderRow: _parseStringList(json['importHeaderRow']),
        exportDelimiter: json['exportDelimiter'] as String? ?? ';',
        groupingGewerkParamKey: json['groupingGewerkParamKey'] as String? ?? '',
        groupingAnlageParamKey: json['groupingAnlageParamKey'] as String? ?? '',
        displayNameParamKey: json['displayNameParamKey'] as String? ?? 'Name',
        displayNameSpalte: json['displayNameSpalte'] as int?,
        listTitleInputFieldIndex: json['listTitleInputFieldIndex'] as int? ?? 1,
        listSubtitleInputFieldIndex:
            json['listSubtitleInputFieldIndex'] as int? ??
                ((json['listSubtitleParamKey'] as String?)?.trim().isNotEmpty ==
                        true
                    ? 2
                    : 0),
      ),
    );
  }

  static CsvSettings _migrateFromLegacyJson(Map<String, dynamic> json) {
    final gewerk = json['gewerkSpalte'] as int? ?? 2;
    final name = json['nameSpalte'] as int? ?? 1;
    final lfd = json['lfdNummerSpalte'] as int? ?? 0;
    final anlageEbene = json['anlageEbeneSpalte'] as int?;
    final useDiscipline = json['useDisciplineGrouping'] as bool? ?? true;

    final HierarchyLevelConfig l1;
    final HierarchyLevelConfig l2;
    final HierarchyLevelConfig l3;

    if (anlageEbene != null && anlageEbene != name) {
      l1 = HierarchyLevelConfig(enabled: useDiscipline, nameColumn: gewerk);
      l2 = HierarchyLevelConfig(enabled: true, nameColumn: anlageEbene);
      l3 = HierarchyLevelConfig(
        enabled: true,
        nameColumn: name,
        useIdColumn: true,
        idColumn: lfd,
      );
    } else {
      l1 = HierarchyLevelConfig(enabled: useDiscipline, nameColumn: gewerk);
      l2 = const HierarchyLevelConfig(enabled: false, nameColumn: 1);
      l3 = HierarchyLevelConfig(
        enabled: true,
        nameColumn: name,
        useIdColumn: true,
        idColumn: lfd,
      );
    }

    return _fromNewJson({
      ...json,
      'level1': l1.toJson(),
      'level2': l2.toJson(),
      'level3': l3.toJson(),
    });
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).toList();
  }

  /// Lädt projektbezogene CSV-Einstellungen (SharedPreferences → Defaults).
  static Future<CsvSettings> loadForProject(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('csv_settings_$projectId');
      CsvSettings settings;
      if (raw != null && raw.trim().isNotEmpty) {
        settings = CsvSettings.fromJson(
          Map<String, dynamic>.from(json.decode(raw) as Map),
        );
      } else {
        settings = CsvSettings.defaults();
      }
      return _migrateLegacyTemplateCsvSettings(prefs, projectId, settings);
    } catch (e) {
      appLog('CsvSettings.loadForProject fehlgeschlagen', error: e);
    }
    return CsvSettings.defaults();
  }

  /// Speichert projektbezogene CSV-Einstellungen (eine Schreib-API für Prefs).
  static Future<void> saveForProject(
    String projectId,
    CsvSettings settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final canon = canonicalizeAttributeMapping(settings);
    await prefs.setString(
      'csv_settings_$projectId',
      json.encode(canon.toJson()),
    );
  }

  /// Speichert die Import-Headerzeile (Anlagen- und Gewerkevorlagen-CSV).
  static Future<void> saveImportHeaderRowForProject(
    String projectId,
    List<String> headerRow,
  ) async {
    final current = await loadForProject(projectId);
    await saveForProject(
      projectId,
      current.copyWith(importHeaderRow: headerRow),
    );
  }

  /// Übernimmt Header/Triplets aus alter `template_csv_settings_*`-Prefs-Key.
  static Future<CsvSettings> _migrateLegacyTemplateCsvSettings(
    SharedPreferences prefs,
    String projectId,
    CsvSettings settings,
  ) async {
    final legacyKey = 'template_csv_settings_$projectId';
    final legacyRaw = prefs.getString(legacyKey);
    if (legacyRaw == null || legacyRaw.trim().isEmpty) return settings;

    try {
      final legacy = Map<String, dynamic>.from(json.decode(legacyRaw) as Map);
      var updated = settings;

      final legacyHeader = _parseStringList(legacy['importHeaderRow']);
      if (legacyHeader.isNotEmpty && settings.importHeaderRow.isEmpty) {
        updated = updated.copyWith(importHeaderRow: legacyHeader);
      }

      if (settings.attributeTripletColumns.isEmpty) {
        final tripletsRaw = legacy['attributeTripletColumns'];
        if (tripletsRaw is List && tripletsRaw.isNotEmpty) {
          final triplets = <AttributeTripletColumn>[];
          for (final e in tripletsRaw) {
            if (e is Map<String, dynamic>) {
              triplets.add(AttributeTripletColumn.fromJson(e));
            } else if (e is Map) {
              triplets.add(
                AttributeTripletColumn.fromJson(Map<String, dynamic>.from(e)),
              );
            }
          }
          if (triplets.isNotEmpty) {
            updated = updated.copyWith(attributeTripletColumns: triplets);
          }
        }
      }

      if (updated != settings) {
        await saveForProject(projectId, updated);
      }
      await prefs.remove(legacyKey);
      return updated;
    } catch (e) {
      appLog('Legacy CSV-Settings Migration fehlgeschlagen', error: e);
      return settings;
    }
  }
}
