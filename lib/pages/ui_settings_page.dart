import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/projects_provider.dart';
import '../providers/database_provider.dart';

class UISettingsPage extends ConsumerStatefulWidget {
  const UISettingsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<UISettingsPage> createState() => _UISettingsPageState();
}

class _UISettingsPageState extends ConsumerState<UISettingsPage> {
  List<String> _availableKeys = ['Bezeichnung'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableKeys();
  }

  Future<void> _loadAvailableKeys() async {
    final projectsState = ref.read(projectsProvider);
    final selectedBuilding = projectsState.selectedBuilding;

    if (selectedBuilding == null) {
      setState(() {
        _availableKeys = ['Bezeichnung'];
        _isLoading = false;
      });
      return;
    }

    try {
      final dbService = ref.read(databaseServiceProvider);
      final disciplines = await dbService.getDisciplinesByBuildingId(selectedBuilding.id);

      final Set<String> keySet = {'Bezeichnung'}; // Bezeichnung ist immer verfügbar

      // Sammle alle Keys aus allen Disziplin-Schemas
      for (final discipline in disciplines) {
        for (final schemaEntry in discipline.schema) {
          final key = schemaEntry['key']?.toString();
          if (key != null && key.isNotEmpty) {
            keySet.add(key);
          }
          // Auch 'label' als Fallback, falls 'key' nicht vorhanden
          final label = schemaEntry['label']?.toString();
          if (label != null && label.isNotEmpty && !keySet.contains(label)) {
            keySet.add(label);
          }
        }
      }

      // Spezielle Keys hinzufügen, die häufig verwendet werden
      keySet.add('Anlage/Bauteil');
      keySet.add('Anlage/Bautel');

      setState(() {
        _availableKeys = keySet.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fehler beim Laden der verfügbaren Keys: $e');
      setState(() {
        _availableKeys = ['Bezeichnung', 'Hersteller', 'Anlage/Bauteil', 'Typ'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiSettings = ref.watch(uiSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'UI Einstellungen',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAvailableKeys();
            },
            tooltip: 'Eingabefelder aktualisieren',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                _buildInfoCard(
                  'Hier kannst du festlegen, welche Informationen in der Anlagenliste primär angezeigt werden sollen. Die verfügbaren Felder basieren auf den Eingabefeldern aus den CSV-Einstellungen.',
                ),
                const SizedBox(height: 24),
                _buildDropdownSection(
                  context,
                  ref,
                  title: 'Hauptzeile (Überschrift)',
                  subtitle: 'Dieser Wert wird fettgedruckt oben angezeigt.',
                  currentValue: uiSettings.titleKey,
                  items: _availableKeys,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(uiSettingsProvider.notifier).setTitleKey(val);
                    }
                  },
                  icon: Icons.title,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildDropdownSection(
                  context,
                  ref,
                  title: 'Zweite Zeile (Untertitel)',
                  subtitle: 'Dieser Wert wird kleiner darunter angezeigt.',
                  currentValue: uiSettings.subtitleKey,
                  items: _availableKeys,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(uiSettingsProvider.notifier).setSubtitleKey(val);
                    }
                  },
                  icon: Icons.subtitles,
                  color: Colors.orange,
                ),
                const SizedBox(height: 32),
                _buildPreviewCard(uiSettings),
                if (_availableKeys.length <= 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildInfoCard(
                      'Hinweis: Es wurden noch keine Eingabefelder in den CSV-Einstellungen definiert. Bitte konfiguriere zuerst die Eingabefelder in den Anlagen-Einstellungen.',
                      isWarning: true,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildInfoCard(String text, {bool isWarning = false}) {
    final color = isWarning ? Colors.orange : Colors.blue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
            color: color[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color[900], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required String currentValue,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    required Color color,
  }) {
    // Falls der aktuelle Wert nicht in der Liste ist, füge ihn hinzu
    final List<String> dropdownItems = List.from(items);
    if (!dropdownItems.contains(currentValue)) {
      dropdownItems.add(currentValue);
      dropdownItems.sort();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
              items: dropdownItems.map((String key) {
                return DropdownMenuItem<String>(
                  value: key,
                  child: Row(
                    children: [
                      Icon(icon, color: color.withOpacity(0.7), size: 18),
                      const SizedBox(width: 12),
                      Text(key, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(UISettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'VORSCHAU',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.settings_input_component, color: Colors.blue[400]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Beispiel Anlage 123',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${settings.subtitleKey}: Wert der Anlage',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

