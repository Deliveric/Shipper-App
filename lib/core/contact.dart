import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'session.dart';
import 'strings.dart';
import 'theme.dart';

/// 01200221822 -> 201200221822 (WhatsApp needs the country code; Egypt).
String waNumber(String phone) {
  var wa = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (wa.startsWith('00')) {
    wa = wa.substring(2);
  } else if (wa.startsWith('0')) {
    wa = '20${wa.substring(1)}';
  } else if (wa.length == 10 && wa.startsWith('1')) {
    wa = '20$wa';
  }
  return wa;
}

bool get _mobileWeb => kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

Future<void> callCustomer(String phone) async {
  await launchUrl(Uri.parse('tel:$phone'), webOnlyWindowName: '_self');
}

/// On a phone's web app the WhatsApp app is opened directly in the same window, so the
/// app is still on the same page when you come back (wa.me opened a blank browser sheet).
Future<void> _openWa(String wa, String text) async {
  final t = Uri.encodeComponent(text);
  if (_mobileWeb) {
    await launchUrl(Uri.parse('whatsapp://send?phone=$wa&text=$t'), webOnlyWindowName: '_self');
  } else {
    await launchUrl(Uri.parse('https://wa.me/$wa?text=$t'), mode: LaunchMode.externalApplication);
  }
}

/// Pick one of the ready messages, then WhatsApp opens with it typed in.
Future<void> whatsappCustomer(BuildContext context, Map s) async {
  final wa = waNumber(Api.phone(s));
  if (wa.isEmpty) return;
  // drop quotes / symbols / spaces around the name and squeeze inner spaces
  final name = Api.name(s).replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '').replaceAll(RegExp(r'\s+'), ' ');
  final product = Api.pick(s, ['product_name']);
  final merchant = '${s['_account'] ?? Session.I.userName ?? ''}';
  // merchant's own Order ID only; without it the message just says "your order" (no waybill number)
  final orderNo = Api.pick(s, ['order_id']);
  final head = 'أهلاً $name 👋 معاك $merchant.\n${orderNo.isEmpty ? 'بخصوص طلب حضرتك' : 'بخصوص طلبك رقم $orderNo'}'
      '${product.isEmpty ? '' : '\nحضرتك كنت طالب\n($product)'}';
  final msgs = <(String, String)>[
    ('Confirm purchase', '$head،\nلسه عايز تستلمه؟ لو آه رد بـ "نعم" وهنرتب التسليم، ولو لأ رد بـ "لا".'),
    ('No answer', '$head،\nالمندوب حاول يتواصل معاك ومردتش. إمتى يناسبك تستلمه؟'),
  ];
  final pick = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Brand.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tl('Send on WhatsApp'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final m in msgs)
            Card(
              color: Brand.card2,
              child: ListTile(
                leading: Image.asset('assets/image/whatsapp.png', width: 30, height: 30),
                title: Text(tl(m.$1), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(m.$2, style: const TextStyle(fontSize: 12.5, color: Brand.muted))),
                onTap: () => Navigator.pop(c, m.$2),
              ),
            ),
        ]),
      ),
    ),
  );
  if (pick != null) await _openWa(wa, pick);
}

/// the two round buttons shown on every shipment card
class ContactButtons extends StatelessWidget {
  final Map s;
  const ContactButtons(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final phone = Api.phone(s);
    if (phone.isEmpty) return const SizedBox.shrink();
    Widget btn(Widget icon, Color bg, Color border, VoidCallback f) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: f,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: border, width: 1.5)),
            child: Center(child: icon),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(const Icon(Icons.call, size: 19, color: Brand.orange), Colors.transparent, Brand.orange, () => callCustomer(phone)),
      const SizedBox(width: 8),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => whatsappCustomer(context, s),
        child: Image.asset('assets/image/whatsapp.png', width: 38, height: 38),
      ),
    ]);
  }
}
