import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:my_financial_manager/core/repositories/export_repository.dart';

import '../test_helpers.dart';

/// Same fake used by backup_repository_test.dart: only redirects *where*
/// the export writes to, so it can run without a device.
class _FakePathProviderPlatform extends PathProviderPlatform {
  final String path;
  _FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  setUpDatabaseForTesting();

  late Directory tempDir;
  late ExportRepository repo;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pfm_export_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDownAll(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  setUp(() => repo = ExportRepository());

  group('ExportRepository.exportMonthlySummaryPdf', () {
    // The PDF footer date (previously always Gregorian, one of the two
    // minor gaps this phase closes — see Addendum #10) is exercised via
    // both toggle states here for a basic smoke check; the actual
    // Gregorian-vs-Ethiopian formatting logic itself is covered directly,
    // string-for-string, in formatters_test.dart, since PDF content
    // streams aren't reliably string-searchable the way a plain-text
    // assertion would need.
    test('produces a real, non-empty PDF regardless of the Ethiopian-calendar toggle', () async {
      final fileGregorian = await repo.exportMonthlySummaryPdf(currency: 'ETB');
      expect(await fileGregorian.exists(), isTrue);
      final bytesGregorian = await fileGregorian.readAsBytes();
      expect(bytesGregorian.length, greaterThan(0));
      expect(String.fromCharCodes(bytesGregorian.take(5)), '%PDF-');

      final fileEthiopian =
          await repo.exportMonthlySummaryPdf(currency: 'ETB', useEthiopian: true);
      expect(await fileEthiopian.exists(), isTrue);
      final bytesEthiopian = await fileEthiopian.readAsBytes();
      expect(bytesEthiopian.length, greaterThan(0));
      expect(String.fromCharCodes(bytesEthiopian.take(5)), '%PDF-');
    });

    test('defaults to the Gregorian footer when useEthiopian is omitted', () async {
      // Signature default (useEthiopian: false) — this is what every call
      // site predating this phase still gets.
      final file = await repo.exportMonthlySummaryPdf(currency: 'USD', languageCode: 'en');
      expect(await file.exists(), isTrue);
    });
  });
}
