import 'package:emby_player/graphics/vitreous_glass_shader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VitreousGlassShader', () {
    test('uniform layout exposes 18 float slots', () {
      expect(VitreousGlassUniforms.floatCount, 18);
      expect(VitreousGlassUniforms.backgroundSamplerIndex, 0);
    });

    test('warmUp throws descriptive error without Impeller', () async {
      if (VitreousGlassShader.isSupported) return;

      expect(VitreousGlassShader.warmUp, throwsA(isA<Exception>()));
    });
  });
}
