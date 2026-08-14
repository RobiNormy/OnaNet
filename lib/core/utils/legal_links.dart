import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class OnaNetLegalLinks {
  static final privacy = Uri.parse('https://onanet.app/privacy');
  static final terms = Uri.parse('https://onanet.app/terms');
  static final accountDeletion = Uri.parse('https://onanet.app/delete-account');
}

Future<void> openOnaNetLegalLink(BuildContext context, Uri uri) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the legal page.')),
    );
  }
}
