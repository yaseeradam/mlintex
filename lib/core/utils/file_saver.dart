import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'web_file_downloader.dart';

class FileSaver {
  /// Saves / shares PDF bytes cross-platform (Web, iOS, Android, macOS, Windows).
  static Future<void> savePdf(BuildContext context, String filename, List<int> bytes) async {
    final u8bytes = Uint8List.fromList(bytes);

    // Calculate origin Rect for iPad / iOS popovers
    Rect? origin;
    try {
      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          origin = box.localToGlobal(Offset.zero) & box.size;
        }
      }
    } catch (_) {}

    // Fallback origin to center of screen if context renderbox had no size
    if (origin == null && context.mounted) {
      try {
        final mediaQuery = MediaQuery.of(context);
        origin = Rect.fromCenter(
          center: Offset(mediaQuery.size.width / 2, mediaQuery.size.height / 2),
          width: 1,
          height: 1,
        );
      } catch (_) {}
    }

    if (kIsWeb) {
      final xFile = XFile.fromData(
        u8bytes,
        name: filename,
        mimeType: 'application/pdf',
      );
      try {
        final result = await Share.shareXFiles(
          [xFile],
          sharePositionOrigin: origin,
        );
        if (result.status == ShareResultStatus.dismissed) {
          // User dismissed the share sheet cleanly
          return;
        }
        if (result.status == ShareResultStatus.unavailable) {
          // Desktop browser without Web Share API -> trigger clean download
          downloadFileWebPlatform(u8bytes, filename, 'application/pdf');
        }
        return;
      } catch (e) {
        debugPrint('[FileSaver] Web share error: $e');
        downloadFileWebPlatform(u8bytes, filename, 'application/pdf');
        return;
      }
    }

    try {
      // On native iOS and Android, Printing.sharePdf provides the native UIActivityViewController/Sharesheet:
      await Printing.sharePdf(
        bytes: u8bytes,
        filename: filename,
        bounds: origin,
      );
    } catch (e) {
      debugPrint('[FileSaver] Printing.sharePdf error: $e');
      // Secondary fallback using in-memory XFile.fromData
      try {
        final xFile = XFile.fromData(
          u8bytes,
          name: filename,
          mimeType: 'application/pdf',
        );
        await Share.shareXFiles([xFile], sharePositionOrigin: origin);
      } catch (fallbackError) {
        debugPrint('[FileSaver] Fallback share error: $fallbackError');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save PDF: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  /// Saves and shares arbitrary bytes (JSON, images, etc.) cross-platform without path_provider.
  static Future<void> saveFileBytes(
    BuildContext context,
    Uint8List bytes,
    String filename, {
    String mimeType = 'application/octet-stream',
    String? shareText,
    String? subject,
  }) async {
    try {
      Rect? origin;
      try {
        if (context.mounted) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            origin = box.localToGlobal(Offset.zero) & box.size;
          }
        }
      } catch (_) {}

      if (origin == null && context.mounted) {
        try {
          final mediaQuery = MediaQuery.of(context);
          origin = Rect.fromCenter(
            center: Offset(mediaQuery.size.width / 2, mediaQuery.size.height / 2),
            width: 1,
            height: 1,
          );
        } catch (_) {}
      }

      final xFile = XFile.fromData(
        bytes,
        name: filename,
        mimeType: mimeType,
      );

      bool sharedSuccessfully = false;
      try {
        final result = await Share.shareXFiles(
          [xFile],
          text: shareText,
          subject: subject,
          sharePositionOrigin: origin,
        );
        if (result.status != ShareResultStatus.unavailable) {
          sharedSuccessfully = true;
        }
      } catch (e) {
        debugPrint('Share.shareXFiles error: $e');
      }

      // If Web Share API is unavailable on this browser or threw an error, fallback to direct browser download
      if (!sharedSuccessfully && kIsWeb) {
        downloadFileWebPlatform(bytes, filename, mimeType);
      }
    } catch (e) {
      if (kIsWeb) {
        downloadFileWebPlatform(bytes, filename, mimeType);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to export file: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// Saves raw image bytes and shares without requiring path_provider.
  static Future<void> saveImageBytes(BuildContext context, Uint8List bytes, String filename) async {
    await saveFileBytes(
      context,
      bytes,
      filename,
      mimeType: 'image/png',
    );
  }

  /// Saves JSON data bytes and shares without requiring path_provider.
  static Future<void> saveJson(
    BuildContext context,
    String filename,
    Uint8List bytes, {
    String? shareText,
    String? subject,
  }) async {
    await saveFileBytes(
      context,
      bytes,
      filename,
      mimeType: 'application/json',
      shareText: shareText,
      subject: subject,
    );
  }

  /// Shares an image file safely with iPad / popover origin support.
  static Future<void> saveImage(BuildContext context, dynamic file) async {
    try {
      final box = context.mounted ? (context.findRenderObject() as RenderBox?) : null;
      final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
      final path = file is String ? file : (file as dynamic).path as String;
      final name = path.split('/').last;

      await Share.shareXFiles([XFile(path)], text: name, sharePositionOrigin: origin);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to share image: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
