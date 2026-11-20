import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';

/// "Ready for delivery" is done on the Deliveric website page that lists the shipments
/// needing action. The waybill is copied first so it can be pasted into that page.
Future<void> readyForDelivery(BuildContext context, Map<String, dynamic> s) async {
  final waybill = Api.pick(s, ['waybill']);
  await Clipboard.setData(ClipboardData(text: waybill));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $waybill')));
  }
  await launchUrl(Uri.parse('https://deliveric.net/admin-area/need_action_shipper.php'), mode: LaunchMode.externalApplication);
}
