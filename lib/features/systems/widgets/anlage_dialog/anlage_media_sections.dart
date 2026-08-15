/// Foto- und QR-Abschnitte im Anlagen-Dialog.
///
/// Nur Darstellung + Callbacks; Speichern/Scannen bleibt in [GenericAnlageDialog].

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';
import 'package:bestandsaufnahme_01/features/media/widgets/photo_manager.dart';

/// QR-Code-Nummern-Feld inkl. Scan-Button.
class AnlageQrCodeSection extends StatelessWidget {
  final AnlageFormTheme theme;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onScan;

  const AnlageQrCodeSection({
    super.key,
    required this.theme,
    required this.controller,
    required this.onChanged,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final ft = theme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ft.sectionBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ft.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ft.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.qr_code_2,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'QR-Code Nummer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ft.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: ft.innerFieldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ft.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.text,
                        style: TextStyle(fontSize: 15, color: ft.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Nummer manuell eingeben oder scannen',
                          hintStyle:
                              TextStyle(color: ft.textHint, fontSize: 14),
                          border: InputBorder.none,
                        ),
                        onChanged: onChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: onScan,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .primaryColor
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.qr_code_scanner,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto-Galerie mit Hinzufügen / Anzeigen / Löschen.
class AnlagePhotoSection extends StatelessWidget {
  final AnlageFormTheme theme;
  final PhotoManager photoManager;
  final VoidCallback onAddPhoto;
  final void Function(File image) onViewImage;
  final void Function(int index) onRemoveImage;

  const AnlagePhotoSection({
    super.key,
    required this.theme,
    required this.photoManager,
    required this.onAddPhoto,
    required this.onViewImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    final ft = theme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ft.sectionBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ft.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ft.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.photo_library,
                        color: AppPalette.primaryDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Fotos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ft.textPrimary,
                          ),
                        ),
                        Text(
                          '${photoManager.images.length}/${PhotoManager.maxPhotos}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: ft.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: photoManager.canAddPhoto
                        ? Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.12)
                        : ft.chipDisabledBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: photoManager.canAddPhoto ? onAddPhoto : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              color: photoManager.canAddPhoto
                                  ? Theme.of(context).primaryColor
                                  : ft.iconMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Hinzufügen',
                              style: TextStyle(
                                color: photoManager.canAddPhoto
                                    ? Theme.of(context).primaryColor
                                    : ft.iconMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (photoManager.images.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: ft.photoEmptyBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ft.borderSubtle,
                    style: BorderStyle.solid,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_outlined,
                        size: 48,
                        color: ft.iconMuted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Noch keine Fotos',
                        style: TextStyle(
                          color: ft.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (photoManager.images.isNotEmpty)
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photoManager.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) {
                    final f = photoManager.images[i];
                    return RepaintBoundary(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            GestureDetector(
                              onTap: () => onViewImage(f),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  f,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  cacheWidth: 220,
                                  cacheHeight: 220,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => onRemoveImage(i),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: ft.scaffold,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: ft.shadow,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: AppPalette.error,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
