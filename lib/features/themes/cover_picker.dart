import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../i18n/translations.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';

const coverMaxBytes = 5 * 1024 * 1024;

class PickedCover {
  const PickedCover(this.bytes, this.filename);

  final Uint8List bytes;
  final String filename;
}

/// Opens the gallery, then lets the user frame the image at 16:9.
/// Returns null when either step is cancelled; shows a toast and returns
/// null when the result is over [coverMaxBytes].
Future<PickedCover?> pickCover(BuildContext context, Translations t) async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 90);
  if (file == null) return null;
  final source = await file.readAsBytes();
  if (!context.mounted) return null;
  if (source.length > coverMaxBytes) {
    showToast(context, t.ct_coverTooLarge, error: true);
    return null;
  }

  final cropped = await Navigator.of(context, rootNavigator: true)
      .push<Uint8List>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _CropScreen(image: source)));
  if (cropped == null || !context.mounted) return null;

  var bytes = cropped;
  if (bytes.length > coverMaxBytes) bytes = await _downscale(bytes, 1280);
  if (!context.mounted) return null;
  if (bytes.length > coverMaxBytes) {
    showToast(context, t.ct_coverTooLarge, error: true);
    return null;
  }
  final isPng = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50;
  return PickedCover(bytes, isPng ? 'cover.png' : 'cover.jpg');
}

/// Re-encodes as PNG at [width] px wide (dart:ui can only encode PNG).
Future<Uint8List> _downscale(Uint8List bytes, int width) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  codec.dispose();
  return data?.buffer.asUint8List() ?? bytes;
}

class _CropScreen extends ConsumerStatefulWidget {
  const _CropScreen({required this.image});

  final Uint8List image;

  @override
  ConsumerState<_CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<_CropScreen> {
  final _controller = CropController();
  bool _cropping = false;

  void _confirm() {
    if (_cropping) return;
    setState(() => _cropping = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.ct_coverCropTitle),
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: t.ct_cancel, onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Crop(
                image: widget.image,
                controller: _controller,
                aspectRatio: 16 / 9,
                interactive: true,
                fixCropRect: true,
                onCropped: (result) {
                  if (!mounted) return;
                  switch (result) {
                    case CropSuccess(:final croppedImage):
                      Navigator.pop(context, croppedImage);
                    case CropFailure():
                      setState(() => _cropping = false);
                      showToast(context, t.ct_coverInvalid, error: true);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GameButton(label: t.ct_coverCropConfirm, loading: _cropping, onPressed: _confirm),
            ),
          ],
        ),
      ),
    );
  }
}

String coverErrorMessage(Translations t, Object error) => switch (error is ApiException ? error.statusCode : null) {
      413 => t.ct_coverTooLarge,
      422 => t.ct_coverInvalid,
      _ => t.ct_coverUploadFailed,
    };

/// Preview + add/change/remove buttons. Shows [bytes] (fresh pick) over [url] (current).
class CoverPicker extends StatelessWidget {
  const CoverPicker({
    super.key,
    required this.t,
    required this.onPick,
    required this.onRemove,
    this.url,
    this.bytes,
    this.busy = false,
  });

  final Translations t;
  final String? url;
  final Uint8List? bytes;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasCover = url != null || bytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(t.ct_coverImage),
        CoverImage(url: url, bytes: bytes, borderRadius: gameBorderRadius),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GameButton(
                label: hasCover ? t.ct_coverChange : t.ct_coverAdd,
                variant: ButtonVariant.muted,
                icon: Icons.image_outlined,
                loading: busy,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                fontSize: 14,
                onPressed: busy ? null : onPick,
              ),
            ),
            if (hasCover) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: t.ct_coverRemove,
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
