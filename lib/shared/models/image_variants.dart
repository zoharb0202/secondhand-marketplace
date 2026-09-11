library;

enum ImageVariant { thumb, medium, original }

class ResizeExtensionConfig {
  final int thumbWidth;
  final int thumbHeight;

  final int mediumWidth;
  final int mediumHeight;

  final String? outputDirectory;

  final String? outputExtension;

  const ResizeExtensionConfig({
    required this.thumbWidth,
    required this.thumbHeight,
    required this.mediumWidth,
    required this.mediumHeight,
    this.outputDirectory,
    this.outputExtension,
  });

  (int, int)? sizeOf(ImageVariant variant) => switch (variant) {
    ImageVariant.thumb => (thumbWidth, thumbHeight),
    ImageVariant.medium => (mediumWidth, mediumHeight),
    ImageVariant.original => null,
  };
}

const ResizeExtensionConfig kResizeExtension = ResizeExtensionConfig(
  thumbWidth: 600,
  thumbHeight: 600,
  mediumWidth: 1280,
  mediumHeight: 1280,
);

const int kThumbDecodeWidth = 600;
const int kCompactThumbDecodeWidth = 500;
const int kMediumDecodeWidth = 1280;

class ProductImageVariants {
  final String originalUrl;
  final String? thumbUrl;
  final String? mediumUrl;

  const ProductImageVariants({
    required this.originalUrl,
    this.thumbUrl,
    this.mediumUrl,
  });

  String? urlFor(ImageVariant variant) => switch (variant) {
    ImageVariant.thumb => thumbUrl,
    ImageVariant.medium => mediumUrl,
    ImageVariant.original => originalUrl,
  };

  static ProductImageVariants? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final original = raw['original'];
    if (original is! String || original.isEmpty) return null;
    String? str(dynamic v) => (v is String && v.isNotEmpty) ? v : null;
    return ProductImageVariants(
      originalUrl: original,
      thumbUrl: str(raw['thumb']),
      mediumUrl: str(raw['medium']),
    );
  }

  static List<ProductImageVariants> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map(ProductImageVariants.fromMap)
        .whereType<ProductImageVariants>()
        .toList(growable: false);
  }

  Map<String, dynamic> toMap() => {
    'original': originalUrl,
    if (thumbUrl != null) 'thumb': thumbUrl,
    if (mediumUrl != null) 'medium': mediumUrl,
  };
}

class StorageDownloadUrl {
  final String origin;

  final String bucket;

  final String objectPath;

  const StorageDownloadUrl({
    required this.origin,
    required this.bucket,
    required this.objectPath,
  });
}

StorageDownloadUrl? parseStorageDownloadUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || !uri.isScheme('https')) return null;
  final segments = uri.pathSegments;
  if (segments.length < 5) return null;
  if (segments[0] != 'v0' || segments[1] != 'b' || segments[3] != 'o') {
    return null;
  }
  final bucket = segments[2];
  if (bucket.isEmpty) return null;
  final objectPath = segments.sublist(4).join('/');
  if (objectPath.isEmpty) return null;
  return StorageDownloadUrl(
    origin: '${uri.scheme}://${uri.authority}',
    bucket: bucket,
    objectPath: objectPath,
  );
}

String derivedObjectPath(
  String objectPath,
  int width,
  int height, {
  String? outputDirectory,
  String? outputExtension,
}) {
  final slash = objectPath.lastIndexOf('/');
  final folder = slash < 0 ? '' : objectPath.substring(0, slash);
  final fileName = slash < 0 ? objectPath : objectPath.substring(slash + 1);

  final dot = fileName.lastIndexOf('.');
  final stem = dot <= 0 ? fileName : fileName.substring(0, dot);
  final ext =
      outputExtension ?? (dot <= 0 ? null : fileName.substring(dot + 1));

  final derivedName = ext == null
      ? '${stem}_${width}x$height'
      : '${stem}_${width}x$height.$ext';

  final targetFolder = outputDirectory ?? folder;
  if (targetFolder.isEmpty) return derivedName;
  return '${targetFolder.replaceAll(RegExp(r'/+$'), '')}/$derivedName';
}

String? derivedDownloadUrl(
  String originalUrl,
  ImageVariant variant, {
  ResizeExtensionConfig config = kResizeExtension,
}) {
  final size = config.sizeOf(variant);
  if (size == null) return null;
  final parsed = parseStorageDownloadUrl(originalUrl);
  if (parsed == null) return null;
  final path = derivedObjectPath(
    parsed.objectPath,
    size.$1,
    size.$2,
    outputDirectory: config.outputDirectory,
    outputExtension: config.outputExtension,
  );
  return '${parsed.origin}/v0/b/${parsed.bucket}/o/'
      '${Uri.encodeComponent(path)}?alt=media';
}

bool isExpectedVariantUrl(
  String candidateUrl,
  String originalUrl,
  ImageVariant variant, {
  ResizeExtensionConfig config = kResizeExtension,
}) {
  final expected = derivedDownloadUrl(originalUrl, variant, config: config);
  if (expected == null) return false;
  final a = parseStorageDownloadUrl(candidateUrl);
  final b = parseStorageDownloadUrl(expected);
  if (a == null || b == null) return false;
  return a.origin == b.origin &&
      a.bucket == b.bucket &&
      a.objectPath == b.objectPath;
}

String? resolveProductImageUrl({
  required List<String> imageUrls,
  required int index,
  required ImageVariant variant,
  List<ProductImageVariants> storedVariants = const [],
  ResizeExtensionConfig config = kResizeExtension,
}) {
  if (index < 0 || index >= imageUrls.length) return null;
  final original = imageUrls[index];
  if (original.isEmpty) return null;
  if (variant == ImageVariant.original) return original;

  for (final entry in storedVariants) {
    if (entry.originalUrl != original) continue;
    final candidate = entry.urlFor(variant);
    if (candidate == null) break;
    if (isExpectedVariantUrl(candidate, original, variant, config: config)) {
      return candidate;
    }
    break;
  }
  return original;
}
