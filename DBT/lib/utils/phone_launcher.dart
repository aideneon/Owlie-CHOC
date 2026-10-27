import 'package:url_launcher/url_launcher.dart';

Future<bool> launchPhoneCall(String phoneNumber) async {
  final digits = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) return false;

  final uri = Uri(scheme: 'tel', path: digits);
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri);
  }
  return false;
}

Future<bool> launchWebUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

Future<bool> launchSms(String phoneNumber, {String? body}) async {
  final digits = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) return false;

  final uri = Uri(
    scheme: 'sms',
    path: digits,
    queryParameters: body == null ? null : {'body': body},
  );
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri);
  }
  return false;
}
