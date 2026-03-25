import 'package:flutter/material.dart';
import '../../shared/open_link.dart';
import 'official_links.dart';

/// Seção pronta para a tela "Aprender", com botões para fontes oficiais.
class ReformaSectionLearn extends StatelessWidget {
  final String? dominioSearchBaseUrl; // público opcional
  const ReformaSectionLearn({super.key, this.dominioSearchBaseUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reforma Tributária (oficial)', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.public),
              label: const Text('Receita Federal'),
              onPressed: () => openExternal(OfficialLinks.rfReforma),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.account_balance),
              label: const Text('Programa do Consumo (RFB)'),
              onPressed: () => openExternal(OfficialLinks.rfProgramaConsumo),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.policy),
              label: const Text('Fazenda — Guia/Regulamentação'),
              onPressed: () => openExternal(OfficialLinks.mfReforma),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.ondemand_video),
              label: const Text('Vídeos oficiais'),
              onPressed: () => openExternal(OfficialLinks.mfVideos),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Central Domínio — Buscar (público)'),
              onPressed: () => openExternal(
                OfficialLinks.dominioPublicSearch('Reforma Tributária', dominioSearchBaseUrl),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.home),
              label: const Text('Central Domínio — Home'),
              onPressed: () => openExternal(OfficialLinks.dominioPublicHome),
            ),
          ],
        ),
      ],
    );
  }
}
