import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Mapping: Verschiedene Bezeichnungen für dasselbe Feld
  static final Map<String, List<String>> _fieldMappings = {
    'hersteller': [
      'hersteller', 'manufacturer', 'fabrikat', 'marke', 'firma', 
      'firmenname', 'produzent', 'erzeuger'
    ],
    'typ': [
      'typ', 'type', 'modell', 'model', 'bezeichnung', 'artikelnummer',
      'art-nr', 'artnr', 'seriennummer', 'serie', 'baureihe'
    ],
    'baujahr': [
      'baujahr', 'year', 'jahr', 'jahrgang', 'herstellungsjahr',
      'produktionsjahr', 'fertigungsjahr'
    ],
    'leistung': [
      'leistung', 'power', 'nennleistung', 'rated power', 'kw', 'watt',
      'w', 'leistung in kw', 'nennleistung kw'
    ],
    'volumenstrom': [
      'volumenstrom', 'airflow', 'luftmenge', 'volumen', 'm³/h', 
      'm3/h', 'luftvolumen', 'durchsatz'
    ],
    'energieverbrauch': [
      'energieverbrauch', 'energy consumption', 'verbrauch', 'kwh',
      'stromverbrauch', 'power consumption'
    ],
    'brennstoff': [
      'brennstoff', 'fuel', 'brennstofftyp', 'fuel type', 'energieträger'
    ],
    'cop': [
      'cop', 'leistungszahl', 'coefficient of performance'
    ],
    'temperaturbereich': [
      'temperaturbereich', 'temperature range', 'temp. bereich',
      'temperatur', 'temperature'
    ],
    'filtertyp': [
      'filtertyp', 'filter type', 'filter', 'filterklasse'
    ],
    'kapazitaet': [
      'kapazität', 'kapazitaet', 'capacity', 'inhalt', 'volumen',
      'speicherkapazität', 'speicherkapazitaet'
    ],
    'betriebsstunden': [
      'betriebsstunden', 'operating hours', 'laufstunden', 'laufzeit'
    ],
  };

  // Einheiten-Mappings für numerische Werte
  static final Map<String, List<String>> _unitMappings = {
    'leistung': ['kw', 'w', 'watt', 'kilowatt'],
    'volumenstrom': ['m³/h', 'm3/h', 'm³', 'm3'],
    'energieverbrauch': ['kwh', 'wh', 'kwh/a', 'kwh/jahr'],
    'kapazitaet': ['l', 'liter', 'm³', 'm3'],
    'temperaturbereich': ['°c', 'c', 'grad', 'kelvin'],
  };

  /// Hauptfunktion: Erkennt Typenschild-Daten mit verbesserter Logik
  static Future<Map<String, String>> recognizeTypenschild(File imageFile) async {
    debugPrint('=== OCR SERVICE: Starte Typenschild-Erkennung ===');
    debugPrint('Bild: ${imageFile.path}');
    
    final InputImage inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    // DEBUG: Vollständiger roher Text
    debugPrint('\n--- ROHER OCR-TEXT ---');
    debugPrint(recognizedText.text);
    debugPrint('--- ENDE ROHER TEXT ---\n');

    // DEBUG: Struktur analysieren
    _debugTextStructure(recognizedText);

    Map<String, String> results = {};

    // Strategie 1: Geografische Positionssuche (neu - für Tabellen)
    debugPrint('\n=== STRATEGIE 1: Geografische Positionssuche ===');
    final geoResults = _extractWithGeographicSearch(recognizedText);
    debugPrint('Ergebnisse: $geoResults');
    results.addAll(geoResults);

    // Strategie 2: Block-basierte Erkennung (nutzt Struktur)
    debugPrint('\n=== STRATEGIE 2: Block-basierte Erkennung ===');
    final blockResults = _extractFromBlocks(recognizedText);
    debugPrint('Ergebnisse: $blockResults');
    // Nur hinzufügen, wenn noch nicht vorhanden
    blockResults.forEach((key, value) {
      if (!results.containsKey(key)) {
        results[key] = value;
      }
    });

    // Strategie 3: Regex-basierte Erkennung (Fallback)
    debugPrint('\n=== STRATEGIE 3: Regex-basierte Erkennung ===');
    final fullText = recognizedText.text.toLowerCase();
    final regexResults = _extractWithRegex(fullText);
    debugPrint('Ergebnisse: $regexResults');
    // Nur hinzufügen, wenn noch nicht vorhanden
    regexResults.forEach((key, value) {
      if (!results.containsKey(key)) {
        results[key] = value;
      }
    });

    // Strategie 4: Kontextuelle Erkennung
    debugPrint('\n=== STRATEGIE 4: Kontextuelle Erkennung ===');
    final contextualResults = _extractContextual(recognizedText);
    debugPrint('Ergebnisse: $contextualResults');
    // Nur hinzufügen, wenn noch nicht vorhanden
    contextualResults.forEach((key, value) {
      if (!results.containsKey(key)) {
        results[key] = value;
      }
    });

    // Post-Processing: Bereinigung und Validierung
    debugPrint('\n=== POST-PROCESSING: Bereinigung und Validierung ===');
    debugPrint('Vorher: $results');
    final cleaned = _cleanAndValidate(results);
    debugPrint('Nachher: $cleaned');

    debugPrint('\n=== FINALE ERGEBNISSE ===');
    debugPrint('Erkannte Felder: ${cleaned.keys.toList()}');
    cleaned.forEach((key, value) {
      debugPrint('  $key: "$value"');
    });
    debugPrint('=== ENDE OCR SERVICE ===\n');

    return cleaned;
  }

  /// DEBUG: Analysiert die Textstruktur
  static void _debugTextStructure(RecognizedText recognizedText) {
    debugPrint('\n--- TEXT-STRUKTUR ANALYSE ---');
    debugPrint('Anzahl Blöcke: ${recognizedText.blocks.length}');
    
    for (int blockIdx = 0; blockIdx < recognizedText.blocks.length; blockIdx++) {
      final block = recognizedText.blocks[blockIdx];
      debugPrint('\nBlock $blockIdx:');
      debugPrint('  Text: "${block.text}"');
      debugPrint('  BoundingBox: ${block.boundingBox}');
      debugPrint('  Anzahl Zeilen: ${block.lines.length}');
      
      for (int lineIdx = 0; lineIdx < block.lines.length; lineIdx++) {
        final line = block.lines[lineIdx];
        debugPrint('  Zeile $lineIdx:');
        debugPrint('    Text: "${line.text}"');
        debugPrint('    BoundingBox: left=${line.boundingBox.left.toStringAsFixed(1)}, top=${line.boundingBox.top.toStringAsFixed(1)}, right=${line.boundingBox.right.toStringAsFixed(1)}, bottom=${line.boundingBox.bottom.toStringAsFixed(1)}');
        debugPrint('    Höhe: ${line.boundingBox.height.toStringAsFixed(1)}');
      }
    }
    debugPrint('--- ENDE STRUKTUR ANALYSE ---\n');
  }

  /// NEU: Geografische Positionssuche - für Tabellen-Layouts
  static Map<String, String> _extractWithGeographicSearch(RecognizedText recognizedText) {
    Map<String, String> results = {};
    
    // Alle Zeilen mit ihren Positionen sammeln
    List<_TextLineWithBox> allLines = [];
    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        allLines.add(_TextLineWithBox(line.text, line.boundingBox));
      }
    }

    debugPrint('Gefundene Zeilen: ${allLines.length}');
    for (var line in allLines) {
      debugPrint('  "${line.text}" @ (${line.box.left.toStringAsFixed(1)}, ${line.box.top.toStringAsFixed(1)})');
    }

    // Für jedes Feld suchen
    for (var fieldKey in _fieldMappings.keys) {
      if (results.containsKey(fieldKey)) continue;
      
      debugPrint('\nSuche nach Feld: $fieldKey');
      
      for (var label in _fieldMappings[fieldKey]!) {
        debugPrint('  Prüfe Label: "$label"');
        
        // Suche Zeile mit diesem Label
        for (int i = 0; i < allLines.length; i++) {
          final currentLine = allLines[i];
          final text = currentLine.text.toLowerCase();
          
          if (text.contains(label)) {
            debugPrint('    ✓ Label gefunden in Zeile $i: "${currentLine.text}"');
            debugPrint('      Position: (${currentLine.box.left.toStringAsFixed(1)}, ${currentLine.box.top.toStringAsFixed(1)})');
            
            String? foundValue;
            String? foundMethod;
            
            // Check A: Wert in derselben Zeile rechts vom Label?
            final pattern = RegExp('$label\\s*[:\\s]+\\s*(.+)', caseSensitive: false);
            final match = pattern.firstMatch(currentLine.text);
            
            if (match != null) {
              final candidate = match.group(1)?.trim() ?? '';
              debugPrint('      Check A (gleiche Zeile): Kandidat "$candidate"');
              
              if (candidate.length > 1 && !_isAnotherLabel(candidate)) {
                foundValue = candidate;
                foundMethod = 'gleiche Zeile';
                debugPrint('      ✓ Akzeptiert als Wert');
              } else {
                debugPrint('      ✗ Abgelehnt (ist Label oder zu kurz)');
              }
            }

            // Check B: Geografisch rechts daneben (gleiche Y-Höhe, größere X-Position)
            if (foundValue == null) {
              debugPrint('      Check B (geografisch rechts):');
              String? foundRight;
              double minXDiff = double.infinity;

              for (int j = 0; j < allLines.length; j++) {
                if (i == j) continue;
                
                final otherLine = allLines[j];
                final yDiff = (otherLine.box.top - currentLine.box.top).abs();
                final tolerance = currentLine.box.height / 2;
                final xDiff = otherLine.box.left - currentLine.box.right;

                debugPrint('        Zeile $j: "${otherLine.text}"');
                debugPrint('          Y-Diff: ${yDiff.toStringAsFixed(1)}, Toleranz: ${tolerance.toStringAsFixed(1)}');
                debugPrint('          X-Diff: ${xDiff.toStringAsFixed(1)}');

                if (yDiff < tolerance && xDiff > -10 && xDiff < minXDiff) {
                  if (!_isAnotherLabel(otherLine.text)) {
                    foundRight = otherLine.text;
                    minXDiff = xDiff;
                    debugPrint('          ✓ Kandidat gefunden');
                  } else {
                    debugPrint('          ✗ Abgelehnt (ist Label)');
                  }
                }
              }

              if (foundRight != null) {
                foundValue = foundRight;
                foundMethod = 'geografisch rechts';
                debugPrint('      ✓ Wert gefunden rechts: "$foundRight"');
              } else {
                debugPrint('      ✗ Kein Wert rechts gefunden');
              }
            }

            // Check C: Direkt darunter (nur wenn rechts nichts gefunden)
            if (foundValue == null && i + 1 < allLines.length) {
              final nextLine = allLines[i + 1];
              final yDiff = nextLine.box.top - currentLine.box.bottom;
              final maxYDiff = currentLine.box.height * 1.5;
              
              debugPrint('      Check C (darunter):');
              debugPrint('        Nächste Zeile: "${nextLine.text}"');
              debugPrint('        Y-Diff: ${yDiff.toStringAsFixed(1)}, Max: ${maxYDiff.toStringAsFixed(1)}');
              
              if (yDiff < maxYDiff) {
                if (!_isAnotherLabel(nextLine.text)) {
                  foundValue = nextLine.text;
                  foundMethod = 'darunter';
                  debugPrint('        ✓ Wert gefunden darunter: "$foundValue"');
                } else {
                  debugPrint('        ✗ Abgelehnt (ist Label)');
                }
              } else {
                debugPrint('        ✗ Zu weit entfernt');
              }
            }

            if (foundValue != null) {
              // Einheiten entfernen
              final cleanedValue = _removeUnits(foundValue, fieldKey);
              if (cleanedValue.isNotEmpty) {
                results[fieldKey] = cleanedValue;
                debugPrint('    ✓✓✓ FELD ERKANNT: $fieldKey = "$cleanedValue" (Methode: $foundMethod)');
                break;
              } else {
                debugPrint('    ✗ Wert nach Einheiten-Entfernung leer');
              }
            } else {
              debugPrint('    ✗ Kein Wert gefunden für Label "$label"');
            }
          }
        }
        
        if (results.containsKey(fieldKey)) break;
      }
    }

    return results;
  }

  /// Hilfsfunktion: Ist der Text vielleicht selbst ein Label?
  static bool _isAnotherLabel(String text) {
    final lower = text.toLowerCase().trim();
    for (var labels in _fieldMappings.values) {
      for (var l in labels) {
        if (lower == l || lower.startsWith('$l:')) {
          debugPrint('        _isAnotherLabel: "$text" ist Label "$l"');
          return true;
        }
      }
    }
    return false;
  }

  /// Extrahiert Daten aus der Block-Struktur von MLKit
  static Map<String, String> _extractFromBlocks(RecognizedText recognizedText) {
    Map<String, String> results = {};
    
    for (final block in recognizedText.blocks) {
      final blockText = block.text.toLowerCase();
      debugPrint('Block: "${block.text}"');
      
      // Suche nach Label-Wert-Paaren in jedem Block
      for (final fieldKey in _fieldMappings.keys) {
        for (final label in _fieldMappings[fieldKey]!) {
          // Pattern: "Label: Wert" oder "Label Wert"
          final pattern = RegExp(
            '$label\\s*[:\\s]+\\s*([^\\n\\r]+)',
            caseSensitive: false,
          );
          
          final match = pattern.firstMatch(blockText);
          if (match != null && !results.containsKey(fieldKey)) {
            String value = match.group(1)?.trim() ?? '';
            debugPrint('  Gefunden: $fieldKey = "$value" (Label: $label)');
            // Entferne Einheiten am Ende
            value = _removeUnits(value, fieldKey);
            if (value.isNotEmpty) {
              results[fieldKey] = value;
            } else {
              debugPrint('  ✗ Wert nach Einheiten-Entfernung leer');
            }
          }
        }
      }
    }
    
    return results;
  }

  /// Regex-basierte Extraktion (Fallback)
  static Map<String, String> _extractWithRegex(String fullText) {
    Map<String, String> results = {};

    // Hersteller: Oft am Anfang oder nach "Hersteller"
    if (!results.containsKey('hersteller')) {
      debugPrint('Suche Hersteller...');
      for (final label in _fieldMappings['hersteller']!) {
        final pattern = RegExp('$label\\s*[:\\s]+\\s*([a-zäöüß\\s]+)', caseSensitive: false);
        final match = pattern.firstMatch(fullText);
        if (match != null) {
          final value = match.group(1)?.trim().toUpperCase() ?? '';
          debugPrint('  Gefunden via Regex: "$value" (Label: $label)');
          results['hersteller'] = value;
          break;
        }
      }
      
      // Fallback: Bekannte Hersteller-Marken erkennen
      if (!results.containsKey('hersteller')) {
        debugPrint('  Suche bekannte Marken...');
        final knownBrands = ['viessmann', 'buderus', 'vaillant', 'wolf', 'weishaupt', 
                            'junkers', 'brötje', 'stiebel eltron', 'eigenbau'];
        for (final brand in knownBrands) {
          if (fullText.contains(brand)) {
            debugPrint('  Gefunden bekannte Marke: $brand');
            results['hersteller'] = brand.toUpperCase();
            break;
          }
        }
      }
    }

    // Typ/Modell: Oft nach "Typ" oder als Produktnummer
    if (!results.containsKey('typ')) {
      debugPrint('Suche Typ...');
      for (final label in _fieldMappings['typ']!) {
        final pattern = RegExp('$label\\s*[:\\s]+\\s*([a-z0-9\\-\\s]+)', caseSensitive: false);
        final match = pattern.firstMatch(fullText);
        if (match != null) {
          final value = match.group(1)?.trim() ?? '';
          debugPrint('  Gefunden via Regex: "$value" (Label: $label)');
          results['typ'] = value;
          break;
        }
      }
    }

    // Baujahr: 4-stellige Jahreszahl
    if (!results.containsKey('baujahr')) {
      debugPrint('Suche Baujahr...');
      final yearPattern = RegExp(r'\b(19|20)\d{2}\b');
      final matches = yearPattern.allMatches(fullText);
      if (matches.isNotEmpty) {
        final year = matches.first.group(0) ?? '';
        debugPrint('  Gefunden via Regex: "$year"');
        results['baujahr'] = year;
      }
    }

    // Leistung: Zahl gefolgt von kW oder W
    if (!results.containsKey('leistung')) {
      debugPrint('Suche Leistung...');
      final powerPattern = RegExp(r'(\d+[\.,]?\d*)\s*(kw|w|watt|kilowatt)', caseSensitive: false);
      final match = powerPattern.firstMatch(fullText);
      if (match != null) {
        String value = match.group(1)?.replaceAll(',', '.') ?? '';
        // Konvertiere W zu kW falls nötig
        final unit = match.group(2)?.toLowerCase() ?? '';
        if (unit == 'w' || unit == 'watt') {
          final numValue = double.tryParse(value) ?? 0;
          value = (numValue / 1000).toString();
        }
        debugPrint('  Gefunden via Regex: "$value" $unit');
        results['leistung'] = value;
      }
    }

    // Volumenstrom: Zahl gefolgt von m³/h
    if (!results.containsKey('volumenstrom')) {
      debugPrint('Suche Volumenstrom...');
      final volumePattern = RegExp(r'(\d+[\.,]?\d*)\s*(m³/h|m3/h|m³|m3)', caseSensitive: false);
      final match = volumePattern.firstMatch(fullText);
      if (match != null) {
        final value = match.group(1)?.replaceAll(',', '.') ?? '';
        debugPrint('  Gefunden via Regex: "$value"');
        results['volumenstrom'] = value;
      }
    }

    // Energieverbrauch: Zahl gefolgt von kWh
    if (!results.containsKey('energieverbrauch')) {
      debugPrint('Suche Energieverbrauch...');
      final energyPattern = RegExp(r'(\d+[\.,]?\d*)\s*(kwh|wh)', caseSensitive: false);
      final match = energyPattern.firstMatch(fullText);
      if (match != null) {
        final value = match.group(1)?.replaceAll(',', '.') ?? '';
        debugPrint('  Gefunden via Regex: "$value"');
        results['energieverbrauch'] = value;
      }
    }

    return results;
  }

  /// Kontextuelle Extraktion: Nutzt räumliche Nähe von Labels und Werten
  static Map<String, String> _extractContextual(RecognizedText recognizedText) {
    Map<String, String> results = {};
    
    // Durchlaufe alle Textblöcke und suche nach benachbarten Label-Wert-Paaren
    for (final block in recognizedText.blocks) {
      final lines = block.text.split('\n');
      debugPrint('Kontextuelle Suche in ${lines.length} Zeilen');
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].toLowerCase().trim();
        
        // Suche nach Labels
        for (final fieldKey in _fieldMappings.keys) {
          if (results.containsKey(fieldKey)) continue;
          
          for (final label in _fieldMappings[fieldKey]!) {
            if (line.contains(label)) {
              debugPrint('  Label "$label" gefunden in Zeile $i: "$line"');
              // Wert könnte in derselben Zeile oder der nächsten sein
              String? value;
              
              // Versuche Wert aus derselben Zeile zu extrahieren
              final sameLinePattern = RegExp('$label\\s*[:\\s]+\\s*(.+)', caseSensitive: false);
              final sameLineMatch = sameLinePattern.firstMatch(line);
              if (sameLineMatch != null) {
                value = sameLineMatch.group(1)?.trim();
                debugPrint('    Wert in gleicher Zeile: "$value"');
              } else if (i + 1 < lines.length) {
                // Wert in nächster Zeile
                value = lines[i + 1].trim();
                debugPrint('    Wert in nächster Zeile: "$value"');
              }
              
              if (value != null && value.isNotEmpty) {
                value = _removeUnits(value, fieldKey);
                if (value.isNotEmpty) {
                  results[fieldKey] = value;
                  debugPrint('  ✓ Gefunden: $fieldKey = "$value"');
                }
              }
            }
          }
        }
      }
    }
    
    return results;
  }

  /// Entfernt Einheiten aus Werten
  static String _removeUnits(String value, String fieldKey) {
    String cleaned = value;
    if (_unitMappings.containsKey(fieldKey)) {
      for (final unit in _unitMappings[fieldKey]!) {
        final before = cleaned;
        cleaned = cleaned.replaceAll(RegExp('\\s*$unit\\s*', caseSensitive: false), '');
        if (before != cleaned) {
          debugPrint('    Einheit entfernt: "$unit" aus "$before" -> "$cleaned"');
        }
      }
    }
    return cleaned.trim();
  }

  /// Bereinigt und validiert die erkannten Werte
  static Map<String, String> _cleanAndValidate(Map<String, String> results) {
    final cleaned = <String, String>{};
    
    for (final entry in results.entries) {
      String value = entry.value.trim();
      debugPrint('Validiere: $entry.key = "$value"');
      
      // Entferne häufige OCR-Fehler
      value = value.replaceAll(RegExp(r'[|]'), 'I'); // | zu I
      
      // Validierung je nach Feldtyp
      switch (entry.key) {
        case 'baujahr':
          final year = int.tryParse(value);
          if (year != null && year >= 1900 && year <= 2100) {
            cleaned[entry.key] = value;
            debugPrint('  ✓ Gültiges Baujahr');
          } else {
            debugPrint('  ✗ Ungültiges Baujahr: $year');
          }
          break;
        case 'leistung':
        case 'volumenstrom':
        case 'energieverbrauch':
        case 'kapazitaet':
          // Numerische Werte: Wir lassen sie als Strings, aber bereinigen sie
          final numStr = value.replaceAll(',', '.');
          final num = double.tryParse(numStr);
          if (num != null && num > 0) {
            cleaned[entry.key] = numStr;
            debugPrint('  ✓ Gültiger numerischer Wert: $numStr');
          } else {
            debugPrint('  ✗ Ungültiger numerischer Wert: "$numStr"');
          }
          break;
        default:
          // String-Werte: Mindestens 2 Zeichen
          if (value.length >= 2) {
            cleaned[entry.key] = value;
            debugPrint('  ✓ Gültiger String-Wert');
          } else {
            debugPrint('  ✗ String zu kurz: "${value.length}" Zeichen');
          }
      }
    }
    
    return cleaned;
  }

  static void dispose() {
    _textRecognizer.close();
  }
}

/// Hilfsklasse für Textzeilen mit Bounding Box
class _TextLineWithBox {
  final String text;
  final Rect box;
  _TextLineWithBox(this.text, this.box);
}
