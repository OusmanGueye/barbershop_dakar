import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../config/supabase_config.dart';

class UploadService {
  final _supabase = SupabaseConfig.client;
  final ImagePicker _picker = ImagePicker();

  Future<String?> uploadAvatar() async {
    try {
      // 1. Sélectionner l'image
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image == null) return null;

      // 2. Lire et compresser l'image
      final bytes = await image.readAsBytes();
      final compressedBytes = await _compressImage(bytes);

      // 3. Générer un nom unique
      final userId = SupabaseConfig.client.auth.currentUser?.id;

      if (userId == null) throw Exception('User not logged in');

      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 4. Upload la photo (SANS FileOptions qui n'existe plus)
      await _supabase.storage
          .from('avatars')
          .uploadBinary(
        fileName,
        compressedBytes,
      );

      // 5. Obtenir l'URL publique
      final publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // 6. Mettre à jour le profil utilisateur
      await _supabase
          .from('users')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);

      return publicUrl;
    } catch (e) {
      print('Erreur upload avatar: $e');
      return null;
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Redimensionner si trop grande
    final resized = img.copyResize(
      image,
      width: image.width > 800 ? 800 : image.width,
    );

    // Compresser en JPEG avec qualité 80%
    return Uint8List.fromList(
      img.encodeJpg(resized, quality: 80),
    );
  }

  Future<String?> uploadBarbershopPhoto(String barbershopId, File photo) async {
    try {
      final fileName = 'barbershop_${barbershopId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'barbershops/$barbershopId/$fileName';

      await _supabase.storage
          .from('barbershop-photos')
          .upload(path, photo);

      final url = _supabase.storage
          .from('barbershop-photos')
          .getPublicUrl(path);

      return url;
    } catch (e) {
      print('Erreur upload photo barbershop: $e');
      return null;
    }
  }

}
