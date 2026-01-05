import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PhotoManager {
  static const int maxPhotos = 4;
  List<File> _imageFiles = [];

  List<File> get images => _imageFiles;
  
  bool get canAddPhoto => _imageFiles.length < maxPhotos;
  int get remainingPhotoSlots => maxPhotos - _imageFiles.length;

  Future<bool> takePhoto() async {
    if (_imageFiles.length >= maxPhotos) {
      return false; // Limit erreicht
    }
    
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) {
      if (_imageFiles.length < maxPhotos) {
        _imageFiles.add(File(picked.path));
        return true;
      }
      return false;
    }
    return false;
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
