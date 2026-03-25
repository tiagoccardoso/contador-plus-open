import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NormasScreen extends StatelessWidget {
  const NormasScreen({super.key});

  static const _url =
      'http://normas.receita.fazenda.gov.br/sijut2consulta/consulta.action';

  Future<void> _abrirNoNavegador(BuildContext context) async {
    final uri = Uri.parse(_url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o navegador.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Normas (RFB)')),
      body: Center(
        child: FilledButton.icon(
          onPressed: () => _abrirNoNavegador(context),
          icon: const Icon(Icons.open_in_browser),
          label: const Text('Abrir Normas da RFB'),
        ),
      ),
    );
  }
}
