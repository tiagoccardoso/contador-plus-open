import 'package:url_launcher/url_launcher.dart';

/// Abre um [Uri] no navegador/sistema externo.
Future<void> openExternal(Uri url) async {
  final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!ok) {
    throw 'Não foi possível abrir: $url';
  }
}
