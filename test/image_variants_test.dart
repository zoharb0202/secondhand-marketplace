import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/core/constants/enums.dart';
import 'package:secondhand_marketplace/shared/models/image_variants.dart';
import 'package:secondhand_marketplace/shared/models/product_model.dart';

const _bucket = 'your-project-id.appspot.com';
const _host = 'https://firebasestorage.googleapis.com';

String storageUrl(String objectPath, {String token = 'aaaa-bbbb-cccc'}) =>
    '$_host/v0/b/$_bucket/o/${Uri.encodeComponent(objectPath)}'
    '?alt=media&token=$token';

const _originalPath = 'product_images/uid123/1699_sofa.jpg';
final _original = storageUrl(_originalPath);

final _thumb = storageUrl(
  'product_images/uid123/1699_sofa_600x600.jpg',
  token: 'zzz-999',
);
final _medium = storageUrl(
  'product_images/uid123/1699_sofa_1280x1280.jpg',
  token: 'yyy-888',
);

ProductModel product({
  List<String> imageUrls = const [],
  List<ProductImageVariants> imageVariants = const [],
}) => ProductModel(
  id: 'p1',
  sellerId: 'uid123',
  title: 'ספה',
  description: 'ספה תלת מושבית',
  price: 500,
  category: ProductCategory.homeGarden,
  condition: ProductCondition.good,
  imageUrls: imageUrls,
  imageVariants: imageVariants,
  createdAt: DateTime(2026, 8, 18),
  location: const GeoPoint(32.08, 34.78),
  city: 'תל אביב',
);

void main() {
  group('parseStorageDownloadUrl', () {
    test('pulls the decoded object path out of a real download URL', () {
      final parsed = parseStorageDownloadUrl(_original)!;
      expect(parsed.bucket, _bucket);
      expect(parsed.objectPath, _originalPath);
      expect(parsed.origin, _host);
    });

    test('rejects anything that is not a Storage download URL', () {
      for (final notStorage in <String?>[
        null,
        '',
        'https://example.com/photos/sofa.jpg',
        'https://cdn.shopify.com/v0/b/x/sofa.jpg',
        'data:image/png;base64,iVBORw0KGgo=',
        'assets/images/placeholder.png',
        'gs://$_bucket/$_originalPath',
        'not a url at all',
        '$_host/v0/b/$_bucket/o/',
      ]) {
        expect(
          parseStorageDownloadUrl(notStorage),
          isNull,
          reason: 'should not parse: $notStorage',
        );
      }
    });
  });

  group('derivedObjectPath', () {
    test('inserts the size before the extension, in the same folder', () {
      expect(
        derivedObjectPath(_originalPath, 600, 600),
        'product_images/uid123/1699_sofa_600x600.jpg',
      );
    });

    test('honours a configured output directory and output format', () {
      expect(
        derivedObjectPath(
          _originalPath,
          600,
          600,
          outputDirectory: 'resized',
          outputExtension: 'webp',
        ),
        'resized/1699_sofa_600x600.webp',
      );
    });

    test('survives a name with dots and a name with no extension', () {
      expect(
        derivedObjectPath('a/my.photo.v2.jpg', 600, 600),
        'a/my.photo.v2_600x600.jpg',
      );
      expect(derivedObjectPath('a/noext', 600, 600), 'a/noext_600x600');
    });
  });

  group('derivedDownloadUrl', () {
    test('builds the sibling URL without a token', () {
      final url = derivedDownloadUrl(_original, ImageVariant.thumb)!;
      expect(
        parseStorageDownloadUrl(url)!.objectPath,
        'product_images/uid123/1699_sofa_600x600.jpg',
      );
      expect(url.contains('token='), isFalse);
    });

    test('has nothing to derive for the original variant', () {
      expect(derivedDownloadUrl(_original, ImageVariant.original), isNull);
    });

    test('returns null for a non-Storage URL', () {
      expect(
        derivedDownloadUrl('https://example.com/a.jpg', ImageVariant.thumb),
        isNull,
      );
    });
  });

  group('resolveProductImageUrl — derived copy EXISTS', () {
    test('serves the stored thumbnail, token and all', () {
      final url = resolveProductImageUrl(
        imageUrls: [_original],
        index: 0,
        variant: ImageVariant.thumb,
        storedVariants: [
          ProductImageVariants(
            originalUrl: _original,
            thumbUrl: _thumb,
            mediumUrl: _medium,
          ),
        ],
      );
      expect(url, _thumb);
    });

    test('serves the stored medium for the same photo', () {
      final url = resolveProductImageUrl(
        imageUrls: [_original],
        index: 0,
        variant: ImageVariant.medium,
        storedVariants: [
          ProductImageVariants(
            originalUrl: _original,
            thumbUrl: _thumb,
            mediumUrl: _medium,
          ),
        ],
      );
      expect(url, _medium);
    });

    test('matches a photo by URL, not by position', () {
      final other = storageUrl('product_images/uid123/1699_lamp.jpg');
      final url = resolveProductImageUrl(
        imageUrls: [other, _original],
        index: 0,
        variant: ImageVariant.thumb,
        storedVariants: [
          ProductImageVariants(originalUrl: _original, thumbUrl: _thumb),
        ],
      );
      expect(url, other, reason: 'no variant for the lamp -> its original');
    });

    test('the original variant is always the original', () {
      final url = resolveProductImageUrl(
        imageUrls: [_original],
        index: 0,
        variant: ImageVariant.original,
        storedVariants: [
          ProductImageVariants(originalUrl: _original, thumbUrl: _thumb),
        ],
      );
      expect(url, _original);
    });
  });

  group('resolveProductImageUrl — derived copy MISSING (the normal case)', () {
    test('no stored variants at all -> the original', () {
      expect(
        resolveProductImageUrl(
          imageUrls: [_original],
          index: 0,
          variant: ImageVariant.thumb,
        ),
        _original,
      );
    });

    test('an entry that carries only a medium -> original for the thumb', () {
      expect(
        resolveProductImageUrl(
          imageUrls: [_original],
          index: 0,
          variant: ImageVariant.thumb,
          storedVariants: [
            ProductImageVariants(originalUrl: _original, mediumUrl: _medium),
          ],
        ),
        _original,
      );
    });

    test('a stored URL that is not the expected sibling is refused', () {
      final forged = storageUrl('product_images/uid123/something_else.jpg');
      expect(
        resolveProductImageUrl(
          imageUrls: [_original],
          index: 0,
          variant: ImageVariant.thumb,
          storedVariants: [
            ProductImageVariants(originalUrl: _original, thumbUrl: forged),
          ],
        ),
        _original,
      );
    });

    test('a variant on a FOREIGN HOST is refused', () {
      final offHost =
          'https://evil.example/v0/b/$_bucket/o/'
          '${Uri.encodeComponent("product_images/uid123/1699_sofa_600x600.jpg")}'
          '?alt=media';
      expect(
        isExpectedVariantUrl(offHost, _original, ImageVariant.thumb),
        isFalse,
      );
      expect(
        resolveProductImageUrl(
          imageUrls: [_original],
          index: 0,
          variant: ImageVariant.thumb,
          storedVariants: [
            ProductImageVariants(originalUrl: _original, thumbUrl: offHost),
          ],
        ),
        _original,
      );
    });

    test('a variant in another BUCKET on the right host is refused', () {
      final otherBucket =
          '$_host/v0/b/someone-elses-bucket/o/'
          '${Uri.encodeComponent("product_images/uid123/1699_sofa_600x600.jpg")}'
          '?alt=media';
      expect(
        resolveProductImageUrl(
          imageUrls: [_original],
          index: 0,
          variant: ImageVariant.thumb,
          storedVariants: [
            ProductImageVariants(originalUrl: _original, thumbUrl: otherBucket),
          ],
        ),
        _original,
      );
    });

    test('a variant stamped at the WRONG size is refused', () {
      final wrongSize = storageUrl(
        'product_images/uid123/1699_sofa_200x200.jpg',
      );
      expect(
        resolveProductImageUrl(
          imageUrls: [_original],
          index: 0,
          variant: ImageVariant.thumb,
          storedVariants: [
            ProductImageVariants(originalUrl: _original, thumbUrl: wrongSize),
          ],
        ),
        _original,
      );
    });

    test('a config change is picked up by passing the new config', () {
      final small = storageUrl('product_images/uid123/1699_sofa_200x200.jpg');
      const reconfigured = ResizeExtensionConfig(
        thumbWidth: 200,
        thumbHeight: 200,
        mediumWidth: 1280,
        mediumHeight: 1280,
      );
      expect(
        resolveProductImageUrl(
          imageUrls: [_original],
          index: 0,
          variant: ImageVariant.thumb,
          storedVariants: [
            ProductImageVariants(originalUrl: _original, thumbUrl: small),
          ],
          config: reconfigured,
        ),
        small,
      );
    });
  });

  group('resolveProductImageUrl — not a Firebase Storage URL', () {
    test('a foreign http URL is served unchanged, never mangled', () {
      const foreign = 'https://example.com/photos/sofa.jpg';
      for (final variant in ImageVariant.values) {
        expect(
          resolveProductImageUrl(
            imageUrls: const [foreign],
            index: 0,
            variant: variant,
          ),
          foreign,
          reason: 'variant $variant',
        );
      }
    });

    test('a foreign URL cannot be dressed up as a variant either', () {
      expect(
        resolveProductImageUrl(
          imageUrls: const ['https://example.com/photos/sofa.jpg'],
          index: 0,
          variant: ImageVariant.thumb,
          storedVariants: const [
            ProductImageVariants(
              originalUrl: 'https://example.com/photos/sofa.jpg',
              thumbUrl: 'https://example.com/photos/sofa_600x600.jpg',
            ),
          ],
        ),
        'https://example.com/photos/sofa.jpg',
      );
    });
  });

  group('resolveProductImageUrl — no image', () {
    test('an empty list yields null, not an empty string', () {
      expect(
        resolveProductImageUrl(
          imageUrls: const [],
          index: 0,
          variant: ImageVariant.thumb,
        ),
        isNull,
      );
    });

    test('an out-of-range index yields null', () {
      expect(
        resolveProductImageUrl(
          imageUrls: [_original],
          index: 3,
          variant: ImageVariant.thumb,
        ),
        isNull,
      );
      expect(
        resolveProductImageUrl(
          imageUrls: [_original],
          index: -1,
          variant: ImageVariant.thumb,
        ),
        isNull,
      );
    });

    test('an empty-string entry yields null', () {
      expect(
        resolveProductImageUrl(
          imageUrls: const [''],
          index: 0,
          variant: ImageVariant.medium,
        ),
        isNull,
      );
    });
  });

  group('ProductImageVariants parsing', () {
    test('reads the documented Firestore shape', () {
      final parsed = ProductImageVariants.listFrom([
        {'original': _original, 'thumb': _thumb, 'medium': _medium},
      ]);
      expect(parsed, hasLength(1));
      expect(parsed.single.originalUrl, _original);
      expect(parsed.single.urlFor(ImageVariant.thumb), _thumb);
    });

    test('a malformed stamp degrades to "no variants", never throws', () {
      final parsed = ProductImageVariants.listFrom([
        'a string',
        42,
        <String, dynamic>{},
        {'thumb': _thumb},
        {'original': '', 'thumb': _thumb},
        {'original': _original, 'thumb': 7},
      ]);
      expect(parsed, hasLength(1));
      expect(parsed.single.thumbUrl, isNull);
    });

    test('a missing or non-list field is an empty list', () {
      expect(ProductImageVariants.listFrom(null), isEmpty);
      expect(ProductImageVariants.listFrom('nope'), isEmpty);
      expect(ProductImageVariants.listFrom(const {}), isEmpty);
    });
  });

  group('ProductModel wiring', () {
    test('thumbnailUrl/mediumImageUrl fall back to the original', () {
      final p = product(imageUrls: [_original]);
      expect(p.thumbnailUrl, _original);
      expect(p.mediumImageUrl, _original);
    });

    test('thumbnailUrl/mediumImageUrl use the stamp when it is there', () {
      final p = product(
        imageUrls: [_original],
        imageVariants: [
          ProductImageVariants(
            originalUrl: _original,
            thumbUrl: _thumb,
            mediumUrl: _medium,
          ),
        ],
      );
      expect(p.thumbnailUrl, _thumb);
      expect(p.mediumImageUrl, _medium);
      expect(p.imageUrlAt(0), _original);
    });

    test('a photoless listing reports null, not an empty string', () {
      final p = product();
      expect(p.thumbnailUrl, isNull);
      expect(p.mediumImageUrl, isNull);
      expect(p.imageUrlAt(0, variant: ImageVariant.medium), isNull);
    });

    test('fromMap parses the field and tolerates its absence', () {
      final absent = ProductModel.fromMap({
        'sellerId': 'uid123',
        'imageUrls': [_original],
      }, 'p1');
      expect(absent.imageVariants, isEmpty);
      expect(absent.thumbnailUrl, _original);

      final present = ProductModel.fromMap({
        'sellerId': 'uid123',
        'imageUrls': [_original],
        'imageVariants': [
          {'original': _original, 'thumb': _thumb},
        ],
      }, 'p1');
      expect(present.thumbnailUrl, _thumb);
    });

    test('toFirestore never proposes imageVariants', () {
      final p = product(
        imageUrls: [_original],
        imageVariants: [
          ProductImageVariants(originalUrl: _original, thumbUrl: _thumb),
        ],
      );
      expect(p.toFirestore().containsKey('imageVariants'), isFalse);
    });

    test('copyWith carries the stamp', () {
      final p = product(
        imageUrls: [_original],
        imageVariants: [
          ProductImageVariants(originalUrl: _original, thumbUrl: _thumb),
        ],
      );
      expect(p.copyWith(title: 'ספה יפה').thumbnailUrl, _thumb);
    });
  });
}
