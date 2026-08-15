/// Verwaltet bis zu [maxPhotos] Anlagenfotos (Kamera/Galerie) mit Sandbox-Persistenz.

import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'package:bestandsaufnahme_01/core/utils/photo_file_utils.dart';

/// Foto-Liste für Anlagen- und Marker-Dialoge (max. 4 Bilder).
class PhotoManager {
  static const int maxPhotos = 4;
  List<File> _imageFiles = [];

  List<File> get images => _imageFiles;

  bool get canAddPhoto => _imageFiles.length < maxPhotos;
  int get remainingPhotoSlots => maxPhotos - _imageFiles.length;

  Future<bool> takePhoto() => _pickAndPersist(ImageSource.camera);

  /// Galerie-Auswahl mit derselben Sandbox-Persistenz wie Kamera.
  Future<bool> pickFromGallery() => _pickAndPersist(ImageSource.gallery);

  /// Aufnehmen/Auswählen und dauerhaft in die App-Documents kopieren.
  Future<bool> _pickAndPersist(ImageSource source) async {
    if (_imageFiles.length >= maxPhotos) {
      return false;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return false;
    if (_imageFiles.length >= maxPhotos) return false;

    final persisted = await persistPickedImageToDocuments(
      picked.path,
      prefix: source == ImageSource.camera ? 'camera' : 'gallery',
    );
    _imageFiles.add(persisted);
    return true;
  }

  void removeImage(int index) {
    _imageFiles.removeAt(index);
  }

  Future<void> viewImage(File image) async {
    // Hier kannst du die Ansicht implementieren, wenn du das Bild vergrößern willst
    // z.B. mit einem Dialog oder einer neuen Seite
  }

  void updateImageFiles(List<File> newImages) {
    // Begrenze auf maximal 4 Fotos
    if (newImages.length > maxPhotos) {
      _imageFiles = newImages.sublist(0, maxPhotos);
    } else {
      _imageFiles = newImages;
    }
  }
}
