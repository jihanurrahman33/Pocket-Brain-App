import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/data_export_repository.dart';
import '../mappers/export_mapper.dart';

/// Writes exports as pretty JSON into Downloads (or Documents as fallback).
final class JsonFileExportRepository implements DataExportRepository {
  const JsonFileExportRepository();

  @override
  Future<String> write(ExportBundle bundle) async {
    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final stamp = bundle.exportedAt.toIso8601String().split('.').first.replaceAll(':', '-');
    final file = File(p.join(dir.path, 'pocket_brain_export_$stamp.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(ExportMapper.toJson(bundle)),
    );
    return file.path;
  }
}
