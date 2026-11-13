import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocket_brain/data/datasources/ai/resumable_downloader.dart';

import '../helpers/fakes.dart';

/// A minimal HTTP/1.1 file server on a raw socket, so it can misbehave
/// exactly like real networks: cut the connection mid-body, ignore `Range`,
/// or redirect.
class _FileServer {
  _FileServer(this.body);

  final Uint8List body;
  late final ServerSocket _server;
  final rangeHeaders = <String?>[];

  /// Cut the connection after sending this many body bytes (once).
  int? dropAfter;
  bool ignoreRange = false;
  bool redirectFirst = false;

  static const _chunk = 16 * 1024;

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}/model.bin');

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> _handle(Socket socket) async {
    final head = StringBuffer();
    await for (final data in socket) {
      head.write(String.fromCharCodes(data));
      if (head.toString().contains('\r\n\r\n')) break;
    }
    final lines = head.toString().split('\r\n');
    final range = lines
        .where((l) => l.toLowerCase().startsWith('range:'))
        .map((l) => l.substring(6).trim())
        .firstOrNull;

    if (redirectFirst) {
      redirectFirst = false;
      socket.write(
        'HTTP/1.1 302 Found\r\nLocation: /cdn/model.bin\r\nContent-Length: 0\r\n'
        'Connection: close\r\n\r\n',
      );
      await socket.flush();
      await socket.close();
      return;
    }
    rangeHeaders.add(range);

    var start = 0;
    final headers = StringBuffer();
    if (range != null && !ignoreRange) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)![1]!);
      headers
        ..write('HTTP/1.1 206 Partial Content\r\n')
        ..write('Content-Range: bytes $start-${body.length - 1}/${body.length}\r\n');
    } else {
      headers.write('HTTP/1.1 200 OK\r\n');
    }
    final slice = body.sublist(start);
    headers.write('Content-Length: ${slice.length}\r\nConnection: close\r\n\r\n');
    socket.write(headers.toString());

    final cut = dropAfter;
    dropAfter = null;
    for (var offset = 0; offset < slice.length; offset += _chunk) {
      final end = (offset + _chunk).clamp(0, slice.length);
      if (cut != null && end > cut) {
        socket.add(slice.sublist(offset, cut));
        await socket.flush();
        socket.destroy(); // Abrupt drop, like a lost connection or killed app.
        return;
      }
      socket.add(slice.sublist(offset, end));
      await socket.flush();
    }
    await socket.close();
  }

  Future<void> stop() => _server.close();
}

void main() {
  final body = Uint8List.fromList(List.generate(2000000, (i) => i * 31 % 256));
  final digest = sha256.convert(body).toString();
  late Directory dir;
  late _FileServer server;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pb_download_');
    server = _FileServer(body);
    await server.start();
  });

  tearDown(() async {
    await server.stop();
    await dir.delete(recursive: true);
  });

  DownloadSpec spec({String? sha}) => DownloadSpec(
    url: server.url,
    target: File('${dir.path}/model.bin'),
    expectedBytes: body.length,
    sha256: sha ?? digest,
  );

  ResumableDownloader downloader({int maxAttempts = 1}) => ResumableDownloader(
    http.Client(),
    const SilentLogger(),
    maxAttempts: maxAttempts,
    retryDelay: Duration.zero,
    idleTimeout: const Duration(seconds: 5),
  );

  test('downloads and verifies a file', () async {
    final file = await downloader().download(spec(), onProgress: (_) {}, isCancelled: () => false);
    expect(await file.readAsBytes(), body);
    expect(spec().partial.existsSync(), isFalse);
  });

  // The reported bug: an interrupted download restarted from 0.
  test('after an interruption, a new download resumes from the bytes on disk', () async {
    server.dropAfter = 1200000;
    await expectLater(
      downloader().download(spec(), onProgress: (_) {}, isCancelled: () => false),
      throwsA(anything),
    );
    final kept = spec().partial.lengthSync();
    expect(kept, greaterThan(0), reason: 'partial bytes must survive the interruption');
    expect(ResumableDownloader.bytesOnDisk(spec()), kept);

    // A fresh downloader = a restarted app.
    final progress = <int>[];
    final file = await downloader().download(
      spec(),
      onProgress: progress.add,
      isCancelled: () => false,
    );
    expect(server.rangeHeaders.last, 'bytes=$kept-');
    expect(progress.first, kept, reason: 'progress continues, not from zero');
    expect(await file.readAsBytes(), body);
  });

  test('retries transient drops within one attempt', () async {
    server.dropAfter = 500000;
    final file = await downloader(maxAttempts: 3)
        .download(spec(), onProgress: (_) {}, isCancelled: () => false);
    expect(await file.readAsBytes(), body);
    expect(server.rangeHeaders, [null, startsWith('bytes=')]);
  });

  test('cancel keeps the partial file for a later resume', () async {
    var cancel = false;
    await expectLater(
      downloader().download(
        spec(),
        onProgress: (bytes) => cancel = bytes > 0,
        isCancelled: () => cancel,
      ),
      throwsA(isA<DownloadCancelledException>()),
    );
    expect(spec().partial.existsSync(), isTrue);
  });

  test('restarts correctly when the server ignores Range', () async {
    server.dropAfter = 800000;
    await expectLater(
      downloader().download(spec(), onProgress: (_) {}, isCancelled: () => false),
      throwsA(anything),
    );
    server.ignoreRange = true;
    final file = await downloader().download(spec(), onProgress: (_) {}, isCancelled: () => false);
    expect(await file.readAsBytes(), body);
  });

  test('keeps the Range header across redirects', () async {
    server.dropAfter = 900000;
    await expectLater(
      downloader().download(spec(), onProgress: (_) {}, isCancelled: () => false),
      throwsA(anything),
    );
    server.redirectFirst = true;
    final file = await downloader().download(spec(), onProgress: (_) {}, isCancelled: () => false);
    expect(server.rangeHeaders.last, startsWith('bytes='));
    expect(await file.readAsBytes(), body);
  });

  test('a corrupt file is rejected and discarded', () async {
    await expectLater(
      downloader().download(
        spec(sha: '0' * 64),
        onProgress: (_) {},
        isCancelled: () => false,
      ),
      throwsA(isA<DownloadIntegrityException>()),
    );
    expect(spec().partial.existsSync(), isFalse);
    expect(spec().target.existsSync(), isFalse);
  });
}
