library;

import '../../core/constants/app_constants.dart';

enum AttachmentKind { image, document }

class MessageAttachment {
  final String url;

  final String storagePath;

  final String mimeType;
  final int sizeBytes;

  final String fileName;

  final int? width;
  final int? height;

  final String? thumbnailUrl;

  const MessageAttachment({
    required this.url,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.fileName,
    this.width,
    this.height,
    this.thumbnailUrl,
  });

  AttachmentKind get kind => AttachmentPolicy.isImageMimeType(mimeType)
      ? AttachmentKind.image
      : AttachmentKind.document;

  bool get isImage => kind == AttachmentKind.image;

  double? get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  String get readableSize {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get typeLabel {
    final dot = fileName.lastIndexOf('.');
    if (dot > 0 && dot < fileName.length - 1) {
      return fileName.substring(dot + 1).toUpperCase();
    }
    final slash = mimeType.lastIndexOf('/');
    if (slash >= 0 && slash < mimeType.length - 1) {
      return mimeType.substring(slash + 1).toUpperCase();
    }
    return 'קובץ';
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'storagePath': storagePath,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'fileName': fileName,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    };
  }

  static MessageAttachment? fromMap(Object? raw) {
    try {
      if (raw is! Map) return null;
      final url = raw['url'];
      final storagePath = raw['storagePath'];
      if (url is! String || url.isEmpty) return null;
      if (storagePath is! String || storagePath.isEmpty) return null;

      if (!AttachmentPolicy.isAllowedStoragePath(storagePath)) return null;
      if (!AttachmentPolicy.isTrustedAttachmentUrl(
        url,
        storagePath: storagePath,
      )) {
        return null;
      }

      final size = raw['sizeBytes'];
      final width = raw['width'];
      final height = raw['height'];
      final thumb = raw['thumbnailUrl'];
      final mime = raw['mimeType'];
      final name = raw['fileName'];

      return MessageAttachment(
        url: url,
        storagePath: storagePath,
        mimeType: mime is String && mime.isNotEmpty
            ? mime
            : 'application/octet-stream',
        sizeBytes: size is num && size.isFinite ? size.toInt() : 0,
        fileName: name is String && name.isNotEmpty ? name : 'קובץ',
        width: width is num && width.isFinite ? width.toInt() : null,
        height: height is num && height.isFinite ? height.toInt() : null,
        thumbnailUrl:
            thumb is String &&
                thumb.isNotEmpty &&
                AttachmentPolicy.isTrustedAttachmentUrl(thumb)
            ? thumb
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static List<MessageAttachment> listFromData(Object? raw) {
    if (raw is! List) return const [];
    final result = <MessageAttachment>[];
    for (final entry in raw) {
      final parsed = fromMap(entry);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  static List<Map<String, dynamic>> listToMaps(
    List<MessageAttachment> attachments,
  ) => attachments.map((a) => a.toMap()).toList();

  static String previewLabel(List<MessageAttachment> attachments) {
    if (attachments.isEmpty) return '';
    final allImages = attachments.every((a) => a.isImage);
    if (attachments.length == 1) {
      return allImages ? '📷 תמונה' : '📎 קובץ';
    }
    return allImages
        ? '📷 ${attachments.length} תמונות'
        : '📎 ${attachments.length} קבצים';
  }
}

class AttachmentPolicy {
  AttachmentPolicy._();

  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxDocumentBytes = 20 * 1024 * 1024;

  static const Set<String> allowedImageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  static const Set<String> allowedDocumentMimeTypes = {
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain',
    'text/csv',
  };

  static const List<String> allowedPickerExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'txt',
    'csv',
  ];

  static const Map<String, String> _mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt': 'text/plain',
    'csv': 'text/csv',
  };

  static const Set<String> bannedExtensions = {
    'exe',
    'msi',
    'bat',
    'cmd',
    'com',
    'scr',
    'pif',
    'cpl',
    'jar',
    'apk',
    'app',
    'dmg',
    'pkg',
    'deb',
    'rpm',
    'sh',
    'bash',
    'ps1',
    'psm1',
    'vbs',
    'vbe',
    'js',
    'jse',
    'wsf',
    'wsh',
    'hta',
    'reg',
    'dll',
    'so',
    'dylib',
    'bin',
    'run',
    'gadget',
    'lnk',
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
    'iso',
  };

  static const Set<String> allowedStorageHosts = {
    'firebasestorage.googleapis.com',
    AppConstants.storageBucket,
  };

  static const List<String> allowedStoragePathPrefixes = [
    'chat_attachments/',
    'ticket_attachments/',
    'review_photos/',
  ];

  static const String storageBucket = AppConstants.storageBucket;

  static bool isTrustedAttachmentUrl(String url, {String? storagePath}) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (!allowedStorageHosts.contains(uri.host.toLowerCase())) return false;

    final segments = uri.pathSegments;
    final String object;
    if (segments.length >= 4 &&
        segments[0] == 'v0' &&
        segments[1] == 'b' &&
        segments[3] == 'o') {
      if (segments[2].toLowerCase() != storageBucket) return false;
      object = segments.sublist(4).join('/');
    } else {
      object = segments.join('/');
    }
    if (storagePath != null && object != storagePath) return false;
    return isAllowedStoragePath(object);
  }

  static bool isAllowedStoragePath(String storagePath) {
    if (storagePath.split('/').contains('..')) return false;
    return allowedStoragePathPrefixes.any((p) => storagePath.startsWith(p));
  }

  static bool isImageMimeType(String mimeType) =>
      allowedImageMimeTypes.contains(mimeType.toLowerCase()) ||
      mimeType.toLowerCase().startsWith('image/');

  static bool isAllowedMimeType(String mimeType) {
    final m = mimeType.toLowerCase();
    return allowedImageMimeTypes.contains(m) ||
        allowedDocumentMimeTypes.contains(m);
  }

  static int maxBytesFor(String mimeType) =>
      allowedImageMimeTypes.contains(mimeType.toLowerCase())
      ? maxImageBytes
      : maxDocumentBytes;

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot >= fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static String resolveMimeType({String? reported, required String fileName}) {
    final r = reported?.trim().toLowerCase() ?? '';
    if (r.isNotEmpty && r != 'application/octet-stream' && r.contains('/')) {
      return r;
    }
    return _mimeByExtension[extensionOf(fileName)] ??
        'application/octet-stream';
  }

  static String sanitizeFileName(String rawName) {
    var name = rawName.trim();
    if (name.isEmpty) name = 'file';
    final lastSep = name.lastIndexOf(RegExp(r'[\\/]'));
    if (lastSep >= 0) name = name.substring(lastSep + 1);
    name = name.replaceAll(RegExp(r'[^֐-׿a-zA-Z0-9 ._()\-]'), '_');
    name = name.replaceAll(RegExp(r'^\.+'), '');
    if (name.isEmpty) name = 'file';
    if (name.length > 80) {
      final ext = extensionOf(name);
      final stem = ext.isEmpty
          ? name
          : name.substring(0, name.length - ext.length - 1);
      final keep = stem.length > 60 ? stem.substring(0, 60) : stem;
      name = ext.isEmpty ? keep : '$keep.$ext';
    }
    return name;
  }

  static String? validate({
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) {
    final ext = extensionOf(fileName);
    if (ext.isNotEmpty && bannedExtensions.contains(ext)) {
      return 'לא ניתן לשלוח קבצי $ext מטעמי אבטחה';
    }
    if (!isAllowedMimeType(mimeType)) {
      return 'סוג הקובץ אינו נתמך. ניתן לשלוח תמונות, PDF ומסמכים בלבד';
    }
    if (sizeBytes <= 0) {
      return 'הקובץ ריק';
    }
    final limit = maxBytesFor(mimeType);
    if (sizeBytes > limit) {
      final limitMb = limit ~/ (1024 * 1024);
      return allowedImageMimeTypes.contains(mimeType.toLowerCase())
          ? 'התמונה גדולה מדי. מקסימום ${limitMb}MB'
          : 'הקובץ גדול מדי. מקסימום ${limitMb}MB';
    }
    return null;
  }
}
