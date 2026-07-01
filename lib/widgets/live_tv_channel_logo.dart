import 'package:flutter/material.dart';

import '../media/media_server_client.dart';
import 'optimized_media_image.dart';

/// Channel logo with the bottom-right IPTV provider watermark cropped off.
///
/// Many M3U/EPG sources bake a small provider logo (e.g. M3U4U) into the
/// corner of channel artwork; clipping that region keeps the guide tidy.
class LiveTvChannelLogo extends StatelessWidget {
  final MediaServerClient client;
  final String imagePath;
  final double width;
  final double height;

  const LiveTvChannelLogo({
    super.key,
    required this.client,
    required this.imagePath,
    required this.width,
    required this.height,
  });

  static const _watermarkCropFraction = 0.14;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.topLeft,
        widthFactor: 1 - _watermarkCropFraction,
        heightFactor: 1 - _watermarkCropFraction,
        child: OptimizedMediaImage.thumb(
          client: client,
          imagePath: imagePath,
          width: width,
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
