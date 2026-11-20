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

  const note = 'Status by sender: cancel confirmation';
  // The server answered "Change Failed" to the first shape, so the request shapes below
  // are tried one after the other (all ask for the same change) until one succeeds.
  final variants = <Map<String, dynamic>>[
    {'ids': [id], 'status_id': statusId, 'notes': note},
    {'shipment_ids': [id], 'status_id': statusId, 'notes': note},
    {'ids': id, 'status_id': statusId, 'notes': note},
    {'ids': [id], 'status': statusId, 'notes': note},
    {'id': id, 'status_id': statusId, 'notes': note},
    {'ids': [id], 'status_id': statusId, 'note': note},
    {'ids': [id], 'status_id': int.tryParse(statusId) ?? statusId, 'notes': note, 'store_id': ''},
  ];
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Brand.card,
      title: Text('Change $waybill to "$statusName"?'),
      content: SingleChildScrollView(
        child: SelectableText(
            'This is a REAL change on Deliveric.\n\nPOST change_shipments_status.php, trying up to ${variants.length} request formats until one works. First one:\n${const JsonEncoder.withIndent('  ').convert(variants.first)}',
            style: const TextStyle(fontSize: 12.5)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  // 2. send; stop at the first reply without "errors"
  final log = StringBuffer();
  for (var n = 0; n < variants.length; n++) {
    String line;
    bool success = false;
    try {
      final r = await Api.post('change_shipments_status.php', variants[n]);
      success = r is Map && r['errors'] == null && r['status'] != false;
      line = jsonEncode(r);
    } catch (e) {
      line = 'ERROR: $e';
    }
    log.writeln('#${n + 1} ${jsonEncode(variants[n])}\n   -> $line\n');
    if (success) break;
  }
  final reply = log.toString();

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
