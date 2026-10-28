import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/services/api_service.dart';

void main() {
  test('reads session_id from a Set-Cookie header', () {
    expect(
      ApiService.sessionIdFromSetCookie(
        'session_id=C5jc5gpwp8abc; Expires=Wed, 04 Nov 2026 10:00:00 GMT; Max-Age=604800; HttpOnly; Path=/',
      ),
      'C5jc5gpwp8abc',
    );
  });

  test('finds it among several cookies joined by commas', () {
    expect(
      ApiService.sessionIdFromSetCookie(
        'frontend_lang=en_US; Path=/, session_id=XyZ_9-1; Expires=Wed, 04 Nov 2026 10:00:00 GMT; HttpOnly; Path=/',
      ),
      'XyZ_9-1',
    );
  });

  test('no session cookie → null', () {
    expect(ApiService.sessionIdFromSetCookie(null), isNull);
    expect(ApiService.sessionIdFromSetCookie(''), isNull);
    expect(ApiService.sessionIdFromSetCookie('frontend_lang=en_US; Path=/'), isNull);
  });
}
