import 'package:emby_core/api/dio_factory.dart';
import 'package:emby_core/api/emby_auth_interceptor.dart';
import 'package:test/test.dart';

void main() {
  group('EmbyAuthInterceptor', () {
    test('adds MediaBrowser authorization header', () {
      const device = EmbyDeviceInfo(
        clientName: 'EmbyPlayer',
        deviceName: 'TestDevice',
        deviceId: 'test-device-id',
        version: '2.0.0',
      );
      final interceptor = EmbyAuthInterceptor(deviceInfo: device, accessToken: 'secret-token');

      expect(device.authorizationHeader, contains('Client="EmbyPlayer"'));
      expect(device.authorizationHeader, contains('DeviceId="test-device-id"'));
      interceptor.updateToken('new-token');
    });
  });

  group('normalizeEmbyBaseUrl', () {
    test('adds http scheme and strips trailing slash', () {
      expect(normalizeEmbyBaseUrl('192.168.1.10:8096/'), 'http://192.168.1.10:8096');
      expect(normalizeEmbyBaseUrl('https://emby.example.com'), 'https://emby.example.com');
    });
  });
}
