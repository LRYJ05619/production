import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

class AppVersionInfo {
  final int id;
  final String version;
  final int versionCode;
  final String releaseNote;
  final String fileName;
  final int fileSize;
  final bool forceUpdate;

  const AppVersionInfo({
    required this.id,
    required this.version,
    required this.versionCode,
    required this.releaseNote,
    required this.fileName,
    required this.fileSize,
    required this.forceUpdate,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => AppVersionInfo(
    id: json['id'] as int,
    version: json['version'] as String,
    versionCode: json['version_code'] as int,
    releaseNote: json['release_note'] as String? ?? '',
    fileName: json['file_name'] as String? ?? '',
    fileSize: json['file_size'] as int? ?? 0,
    forceUpdate: json['force_update'] as bool? ?? false,
  );
}

class UpdateService {
  // "v0.9.29" → 0*100000 + 9*1000 + 29 = 9029，与服务端 version_code 规则一致
  static int parseVersionCode(String version) {
    final cleaned = version.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = cleaned.split('.');
    if (parts.length < 3) return 0;
    final major = int.tryParse(parts[0]) ?? 0;
    final minor = int.tryParse(parts[1]) ?? 0;
    final patch = int.tryParse(parts[2]) ?? 0;
    return major * 100000 + minor * 1000 + patch;
  }

  /// 检查是否有新版本；有则返回 [AppVersionInfo]，无则返回 null
  static Future<AppVersionInfo?> checkForUpdate(String currentVersion) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}${ApiService.apiPrefix}/app/latest');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['code'] == 200) {
          final info = AppVersionInfo.fromJson(json['data'] as Map<String, dynamic>);
          if (info.versionCode > parseVersionCode(currentVersion)) {
            return info;
          }
        }
      }
    } catch (e) {
      debugPrint('[更新] 检查版本失败: $e');
    }
    return null;
  }

  /// 下载 APK；[onProgress] 接收 0.0~1.0 进度，[isCancelled] 返回 true 时中止
  /// 成功返回本地文件路径，失败或取消返回 null
  static Future<String?> downloadApk({
    required String version,
    required void Function(double) onProgress,
    required bool Function() isCancelled,
  }) async {
    final client = http.Client();
    try {
      final safeVersion = version.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final uri = Uri.parse(
        '${ApiService.baseUrl}${ApiService.apiPrefix}/app/download'
        '?version=${Uri.encodeComponent(version)}',
      );
      final request = http.Request('GET', uri);
      final token = ApiService.getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      final response = await client.send(request);
      if (response.statusCode != 200) return null;

      final total = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update_$safeVersion.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      int received = 0;
      await for (final chunk in response.stream) {
        if (isCancelled()) {
          await sink.close();
          file.deleteSync();
          return null;
        }
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.flush();
      await sink.close();
      return filePath;
    } catch (e) {
      debugPrint('[更新] 下载APK失败: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// 打开 APK 触发系统安装器
  static Future<void> installApk(String filePath) async {
    await OpenFile.open(filePath, type: 'application/vnd.android.package-archive');
  }
}