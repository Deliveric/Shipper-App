import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/session.dart';
import '../core/theme.dart';

const _loginUrl = 'https://deliveric.net/admin-area/login.php';

/// A page of the real Deliveric shipper portal shown inside the app.
/// The app signs in to the portal by itself with the same login, hides the
/// portal's own header/sidebar and restyles the page (see _baseCss / _js*).
class PortalScreen extends StatefulWidget {
  final String title;
  final String url;
  final String kind; // 'shipments' | 'wallet'
  const PortalScreen({super.key, required this.title, required this.url, this.kind = ''});
  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

// ---------------------------------------------------------------- styles
const _baseCss = r'''
:root{--o:#E2964E;--d:#1B1B17;--c:#26261F;--c2:#33332A;--t:#F4EFE8;--m:#A9A395}
html,body{background:var(--d)!important;color:var(--t)!important;font-family:Ubuntu,Cairo,Segoe UI,Arial,sans-serif!important}
.page-header.navbar-fixed-top,.page-sidebar-wrapper,.page-footer,.modern-breadcrumb,.modern-header-bar,.alert-warning,.alert-info,.page-quick-sidebar-wrapper,.page-bar{display:none!important}
body,.page-header-fixed{padding-top:0!important;margin:0!important}
.page-container{margin-top:0!important;padding-top:0!important}
.page-content-wrapper{margin:0!important}
.page-content-wrapper .page-content,.page-content{margin-left:0!important;margin-top:0!important;padding:10px 10px 120px!important;background:transparent!important;min-height:0!important}
a{color:var(--o)!important}
.btn-primary,.btn-success,.btn-warning,button[type=submit],input[type=submit],.btn-info{background:var(--o)!important;border-color:var(--o)!important;color:#1b1b17!important;border-radius:12px!important}
.portlet,.portlet-body,.portlet.box,.panel,.panel-body,.well,.box,.bg-white,.white,.modal-content,.dropdown-menu,.form{background:var(--c)!important;color:var(--t)!important;border-color:#33332a!important;border-radius:14px!important}
.portlet>.portlet-title,.portlet.box>.portlet-title{background:var(--c2)!important;color:var(--t)!important}
table,th,td,tr,.table{background-color:transparent!important;color:var(--t)!important;border-color:#3a3a30!important}
.table-striped>tbody>tr:nth-of-type(odd){background-color:rgba(255,255,255,.03)!important}
thead th{background:var(--c2)!important;color:var(--o)!important}
input,select,textarea,.form-control,.select2-container .select2-choice,.select2-container--default .select2-selection--single{background:var(--d)!important;color:var(--t)!important;border:1px solid #3d3d33!important;border-radius:10px!important}
input::placeholder,textarea::placeholder{color:var(--m)!important}
label,.control-label,h1,h2,h3,h4,h5,h6{color:var(--t)!important}
.text-muted,small{color:var(--m)!important}
.pagination>li>a,.dataTables_wrapper .dataTables_paginate .paginate_button{background:var(--c)!important;color:var(--t)!important;border-color:#33332a!important}
.pagination>.active>a,.pagination>.active>span{background:var(--o)!important;color:#1b1b17!important;border-color:var(--o)!important}
.label{border-radius:10px!important}
img{max-width:100%}
''';

const _shipmentsCss = r'''
.panel-group .panel,.accordion .panel{background:var(--c)!important;border:0!important;border-radius:14px!important;margin-bottom:10px!important;overflow:hidden}
.panel-group .panel-heading,.accordion .panel-heading,.panel-default>.panel-heading{background:var(--c2)!important;color:var(--t)!important;border:0!important;border-left:4px solid var(--o)!important;padding:12px!important}
.panel-heading a,.panel-heading *{color:var(--t)!important}
.panel-body{overflow-x:auto!important;padding:6px!important;-webkit-overflow-scrolling:touch}
.panel-body table{font-size:12px;white-space:nowrap}
''';

const _walletCss = r'''
#wallet-chips{margin:4px 0 12px}
#wallet-chips .big{display:flex;gap:10px}
#wallet-chips .chip{flex:1;border-radius:18px;padding:14px 12px;text-align:center}
#wallet-chips .chip .l{display:block;font-size:12px;color:var(--m)}
#wallet-chips .chip .v{display:block;font-size:22px;font-weight:700;margin-top:4px;color:var(--t)}
#wallet-chips .t-net{background:var(--c);border:1.5px solid var(--o)}
#wallet-chips .t-net .v{color:var(--o)}
#wallet-chips .t-main{background:var(--o)}
#wallet-chips .t-main .l,#wallet-chips .t-main .v{color:#1b1b17}
#wallet-chips details{margin-top:10px;background:var(--c);border-radius:14px;padding:8px 12px}
#wallet-chips summary{color:var(--m);font-size:13px}
#wallet-chips .small{display:flex;flex-wrap:wrap;gap:8px;margin-top:8px}
#wallet-chips .small .chip{flex:1 1 45%;background:var(--c2);padding:8px;border-radius:12px}
#wallet-chips .small .chip .v{font-size:14px}
#table{display:block;overflow-x:auto;font-size:12px;white-space:nowrap;-webkit-overflow-scrolling:touch}
''';

const _walletJs = r'''
(function(){
  var row=document.querySelector('.row.big');
  if(!row||row.getAttribute('data-done'))return;
  row.setAttribute('data-done','1');
  var cells=[].slice.call(row.children);
  var net=null,main=null,rest=[];
  cells.forEach(function(c){
    var t=c.textContent.replace(/\s+/g,' ').trim(); var i=t.indexOf(':');
    if(i<0)return;
    var item={l:t.slice(0,i).trim(),v:t.slice(i+1).trim()};
    if(/Transferable/i.test(item.l))main=item;
    else if(/Net Deserved/i.test(item.l))net=item;
    else rest.push(item);
    c.style.display='none';
  });
  function chip(it,cls,money){
    var d=document.createElement('div');d.className='chip '+cls;
    var l=document.createElement('span');l.className='l';l.textContent=it.l;
    var v=document.createElement('b');v.className='v';
    var val=it.v.replace(/\$\s*$/,'').trim();
    v.textContent=money?('EGP '+val):it.v;
    d.appendChild(l);d.appendChild(v);return d;
  }
  var wrap=document.createElement('div');wrap.id='wallet-chips';
  var big=document.createElement('div');big.className='big';
  if(net)big.appendChild(chip(net,'t-net',true));
  if(main)big.appendChild(chip(main,'t-main',true));
  wrap.appendChild(big);
  if(rest.length){
    var det=document.createElement('details');
    var sm=document.createElement('summary');sm.textContent='More details';det.appendChild(sm);
    var small=document.createElement('div');small.className='small';
    rest.forEach(function(it){small.appendChild(chip(it,'',false));});
    det.appendChild(small);wrap.appendChild(det);
  }
  row.parentNode.insertBefore(wrap,row);
})();
''';

// ---------------------------------------------------------------- screen
class _PortalScreenState extends State<PortalScreen> {
  WebViewController? _c;
  int _progress = 0;
  bool _canBack = false;
  bool _loginFailed = false;
  bool _retried = false;
  int _stage = 0; // 0 = signing in, 1 = target page

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Brand.dark)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageFinished: _onFinished,
        onNavigationRequest: (req) {
          final u = Uri.parse(req.url);
          if (u.scheme == 'tel' || u.scheme == 'sms' || u.scheme == 'mailto' || u.scheme == 'whatsapp' ||
              u.host.contains('wa.me') || u.host.contains('whatsapp.com')) {
            launchUrl(u, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
    _signIn();
  }

  Future<void> _signIn() async {
    _stage = 0;
    final u = Session.I.portalUser, p = Session.I.portalPass;
    if (u == null || p == null) {
      _stage = 1;
      await _c!.loadRequest(Uri.parse(widget.url));
      return;
    }
    final body = 'location=&email=${Uri.encodeQueryComponent(u)}&password=${Uri.encodeQueryComponent(p)}&remember-me=1&authorize=1';
    await _c!.loadRequest(
      Uri.parse(_loginUrl),
      method: LoadRequestMethod.post,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: Uint8List.fromList(utf8.encode(body)),
    );
  }

  Future<void> _onFinished(String url) async {
    if (_stage == 0) {
      _stage = 1;
      await _c!.loadRequest(Uri.parse(widget.url));
      return;
    }
    if (url.contains('login.php')) {
      if (!_retried) {
        _retried = true;
        await _signIn();
      } else if (mounted) {
        setState(() => _loginFailed = true);
      }
      return;
    }
    await _inject();
    final b = await _c!.canGoBack();
    if (mounted) setState(() => _canBack = b);
  }

  Future<void> _inject() async {
    final css = _baseCss +
        (widget.kind == 'shipments' ? _shipmentsCss : '') +
        (widget.kind == 'wallet' ? _walletCss : '');
    await _c!.runJavaScript('''
(function(){
  var m=document.querySelector('meta[name=viewport]');
  if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}
  m.content='width=device-width, initial-scale=1';
  var s=document.getElementById('deliveric-app-style');
  if(!s){s=document.createElement('style');s.id='deliveric-app-style';document.head.appendChild(s);}
  s.textContent=${jsonEncode(css)};
})();''');
    if (widget.kind == 'wallet') await _c!.runJavaScript(_walletJs);
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
                child: Text('Open ${widget.title.toLowerCase()}'),
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
        body: _loginFailed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_outline, color: Brand.orange, size: 40),
                    const SizedBox(height: 12),
                    const Text('Could not sign in to the portal automatically.\nLog out from Profile and sign in again.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loginFailed = false;
                          _retried = false;
                        });
                        _signIn();
                      },
                      child: const Text('Retry'),
                    ),
                  ]),
                ),
              )
            : WebViewWidget(controller: _c!),
      ),
    );
  }
}
