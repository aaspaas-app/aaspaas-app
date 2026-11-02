import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openUrl(String url) async {
  final u = Uri.tryParse(url);
  if (u == null || url.isEmpty) return false;
  try {
    return await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

void toast(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(content: Text(message)));
}

Future<void> openOrWarn(
  BuildContext context,
  String url, [
  String failMessage = 'Could not open that. Is the app installed?',
]) async {
  final ok = await openUrl(url);
  if (!ok && context.mounted) toast(context, failMessage);
}

Future<void> callNumber(BuildContext context, String number) =>
    openOrWarn(context, 'tel:$number', 'Could not start the call.');
