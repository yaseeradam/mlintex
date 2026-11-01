// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void downloadFileWeb(Uint8List bytes, String filename, String mimeType) {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);

    // Do NOT revoke immediately! Safari on iOS processes the blob asynchronously.
    // Delay revocation by 2 minutes to allow the browser to complete rendering / saving.
    Future.delayed(const Duration(minutes: 2), () {
      try {
        html.Url.revokeObjectUrl(url);
      } catch (_) {}
    });
  } catch (_) {}
}
