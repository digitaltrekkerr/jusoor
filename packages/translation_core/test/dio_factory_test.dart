import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/src/utils/dio_factory.dart';

void main() {
  group('createTranslationDio', () {
    final dio = createTranslationDio();

    test('configures 10s connect timeout', () {
      expect(dio.options.connectTimeout, const Duration(seconds: 10));
    });

    test('configures 120s receive timeout', () {
      expect(dio.options.receiveTimeout, const Duration(seconds: 120));
    });

    test('configures 30s send timeout', () {
      expect(dio.options.sendTimeout, const Duration(seconds: 30));
    });
  });
}
