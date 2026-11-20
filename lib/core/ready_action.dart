import 'dart:convert';
import 'package:flutter/material.dart';
import 'api.dart';
import 'data.dart';
import 'theme.dart';

/// REAL call: asks Deliveric to change a shipment to "Ready for delivery".
/// The exact request is shown first, the raw reply is shown after, then the
/// shipment is re-read so you can see its new status and history.
Future<void> readyForDelivery(BuildContext context, Map<String, dynamic> s) async {
  final id = Api.pick(s, ['id', 'shipment_id']);
  final waybill = Api.pick(s, ['waybill']);
  Future<void> info(String title, String body) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Brand.card,
          title: Text(title),
          content: SingleChildScrollView(child: SelectableText(body, style: const TextStyle(fontSize: 12.5))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  // The status the website sets when the shipper presses "Ready for delivery".
  const statusId = '155';
  const statusName = 'Ready for Receiving (by Shipper)';

  final payload = {
    'ids': [id],
    'status_id': statusId,
    'notes': 'Status by sender: cancel confirmation',
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Brand.card,
      title: Text('Change $waybill to "$statusName"?'),
      content: SingleChildScrollView(
        child: SelectableText('This is a REAL change on Deliveric.\n\nPOST change_shipments_status.php\n${const JsonEncoder.withIndent('  ').convert(payload)}',
            style: const TextStyle(fontSize: 12.5)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  // 2. send and show the raw reply
  String reply;
  try {
    reply = const JsonEncoder.withIndent('  ').convert(await Api.post('change_shipments_status.php', payload));
  } catch (e) {
    reply = 'ERROR: $e';
  }

  // 3. track: re-read the shipment
  String now = '';
  try {
    final r = await Api.post('shipment.php', {'id': id, 'app': 'shipper'});
    final d = r is Map ? r['shipment'] : null;
    if (d is Map) {
      final h = (d['historyStatus'] is List ? d['historyStatus'] as List : []).whereType<Map>().toList();
      now = 'Status now: ${d['status']}\n\nLatest history:\n${h.reversed.take(4).map((e) => '• ${e['status']}  ${e['date_added']}').join('\n')}';
    }
  } catch (e) {
    now = 'Could not re-read the shipment: $e';
  }
  await AppData.I.refresh();
  if (context.mounted) await info('Reply from Deliveric', '$reply\n\n$now');
}
