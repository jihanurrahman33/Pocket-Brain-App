import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../../core/logging/app_logger.dart';

/// A file to download and verify.
class DownloadSpec {
  const DownloadSpec({
    required this.url,
    required this.target,
    required this.expectedBytes,
    required this.sha256,
  });

  final Uri url;

  /// Final location; bytes are staged in `<target>.part` until verified.
  final File target;
  final int expectedBytes;

  /// Lower-case hex digest the finished file must match.
  final String sha256;

  File get partial => File('${target.path}.part');
}

/// Thrown when the user cancels; the partial file is kept for resuming.
final class DownloadCancelledException implements Exception {
  const DownloadCancelledException();
}

/// Thrown when the finished file does not match its size or checksum. The
/// corrupt partial is deleted so the next attempt starts clean.
final class DownloadIntegrityException implements Exception {
  const DownloadIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'DownloadIntegrityException: $message';
}

/// Downloads large files so that any interruption — cancel, crash, network
/// drop, hot restart, app kill — resumes from the bytes already on disk.
///
/// Bytes stream into `<target>.part`. Each attempt asks the server for the
/// rest with an HTTP `Range` header; a server that ignores it (`200`) is
/// handled by starting over. Transient network errors are retried with
/// back-off. The finished file is verified (size and SHA-256) before it is
/// renamed into place, so a corrupt or tampered file is never used.
class ResumableDownloader {
  ResumableDownloader(
    this._client,
    this._logger, {
    this.maxAttempts = 5,
    this.retryDelay = const Duration(seconds: 2),
    this.idleTimeout = const Duration(seconds: 30),
  });

  final http.Client _client;
  final AppLogger _logger;
  final int maxAttempts;
  final Duration retryDelay;

  /// A connection that delivers no data for this long counts as dropped
  /// (and is retried from the bytes on disk) instead of hanging forever.
  final Duration idleTimeout;

  static const _maxRedirects = 5;
  static const _ok = 200;
  static const _partialContent = 206;
  static const _rangeNotSatisfiable = 416;

  /// Bytes already downloaded (complete file or partial).
  static int bytesOnDisk(DownloadSpec spec) {
    if (spec.target.existsSync()) return spec.target.lengthSync();
    if (spec.partial.existsSync()) return spec.partial.lengthSync();
    return 0;
  }

  /// Downloads [spec], reporting the bytes on disk (including any resumed
  /// prefix) to [onProgress]. Returns the verified target file.
  Future<File> download(
    DownloadSpec spec, {
    required void Function(int bytesOnDisk) onProgress,
    required bool Function() isCancelled,
  }) async {
    if (spec.target.existsSync() && spec.target.lengthSync() == spec.expectedBytes) {
      onProgress(spec.expectedBytes);
      return spec.target;
    }
    await spec.partial.parent.create(recursive: true);
    for (var attempt = 1; ; attempt++) {
      try {
        await _fetchRemaining(spec, onProgress: onProgress, isCancelled: isCancelled);
        break;
      } on DownloadCancelledException {
        rethrow;
      } on Object catch (e) {
        if (attempt >= maxAttempts || isCancelled()) rethrow;
        _logger.info('Download interrupted ($e); retry $attempt of ${maxAttempts - 1}');
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
    // Honour a cancel that arrived with the final bytes; they stay on disk.
    if (isCancelled()) throw const DownloadCancelledException();
    await _verify(spec);
    return spec.partial.rename(spec.target.path);
  }

  Future<void> _fetchRemaining(
    DownloadSpec spec, {
    required void Function(int bytesOnDisk) onProgress,
    required bool Function() isCancelled,
  }) async {
    var offset = spec.partial.existsSync() ? spec.partial.lengthSync() : 0;
    if (offset > spec.expectedBytes) {
      await spec.partial.delete();
      offset = 0;
    }
    if (offset == spec.expectedBytes) return;
    onProgress(offset);

    final response = await _get(spec.url, offset);
    switch (response.statusCode) {
      case _partialContent:
        break;
      case _ok:
        // Range ignored: the body is the whole file, so restart the partial.
        offset = 0;
      case _rangeNotSatisfiable:
        await response.stream.drain<void>();
        await spec.partial.delete();
        throw const HttpException('Partial download did not match the server file');
      default:
        await response.stream.drain<void>();
        throw HttpException('Download failed with HTTP ${response.statusCode}');
    }

    final sink = spec.partial.openWrite(mode: offset == 0 ? FileMode.write : FileMode.append);
    var received = offset;
    try {
      await for (final chunk in response.stream.timeout(idleTimeout)) {
        if (isCancelled()) throw const DownloadCancelledException();
        sink.add(chunk);
        received += chunk.length;
        onProgress(received);
      }
    } finally {
      // Flushes what arrived, so the next attempt resumes after it.
      await sink.flush();
      await sink.close();
    }
    if (received != spec.expectedBytes) {
      throw HttpException('Connection closed at $received of ${spec.expectedBytes} bytes');
    }
  }

  /// GET with a `Range` header, following redirects manually so the header
  /// is kept on every hop (CDNs redirect to signed storage URLs).
  Future<http.StreamedResponse> _get(Uri url, int offset) async {
    var current = url;
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      final request = http.Request('GET', current)..followRedirects = false;
      if (offset > 0) request.headers[HttpHeaders.rangeHeader] = 'bytes=$offset-';
      final response = await _client.send(request);
      final location = response.headers[HttpHeaders.locationHeader];
      if (response.isRedirect || (response.statusCode >= 300 && response.statusCode < 400)) {
        await response.stream.drain<void>();
        if (location == null) throw const HttpException('Redirect without location');
        current = current.resolve(location);
        continue;
      }
      return response;
    }
    throw const HttpException('Too many redirects');
  }

  Future<void> _verify(DownloadSpec spec) async {
    final length = await spec.partial.length();
    if (length != spec.expectedBytes) {
      await spec.partial.delete();
      throw DownloadIntegrityException('Expected ${spec.expectedBytes} bytes, got $length');
    }
    final digest = await sha256.bind(spec.partial.openRead()).first;
    if (digest.toString() != spec.sha256.toLowerCase()) {
      await spec.partial.delete();
      throw const DownloadIntegrityException('Checksum mismatch');
    }
  }

  /// Removes both the finished file and any partial download.
  static Future<void> deleteAll(DownloadSpec spec) async {
    for (final file in [spec.target, spec.partial]) {
      if (file.existsSync()) await file.delete();
    }
  }
}
