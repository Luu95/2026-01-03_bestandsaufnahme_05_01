import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
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
              color: Colors.indigo,
              borderColor: Colors.indigo.withOpacity(0.25),
              icon: Icons.dark_mode_outlined,
              iconColor: Colors.indigo[700]!,
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
          ],
        ),
      ),
    );
  }
}
