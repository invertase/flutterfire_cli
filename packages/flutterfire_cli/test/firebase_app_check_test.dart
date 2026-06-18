import 'dart:convert';

import 'package:flutterfire_cli/src/firebase.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('getRecaptchaEnterpriseSiteKey', () {
    test('returns siteKey from reCAPTCHA Enterprise config', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'siteKey': 'test-enterprise-site-key'}),
          200,
        );
      });

      final siteKey = await getRecaptchaEnterpriseSiteKey(
        projectNumber: '1234567890',
        appId: '1:1234567890:web:abcdef',
        accessToken: 'test-access-token',
        client: client,
      );

      expect(siteKey, 'test-enterprise-site-key');
      expect(
        capturedRequest.url,
        Uri.parse(
          'https://firebaseappcheck.googleapis.com/v1/projects/1234567890/apps/1:1234567890:web:abcdef/recaptchaEnterpriseConfig',
        ),
      );
      expect(
        capturedRequest.headers['Authorization'],
        'Bearer test-access-token',
      );
    });

    test('returns null when config has no siteKey', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      });

      final siteKey = await getRecaptchaEnterpriseSiteKey(
        projectNumber: '1234567890',
        appId: '1:1234567890:web:abcdef',
        accessToken: 'test-access-token',
        client: client,
      );

      expect(siteKey, isNull);
    });

    test('returns null when siteKey is empty', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'siteKey': ''}), 200);
      });

      final siteKey = await getRecaptchaEnterpriseSiteKey(
        projectNumber: '1234567890',
        appId: '1:1234567890:web:abcdef',
        accessToken: 'test-access-token',
        client: client,
      );

      expect(siteKey, isNull);
    });

    test('returns null when config is not found', () async {
      final client = MockClient((request) async {
        return http.Response('not found', 404);
      });

      final siteKey = await getRecaptchaEnterpriseSiteKey(
        projectNumber: '1234567890',
        appId: '1:1234567890:web:abcdef',
        accessToken: 'test-access-token',
        client: client,
      );

      expect(siteKey, isNull);
    });

    test('returns null when request fails', () async {
      final client = MockClient((request) async {
        throw http.ClientException('network unavailable');
      });

      final siteKey = await getRecaptchaEnterpriseSiteKey(
        projectNumber: '1234567890',
        appId: '1:1234567890:web:abcdef',
        accessToken: 'test-access-token',
        client: client,
      );

      expect(siteKey, isNull);
    });
  });
}
