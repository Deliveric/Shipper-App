import 'package:flutter/widgets.dart';

class PortalWeb extends StatelessWidget {
  final String path, css, js, user, pass;
  const PortalWeb({super.key, required this.path, required this.css, required this.js, required this.user, required this.pass});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
