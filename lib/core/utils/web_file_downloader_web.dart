// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void downloadFileWeb(Uint8List bytes, String filename, String mimeType) {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Detect iOS devices (iPhone, iPad, iPod) or iPad on iPadOS (which reports as MacIntel with touch)
    final ua = html.window.navigator.userAgent;
    final isIOS = ua.contains('iPhone') ||
        ua.contains('iPad') ||
        ua.contains('iPod') ||
        (html.window.navigator.platform == 'MacIntel' &&
            html.window.navigator.maxTouchPoints != null &&
            html.window.navigator.maxTouchPoints! > 1);

    if (isIOS) {
      // iOS WebKit does not honor the 'download' attribute on <a> tags for Blobs.
      // Opening the PDF / file Blob URL in a new window/tab enables iOS Safari's native viewer,
      // where the user can view, print, or tap Share -> "Save to Files".
      try {
        html.window.open(url, '_blank');
      } catch (_) {
        // Fallback if popup blocker intercepted window.open
        final anchor = html.AnchorElement(href: url)
          ..target = '_blank'
          ..style.display = 'none';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
      }
    } else {
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
    }

    // Do NOT revoke immediately! Safari on iOS processes the blob asynchronously.
    // Delay revocation by 2 minutes to allow the browser to complete rendering / saving.
    Future.delayed(const Duration(minutes: 2), () {
      try {
        html.Url.revokeObjectUrl(url);
      } catch (_) {}
    });
  } catch (_) {}
}
