import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/patient_records.dart';

class RecordsRepository {
  RecordsRepository(this._dio, {Future<Directory> Function()? tempDir})
    : _tempDir = tempDir ?? getTemporaryDirectory;

  final Dio _dio;
  final Future<Directory> Function() _tempDir;

  /// The signed-in patient's records, or a family member's.
  ApiResult<PatientRecords> mine({String? familyMemberId}) =>
      guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/me/records',
          queryParameters: {'familyMemberId': ?familyMemberId},
        );
        return PatientRecords.fromJson(response.data!);
      });

  /// Downloads a record's attachment with the authenticated client (the
  /// endpoint needs the bearer token) into the temp folder and returns the file.
  ApiResult<File> downloadAttachment(String recordId) => guardApi(() async {
    final response = await _dio.get<List<int>>(
      '/me/records/${Uri.encodeComponent(recordId)}/attachment',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const Failure(code: 'NOT_FOUND');
    }
    final name = attachmentFileName(
      contentDisposition: response.headers.value('content-disposition'),
      contentType: response.headers.value('content-type'),
    );
    final root = await _tempDir();
    final dir = Directory(
      '${root.path}/attachments/${_safeName(recordId, 'record')}',
    );
    await dir.create(recursive: true);
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  });
}

const _extensions = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
  'text/plain': 'txt',
};

String _safeName(String raw, String fallback) {
  final base = raw.split(RegExp(r'[\\/]')).last;
  final clean = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return clean.isEmpty || clean.replaceAll('.', '').isEmpty ? fallback : clean;
}

/// A safe local file name for a download: the server's `filename` when there is
/// one (path parts and odd characters removed), else `attachment.<ext>` from the
/// content type, so the system viewer can tell what kind of file it is.
String attachmentFileName({String? contentDisposition, String? contentType}) {
  final match = RegExp(
    r'''filename\*?=(?:UTF-8'')?"?([^";]+)"?''',
    caseSensitive: false,
  ).firstMatch(contentDisposition ?? '');
  if (match != null) {
    final decoded = Uri.decodeComponent(match.group(1)!.trim());
    final safe = _safeName(decoded, '');
    if (safe.isNotEmpty) return safe;
  }
  final type = (contentType ?? '').split(';').first.trim().toLowerCase();
  final extension = _extensions[type];
  return extension == null ? 'attachment' : 'attachment.$extension';
}

/// Opens a downloaded file with the system viewer; false when nothing can.
typedef FileOpener = Future<bool> Function(File file);

final fileOpenerProvider = Provider<FileOpener>(
  (ref) => (file) async {
    final result = await OpenFilex.open(file.path);
    return result.type == ResultType.done;
  },
);

final recordsRepositoryProvider = Provider<RecordsRepository>(
  (ref) => RecordsRepository(ref.watch(dioProvider)),
);
