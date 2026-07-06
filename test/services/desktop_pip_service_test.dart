import 'package:flutter_test/flutter_test.dart';
import 'package:emby_player/services/desktop_pip_service.dart';

void main() {
  test('desktop PiP corner radius is positive', () {
    expect(DesktopPipService.pipCornerRadius, greaterThan(0));
  });

  test('desktop PiP inactive by default', () {
    expect(DesktopPipService.isActive.value, isFalse);
  });
}
