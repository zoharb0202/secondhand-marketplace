import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_colors.dart';

class ImageCropFramePage extends StatefulWidget {
  final Uint8List imageBytes;

  final double aspectRatio;

  const ImageCropFramePage({
    super.key,
    required this.imageBytes,
    this.aspectRatio = 3 / 4,
  });

  @override
  State<ImageCropFramePage> createState() => _ImageCropFramePageState();
}

class _ImageCropFramePageState extends State<ImageCropFramePage> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _controller = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final box = _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box != null
        ? Offset(box.size.width / 2, box.size.height / 2)
        : Offset.zero;
    final m = _controller.value.clone()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(factor, factor, factor, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    _controller.value = m;
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final logicalWidth = boundary.size.width;
      final pixelRatio = (1080 / logicalWidth).clamp(1.0, 4.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);

      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!mounted) return;
      if (raw == null) {
        Navigator.pop(context, null);
        return;
      }
      final decoded = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: raw.buffer,
        numChannels: 4,
      );
      final jpeg = img.encodeJpg(decoded, quality: 88);
      if (!mounted) return;
      Navigator.pop(context, jpeg);
    } catch (_) {
      if (mounted) Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('מסגור התמונה'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _confirm,
              child: const Text(
                'אישור',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Text(
              'גררו למיקום · השתמשו בכפתורי הזום למטה (או צביטה במובייל)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: Container(
                        color: Colors.white,
                        child: InteractiveViewer(
                          transformationController: _controller,
                          minScale: 0.5,
                          maxScale: 6,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          clipBehavior: Clip.hardEdge,
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _zoom(1 / 1.25),
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.white,
                    size: 30,
                  ),
                  tooltip: 'הקטן',
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _controller.value = Matrix4.identity(),
                  icon: const Icon(Icons.refresh, color: AppColors.sun),
                  label: const Text(
                    'איפוס',
                    style: TextStyle(color: AppColors.sun),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _zoom(1.25),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: 30,
                  ),
                  tooltip: 'הגדל',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
