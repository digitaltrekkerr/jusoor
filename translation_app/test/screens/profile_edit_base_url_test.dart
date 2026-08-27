import 'package:flutter_test/flutter_test.dart';
import 'package:translation_app/screens/profile_edit_screen.dart';

void main() {
  group('validateProviderBaseUrl — HTTPS enforcement', () {
    test('accepts https:// remote endpoints', () {
      expect(
        validateProviderBaseUrl('https://api.openai.com/v1'),
        isA<BaseUrlOk>(),
      );
      expect(
        validateProviderBaseUrl('https://localhost:11434/v1'),
        isA<BaseUrlOk>(),
      );
      expect(
        validateProviderBaseUrl('  https://api.example.com/v1  '),
        isA<BaseUrlOk>(),
      );
    });

    test('accepts http:// only for loopback hosts', () {
      expect(
        validateProviderBaseUrl('http://localhost:11434/v1'),
        isA<BaseUrlOk>(),
      );
      expect(
        validateProviderBaseUrl('http://127.0.0.1:8000'),
        isA<BaseUrlOk>(),
      );
      expect(
        validateProviderBaseUrl('http://[::1]:8080'),
        isA<BaseUrlOk>(),
      );
    });

    test('rejects http:// for remote endpoints', () {
      expect(
        validateProviderBaseUrl('http://192.168.1.10:11434/v1'),
        isA<BaseUrlInsecureRemote>(),
      );
      expect(
        validateProviderBaseUrl('http://api.example.com/v1'),
        isA<BaseUrlInsecureRemote>(),
      );
      expect(
        validateProviderBaseUrl('HTTP://example.com'),
        isA<BaseUrlInsecureRemote>(),
      );
    });

    test('rejects malformed and non-http(s) URLs', () {
      expect(
        validateProviderBaseUrl(''),
        isA<BaseUrlMalformed>(),
      );
      expect(
        validateProviderBaseUrl('not-a-url'),
        isA<BaseUrlMalformed>(),
      );
      expect(
        validateProviderBaseUrl('ftp://example.com'),
        isA<BaseUrlBadScheme>(),
      );
    });
  });
}