import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';

/// A build uploaded in Odoo (Custom POS → Configuration → App Updates).
class AppRelease {
  final int id;
  final String version;
  final int build;
  final String notes;
  final bool force;
  final int size;
  final String downloadUrl;

  const AppRelease({
    required this.id,
    required this.version,
    required this.build,
    required this.notes,
    required this.force,
    required this.size,
    required this.downloadUrl,
  });

  factory AppRelease.fromJson(Map<String, dynamic> j) => AppRelease(
        id: (j['id'] as num?)?.toInt() ?? 0,
        version: j['version']?.toString() ?? '',
        build: (j['build'] as num?)?.toInt() ?? 0,
        notes: j['notes']?.toString() ?? '',
        force: j['force'] == true,
        size: (j['size'] as num?)?.toInt() ?? 0,
        downloadUrl: j['download_url']?.toString() ?? '',
      );
}

class InstalledVersion {
  final String name;
  final int build;
  const InstalledVersion(this.name, this.build);
  @override
  String toString() => '$name ($build)';
}

/// In-app update outside Google Play (Android only): ask the server for the
/// newest uploaded build, download it, and open Android's installer. Staff
/// still tap "Install"; Android never lets an app replace itself silently.
/// Google Play forbids this, so drop it from a Play build.
class AppUpdateService {
  static const MethodChannel _channel = MethodChannel('ladolce/app_update');

  static bool get isSupported => Platform.isAndroid;

  final ApiService _api = ApiService();

  Future<InstalledVersion?> installedVersion() async {
    if (!isSupported) return null;
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('appVersion');
      if (m == null) return null;
      return InstalledVersion(
        m['name']?.toString() ?? '',
        (m['build'] as num?)?.toInt() ?? 0,
      );
    } on PlatformException {
      return null;
    }
  }

  /// The newest release on the server, or null when there is none.
  Future<AppRelease?> latestRelease() async {
    final base = await _api.getBaseUrl();
    final res = await http
        .get(Uri.parse('$base/pos/app/latest?platform=android'), headers: _headers())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Update check failed (${res.statusCode})');
    }
    final data = (jsonDecode(res.body) as Map<String, dynamic>)['data'];
    return data is Map ? AppRelease.fromJson(Map<String, dynamic>.from(data)) : null;
  }

  /// A release newer than the installed app, or null when up to date.
  Future<AppRelease?> availableUpdate() async {
    if (!isSupported) return null;
    final installed = await installedVersion();
    final latest = await latestRelease();
    if (installed == null || latest == null) return null;
    return latest.build > installed.build ? latest : null;
  }

  /// Downloads the APK into cache/updates (shared with the installer through
  /// the FileProvider in AndroidManifest.xml) and returns its path.
  Future<String> download(
    AppRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final base = await _api.getBaseUrl();
    final origin = Uri.parse(base).origin;
    final url = release.downloadUrl.startsWith('http')
        ? release.downloadUrl
        : '$origin${release.downloadUrl}';
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (dir.existsSync()) dir.deleteSync(recursive: true); // old downloads
    dir.createSync(recursive: true);
    final file = File('${dir.path}/LaDolce-${release.build}.apk');

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url))..headers.addAll(_headers());
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('Download failed (${res.statusCode})');
      }
      final total = res.contentLength ?? release.size;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && received != total) {
        throw Exception('Download incomplete ($received of $total bytes)');
      }
      return file.path;
    } finally {
      client.close();
    }
  }

  /// "Install unknown apps" allowed for this app (asked once per device).
  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  Future<void> openInstallSettings() => _channel.invokeMethod('openInstallSettings');

  /// Opens Android's installer for [path]; staff confirm with "Install".
  Future<void> install(String path) =>
      _channel.invokeMethod('installApk', {'path': path});

  Map<String, String> _headers() {
    final key = dotenv.env['API_KEY'];
    return {if (key != null && key.isNotEmpty) 'X-API-Key': key};
  }
}
