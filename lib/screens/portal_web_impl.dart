// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

/// Web: shows a portal page in an iframe served from the same address as the
/// app (Render forwards /admin-area/* to deliveric.net), signs in with a hidden
/// form, then injects the app styling into the page.
class PortalWeb extends StatefulWidget {
  final String path, css, js, user, pass;
  const PortalWeb({super.key, required this.path, required this.css, required this.js, required this.user, required this.pass});
  @override
  State<PortalWeb> createState() => _PortalWebState();
}

int _n = 0;

class _PortalWebState extends State<PortalWeb> {
  late final String _viewType;
  late final html.IFrameElement _f;
  int _stage = 0;

  @override
  void initState() {
    super.initState();
    final id = 'portal-frame-${_n++}';
    _viewType = id;
    _f = html.IFrameElement()
      ..name = id
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.background = '#1B1B17';
    _f.onLoad.listen((_) => _loaded());
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _f);
    if (widget.user.isNotEmpty) {
      final form = html.FormElement()
        ..method = 'post'
        ..action = '/admin-area/login.php'
        ..target = id
        ..style.display = 'none';
      void field(String n, String v) => form.append(html.InputElement()
        ..type = 'hidden'
        ..name = n
        ..value = v);
      field('location', '');
      field('email', widget.user);
      field('password', widget.pass);
      field('remember-me', '1');
      field('authorize', '1');
      html.document.body!.append(form);
      form.submit();
      form.remove();
    } else {
      _stage = 1;
      _f.src = widget.path;
    }
  }

  void _loaded() {
    if (_stage == 0) {
      _stage = 1;
      _f.src = widget.path;
      return;
    }
    try {
      final doc = (_f.contentWindow as dynamic).document as html.HtmlDocument;
      final m = doc.createElement('meta')..setAttribute('name', 'viewport')..setAttribute('content', 'width=device-width, initial-scale=1');
      doc.head!.append(m);
      final s = doc.createElement('style')..text = widget.css;
      doc.head!.append(s);
      final sc = doc.createElement('script')..text = widget.js;
      doc.body!.append(sc);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
