import 'package:flutter/material.dart';

import 'refraction_controller.dart';

/// Small HUD for shader binding health and capture timing (debug builds).
class GraphicsDebugOverlay extends StatelessWidget {
  const GraphicsDebugOverlay({
    super.key,
    required this.controller,
    required this.frameCount,
    required this.impeller,
    this.initError,
  });

  final RefractionController controller;
  final int frameCount;
  final bool impeller;
  final Object? initError;

  @override
  Widget build(BuildContext context) {
    final frameMs = controller.lastFrameTime?.inMicroseconds ?? 0;
    final frameMsDisplay = frameMs > 0 ? (frameMs / 1000).toStringAsFixed(1) : '—';
    final captureMs = controller.lastCaptureDuration?.inMicroseconds ?? 0;
    final captureDisplay = captureMs > 0 ? (captureMs / 1000).toStringAsFixed(1) : '—';

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white, height: 1.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Vitreous GFX', style: TextStyle(color: Colors.cyan.shade200)),
              Text('Impeller: ${impeller ? 'ON' : 'OFF'}'),
              Text('Frame: ${frameMsDisplay}ms  (#$frameCount)'),
              Text('Capture: ${captureDisplay}ms  (n=${controller.captureCount})'),
              Text('Uniform pushes: ${controller.uniformPushCount}'),
              Text('Snapshot: ${controller.hasValidSnapshot ? 'OK' : 'pending'}'),
              if (initError != null) Text('ERR: $initError', style: const TextStyle(color: Colors.redAccent)),
              if (controller.lastError != null)
                Text('CAP: ${controller.lastError}', style: const TextStyle(color: Colors.orangeAccent)),
            ],
          ),
        ),
      ),
    );
  }
}
