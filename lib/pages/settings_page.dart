import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui_settings_page.dart';
import 'csv_settings_page.dart';
import '../providers/projects_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsState = ref.watch(projectsProvider);
    
    // Versuche das aktuelle Projekt und Gebäude zu finden
    String? projectId;
    String? buildingId;
    
    final selectedProject = projectsState.selectedProject;
    final selectedBuilding = projectsState.selectedBuilding;
    
    if (selectedProject != null) {
      projectId = selectedProject.id;
      if (selectedBuilding != null) {
        buildingId = selectedBuilding.id;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Einstellungen',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _buildSettingsSection(
            context,
            title: 'App-Oberfläche',
            items: [
              _SettingsItem(
                icon: Icons.palette_outlined,
                title: 'UI Einstellungen',
                subtitle: 'Überschrift und Untertitel in der Anlagenliste anpassen',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const UISettingsPage()),
                  );
                },
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (projectId != null && buildingId != null)
            _buildSettingsSection(
              context,
              title: 'CSV',
              items: [
                _SettingsItem(
                  icon: Icons.settings_rounded,
                  title: 'CSV-Einstellungen',
                  subtitle: 'Spalten-Mapping und Import-Einstellungen',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CsvSettingsPage(
                          projectId: projectId!,
                          buildingId: buildingId!,
                        ),
                      ),
                    );
                  },
                  color: Colors.purple,
                ),
              ],
            ),
          if (projectId != null && buildingId != null) const SizedBox(height: 24),
          _buildSettingsSection(
            context,
            title: 'Allgemein',
            items: [
              _SettingsItem(
                icon: Icons.info_outline,
                title: 'Über die App',
                subtitle: 'Version 1.0.0',
                onTap: () {
                  // TODO: Info Dialog
                },
                color: Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, {required String title, required List<_SettingsItem> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color, size: 24),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                    onTap: item.onTap,
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 64, color: Colors.grey[100]),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });
}

