// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<bool> downloadText(String name, String text) async {
  final blob = html.Blob([text], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)..download = name;
  html.document.body!.append(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
