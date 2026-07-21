import 'package:url_launcher/url_launcher.dart';

Future<bool> openSupportContactWithPlatform(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
