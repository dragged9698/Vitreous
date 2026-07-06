import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'vitreous_glass_exception.dart';

/// Uniform layout shared with [shaders/vitreous_glass.frag].
class VitreousGlassUniforms {
  const VitreousGlassUniforms({
    required this.panelSize,
    required this.physicalOrigin,
    required this.scale,
    required this.glassTint,
    required this.refractionStrength,
    required this.fresnelPower,
    required this.backdropLuma,
    required this.blurRadius,
    required this.bgRelativeOrigin,
    required this.bgSize,
  });

  final Size panelSize;
  final Offset physicalOrigin;
  final Offset scale;
  final Color glassTint;
  final double refractionStrength;
  final double fresnelPower;
  final double backdropLuma;
  final double blurRadius;
  final Offset bgRelativeOrigin;
  final Size bgSize;

  static const int floatCount = 18;
  static const int backgroundSamplerIndex = 0;
}

/// Loads and binds the Vitreous refraction fragment shader for Impeller/Vulkan.
class VitreousGlassShader {
  VitreousGlassShader._(this._program);

  static const assetPath = 'shaders/vitreous_glass.frag';

  static VitreousGlassShader? _cached;
  static bool _loading = false;
  static ui.Image? _dummySampler;

  final ui.FragmentProgram _program;

  static bool get isSupported => ui.ImageFilter.isShaderFilterSupported;

  static Future<VitreousGlassShader> warmUp() async {
    if (_cached != null) return _cached!;
    if (_loading) {
      while (_loading) {
        await Future<void>.delayed(const Duration(milliseconds: 4));
      }
      if (_cached != null) return _cached!;
    }

    _loading = true;
    try {
      if (!isSupported) {
        throw VitreousGlassException(
          'VitreousGlassShader requires Impeller (Vulkan/Metal). '
          'Run with --enable-impeller.',
        );
      }

      final program = await ui.FragmentProgram.fromAsset(assetPath);
      final shader = VitreousGlassShader._(program);

      final probe = program.fragmentShader();
      try {
        for (var i = 0; i < VitreousGlassUniforms.floatCount; i++) {
          probe.setFloat(i, 0);
        }
      } catch (e) {
        probe.dispose();
        throw VitreousGlassException(
          'Shader float uniform layout mismatch at index < ${VitreousGlassUniforms.floatCount}.',
          cause: e,
        );
      }
      probe.dispose();

      _dummySampler ??= await _createDummyImage();
      _cached = shader;
      return shader;
    } on VitreousGlassException {
      rethrow;
    } catch (e) {
      throw VitreousGlassException(
        'Failed to compile $assetPath.',
        cause: e,
      );
    } finally {
      _loading = false;
    }
  }

  static Future<ui.Image> _createDummyImage() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(1, 1);
    picture.dispose();
    return image;
  }

  ui.FragmentShader createFragmentShader() => _program.fragmentShader();

  void bind({
    required ui.FragmentShader shader,
    required VitreousGlassUniforms uniforms,
    required ui.Image? background,
  }) {
    var i = 0;
    shader
      ..setFloat(i++, uniforms.panelSize.width)
      ..setFloat(i++, uniforms.panelSize.height)
      ..setFloat(i++, uniforms.physicalOrigin.dx)
      ..setFloat(i++, uniforms.physicalOrigin.dy)
      ..setFloat(i++, uniforms.glassTint.r)
      ..setFloat(i++, uniforms.glassTint.g)
      ..setFloat(i++, uniforms.glassTint.b)
      ..setFloat(i++, uniforms.glassTint.a)
      ..setFloat(i++, uniforms.refractionStrength)
      ..setFloat(i++, uniforms.fresnelPower)
      ..setFloat(i++, uniforms.backdropLuma)
      ..setFloat(i++, uniforms.blurRadius)
      ..setFloat(i++, uniforms.bgRelativeOrigin.dx)
      ..setFloat(i++, uniforms.bgRelativeOrigin.dy)
      ..setFloat(i++, uniforms.bgSize.width)
      ..setFloat(i++, uniforms.bgSize.height)
      ..setFloat(i++, uniforms.scale.dx)
      ..setFloat(i++, uniforms.scale.dy);

    final image = background ?? _dummySampler;
    if (image == null) {
      throw VitreousGlassException(
        'Cannot bind uBackground sampler: no snapshot and dummy texture missing.',
      );
    }

    try {
      shader.setImageSampler(
        VitreousGlassUniforms.backgroundSamplerIndex,
        image,
        filterQuality: FilterQuality.medium,
      );
    } catch (e) {
      throw VitreousGlassException(
        'setImageSampler failed for ${image.width}x${image.height}.',
        cause: e,
      );
    }
  }
}
