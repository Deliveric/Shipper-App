import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

/// Small copy icon: copies [text] and shows a short confirmation.
class CopyButton extends StatelessWidget {
  final String text;
  const CopyButton(this.text, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 1), content: Text('Copied $text')));
          }
        },
        child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 16, color: Brand.muted)),
      );
}
