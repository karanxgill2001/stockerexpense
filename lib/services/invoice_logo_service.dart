import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'google_sheet_service.dart';

class InvoiceLogoService {
  const InvoiceLogoService._();

  static const String _logoFileName = 'invoice_logo.png';

  static Future<String?> getLogoPath({bool refreshFromServer = false}) async {
    final cachedPath = await _getCachedLogoPath();
    if (!refreshFromServer && cachedPath != null) {
      return cachedPath;
    }

    if (refreshFromServer) {
      final refreshedPath = await syncLogoFromServer();
      if (refreshedPath != null) {
        return refreshedPath;
      }
    }

    return cachedPath;
  }

  static Future<bool> hasLogo({bool refreshFromServer = false}) async {
    return (await getLogoPath(refreshFromServer: refreshFromServer)) != null;
  }

  static Future<Uint8List?> loadLogoBytes({bool refreshFromServer = true}) async {
    var path = await getLogoPath(refreshFromServer: false);
    if (path == null && refreshFromServer) {
      path = await getLogoPath(refreshFromServer: true);
    }
    if (path == null) {
      return null;
    }

    return File(path).readAsBytes();
  }

  static Future<String?> syncLogoFromServer() async {
    try {
      final base64Value = await GoogleSheetService.instance.fetchInvoiceLogoBase64(
        forceRefresh: true,
      );
      if (base64Value == null || base64Value.trim().isEmpty) {
        await _clearCachedLogo();
        return null;
      }

      final targetFile = await _getCacheFile();
      await targetFile.writeAsBytes(base64Decode(base64Value), flush: true);
      return targetFile.path;
    } catch (_) {
      return _getCachedLogoPath();
    }
  }

  static Future<String> savePngLogo(File sourceFile) async {
    final extension = sourceFile.path.split('.').last.toLowerCase();
    if (extension != 'png') {
      throw Exception('Only PNG logo files are supported.');
    }

    final bytes = await sourceFile.readAsBytes();
    await GoogleSheetService.instance.updateInvoiceLogoBase64(base64Encode(bytes));

    final targetFile = await _getCacheFile();
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.path;
  }

  static Future<void> clearLogo() async {
    await GoogleSheetService.instance.clearInvoiceLogo();
    await _clearCachedLogo();
  }

  static Future<String?> _getCachedLogoPath() async {
    final file = await _getCacheFile();
    return (await file.exists()) ? file.path : null;
  }

  static Future<void> _clearCachedLogo() async {
    final file = await _getCacheFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<File> _getCacheFile() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/invoice_branding');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return File('${directory.path}/$_logoFileName');
  }
}
