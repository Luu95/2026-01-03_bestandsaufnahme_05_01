import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../theme/app_palette.dart';
import 'widgets/settings_card.dart';

class AppSettingsPage extends ConsumerWidget {
  final String? projectId;
  final String? buildingId;

  const AppSettingsPage({
    super.key,
    this.projectId,
    this.buildingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Allgemeine Einstellungen',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App-weite Einstellungen',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            SettingsCard(
              color: AppPalette.primary,
              borderColor: AppPalette.primary.withOpacity(0.25),
              icon: Icons.dark_mode_outlined,
              iconColor: AppPalette.primaryDark,
              title: 'Erscheinungsbild',
              description: 'Helles, dunkles Design oder automatisch nach Systemeinstellung.',
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Hell'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dunkel'),
                    icon: Icon(Icons.dark_mode),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) {
                  ref.read(settingsProvider.notifier).setThemeMode(selection.first);
                },
              ),
            ),
            const SizedBox(height: 16),
            SettingsCard(
              color: AppPalette.primary,
              borderColor: AppPalette.primary.withOpacity(0.25),
              icon: Icons.history,
              iconColor: AppPalette.primaryDark,
              title: 'Anlagenliste',
              description:
                  'Steuert die Hervorhebung in der Übersicht der Anlagen.',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Zuletzt geöffnete Anlage markieren'),
                subtitle: const Text(
                  'Hebt die zuletzt aufgerufene Anlage visuell hervor',
                ),
                value: settings.highlightLastOpenedAnlage,
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setHighlightLastOpenedAnlage(value);
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Beta-Funktionen',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            SettingsCard(
              color: AppPalette.warning,
              borderColor: AppPalette.warningBorder,
              icon: Icons.document_scanner_outlined,
              iconColor: AppPalette.warningText,
              title: 'Typenschild-OCR',
              description:
                  'Scannt Typenschilder per Kamera und übernimmt erkannte Daten in die Anlagefelder.',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Typenschild-OCR aktivieren'),
                subtitle: const Text('Experimentelle Funktion – noch nicht freigegeben'),
                value: settings.typenschildOcrEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setTypenschildOcrEnabled(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
