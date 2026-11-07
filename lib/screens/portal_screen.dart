import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme.dart';

/// Shows a page of the real Deliveric shipper portal inside the app and
/// restyles it (see _css / _js). The portal session (cookies) is kept by the WebView.
class PortalScreen extends StatefulWidget {
  final String title;
  final String url;
  const PortalScreen({super.key, required this.title, required this.url});
  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

const _css = r'''
:root{--o:#E2964E;--d:#1B1B17;--c:#26261F;--t:#F4EFE8;--m:#A9A395}
html,body{background:var(--d)!important;color:var(--t)!important;font-family:Ubuntu,Cairo,Segoe UI,Arial,sans-serif!important}
body{padding-bottom:110px!important;-webkit-tap-highlight-color:transparent}
a{color:var(--o)!important}
.btn-primary,.btn-success,button[type=submit],input[type=submit],.btn-info{background:var(--o)!important;border-color:var(--o)!important;color:#1b1b17!important;border-radius:12px!important}
.card,.panel,.box,.table,.modal-content,.dropdown-menu,.well{background:var(--c)!important;color:var(--t)!important;border-color:#33332a!important;border-radius:14px!important}
table,th,td,tr{background-color:transparent!important;color:var(--t)!important;border-color:#33332a!important}
thead th{color:var(--o)!important}
input,select,textarea,.form-control{background:var(--c)!important;color:var(--t)!important;border:1px solid #3d3d33!important;border-radius:10px!important}
input::placeholder,textarea::placeholder{color:var(--m)!important}
.nav-tabs>li.active>a,.nav-pills>li.active>a,.pagination>.active>a{background:var(--o)!important;color:#1b1b17!important;border-color:var(--o)!important}
.pagination>li>a{background:var(--c)!important;color:var(--t)!important;border-color:#33332a!important}
h1,h2,h3,h4,h5,label,.control-label,.page-title{color:var(--t)!important}
.text-muted,small{color:var(--m)!important}
''';

class _PortalScreenState extends State<PortalScreen> {
  WebViewController? _c;
  int _progress = 0;
  bool _canBack = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Brand.dark)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageFinished: (_) async {
          await _inject();
          final b = await _c!.canGoBack();
          if (mounted) setState(() => _canBack = b);
        },
        onNavigationRequest: (req) {
          final u = Uri.parse(req.url);
          if (u.scheme == 'tel' || u.scheme == 'sms' || u.scheme == 'mailto' || u.scheme == 'whatsapp' ||
              u.host.contains('wa.me') || u.host.contains('whatsapp.com')) {
            launchUrl(u, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _inject() async {
    final css = _css.replaceAll('\n', ' ').replaceAll("'", "\\'");
    await _c!.runJavaScript('''
(function(){
  var m=document.querySelector('meta[name=viewport]');
  if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}
  m.content='width=device-width, initial-scale=1';
  var s=document.getElementById('deliveric-app-style');
  if(!s){s=document.createElement('style');s.id='deliveric-app-style';document.head.appendChild(s);}
  s.textContent='$css';
})();''');
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipOval(child: Image.asset('assets/image/logo.png', width: 120)),
              const SizedBox(height: 16),
              const Text('This page opens inside the Android app.\nOn the web it opens in a new tab.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => launchUrl(Uri.parse(widget.url), webOnlyWindowName: '_blank'),
                child: const Text('Open shipments'),
              ),
            ]),
          ),
        ),
      );
    }
    return PopScope(
      canPop: !_canBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _c!.canGoBack()) await _c!.goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: () => _c!.reload()),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100, color: Brand.orange, minHeight: 3),
                )
              : null,
        ),
        body: WebViewWidget(controller: _c!),
      ),
    );
  }
}
