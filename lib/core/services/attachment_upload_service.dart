import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/models/message_attachment.dart';

class AttachmentUploadService {
  AttachmentUploadService({
    FirebaseStorage? storage,
    ImagePicker? picker,
    FirebaseAuth? auth,
  }) : _storage = storage ?? FirebaseStorage.instance,
       _picker = picker ?? ImagePicker(),
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseStorage _storage;
  final ImagePicker _picker;
  final FirebaseAuth _auth;

  static const String uploaderMetadataKey = 'uploaderUid';

  static const Duration uploadTimeout = Duration(minutes: 3);

  static const double _imageMaxDimension = 1920;
  static const int _imageQuality = 85;

  Future<PickedAttachment?> pickFromCamera() async {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _imageMaxDimension,
      maxHeight: _imageMaxDimension,
      imageQuality: _imageQuality,
    );
    if (shot == null) return null;
    return _fromXFile(shot);
  }

  Future<PickedAttachment?> pickFromGallery() async {
    final shot = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _imageMaxDimension,
      maxHeight: _imageMaxDimension,
      imageQuality: _imageQuality,
    );
    if (shot == null) return null;
    return _fromXFile(shot);
  }

  Future<PickedAttachment?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AttachmentPolicy.allowedPickerExtensions,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      debugPrint('⚠️ file_picker returned no bytes for ${file.name}');
      return null;
    }

    final fileName = AttachmentPolicy.sanitizeFileName(file.name);
    return PickedAttachment(
      fileName: fileName,
      bytes: bytes,
      mimeType: AttachmentPolicy.resolveMimeType(fileName: fileName),
    );
  }

  Future<PickedAttachment> _fromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final fileName = AttachmentPolicy.sanitizeFileName(
      file.name.isEmpty
          ? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : file.name,
    );
    final mimeType = AttachmentPolicy.resolveMimeType(
      reported: file.mimeType,
      fileName: fileName,
    );
    return PickedAttachment(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  AttachmentUpload startUpload({
    required String basePath,
    required PickedAttachment picked,
  }) {
    final storagePath = '$basePath/${picked.fileName}';
    final ref = _storage.ref().child(storagePath);

    final task = ref.putData(
      picked.bytes,
      SettableMetadata(
        contentType: picked.mimeType,
        customMetadata: {
          'originalName': picked.fileName,
          uploaderMetadataKey: _auth.currentUser?.uid ?? '',
        },
      ),
    );

    final done = () async {
      TaskSnapshot snapshot;
      try {
        snapshot = await task.timeout(uploadTimeout);
      } on TimeoutException {
        try {
          await task.cancel();
        } catch (e) {
          debugPrint('⚠️ could not cancel timed-out upload $storagePath: $e');
        }
        rethrow;
      }
      final url = await snapshot.ref.getDownloadURL();
      final size = snapshot.totalBytes > 0
          ? snapshot.totalBytes
          : picked.bytes.length;
      final dimensions = picked.isImage
          ? await _decodeDimensions(picked.bytes)
          : null;
      return MessageAttachment(
        url: url,
        storagePath: storagePath,
        mimeType: picked.mimeType,
        sizeBytes: size,
        fileName: picked.fileName,
        width: dimensions?.$1,
        height: dimensions?.$2,
      );
    }();

    return AttachmentUpload._(
      task: task,
      done: done,
      storagePath: storagePath,
      fileName: picked.fileName,
      sizeBytes: picked.bytes.length,
      isImage: picked.isImage,
    );
  }

  Future<void> deleteQuietly(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      await _storage.ref().child(storagePath).delete();
    } catch (e) {
      debugPrint('⚠️ could not delete orphaned attachment $storagePath: $e');
    }
  }

  static Future<(int, int)?> _decodeDimensions(Uint8List bytes) async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = (frame.image.width, frame.image.height);
      frame.image.dispose();
      return size;
    } catch (e) {
      debugPrint('ℹ️ could not decode attachment dimensions: $e');
      return null;
    } finally {
      codec?.dispose();
    }
  }
}

class PickedAttachment {
  final String fileName;
  final Uint8List bytes;
  final String mimeType;

  const PickedAttachment({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  bool get isImage => AttachmentPolicy.isImageMimeType(mimeType);

  int get sizeBytes => bytes.length;

  String? get validationError => AttachmentPolicy.validate(
    fileName: fileName,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
  );
}

class AttachmentUpload {
  AttachmentUpload._({
    required UploadTask task,
    required this.done,
    required this.storagePath,
    required this.fileName,
    required this.sizeBytes,
    required this.isImage,
  }) : _task = task;

  final UploadTask _task;

  final Future<MessageAttachment> done;

  final String storagePath;
  final String fileName;
  final int sizeBytes;
  final bool isImage;

  Stream<double> get progress => _task.snapshotEvents.map((snapshot) {
    if (snapshot.totalBytes <= 0) return 0.0;
    final ratio = snapshot.bytesTransferred / snapshot.totalBytes;
    return ratio.clamp(0.0, 1.0).toDouble();
  });

  Future<void> cancel() async {
    try {
      await _task.cancel();
    } catch (e) {
      debugPrint('⚠️ upload cancel failed for $storagePath: $e');
    }
  }

  bool get isCancelled => _task.snapshot.state == TaskState.canceled;
}

bool isUploadCancellation(Object error) =>
    error is FirebaseException && error.code == 'canceled';
