import 'package:flutter/material.dart';
import '../../shared/open_link.dart';
import 'official_links.dart';

/// Card pronto para a Home com fontes oficiais sobre a Reforma Tributária.
class ReformaCardHome extends StatelessWidget {
  final String? dominioSearchBaseUrl; // público opcional
  const ReformaCardHome({super.key, this.dominioSearchBaseUrl});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.balance),
        title: const Text('Reforma Tributária — fontes oficiais'),
        subtitle: const Text('Receita Federal, Ministério da Fazenda e Central Domínio'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Receita Federal — Reforma Tributária'),
                  subtitle: const Text('Serviços, pilotos e orientações'),
                  onTap: () => openExternal(OfficialLinks.rfReforma),
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance),
                  title: const Text('Programa da Reforma do Consumo (RFB)'),
                  subtitle: const Text('Hub institucional da Reforma na Receita'),
                  onTap: () => openExternal(OfficialLinks.rfProgramaConsumo),
                ),
                ListTile(
                  leading: const Icon(Icons.policy),
                  title: const Text('Ministério da Fazenda — Reforma Tributária'),
                  subtitle: const Text('Regulamentação e materiais oficiais'),
                  onTap: () => openExternal(OfficialLinks.mfReforma),
                ),
                ListTile(
                  leading: const Icon(Icons.ondemand_video),
                  title: const Text('Vídeos oficiais — Ministério da Fazenda'),
                  onTap: () => openExternal(OfficialLinks.mfVideos),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text('Central de Soluções — Buscar (público)'),
                  subtitle: const Text('Site search (sem login)'),
                  onTap: () => openExternal(
                    OfficialLinks.dominioPublicSearch('Reforma Tributária', dominioSearchBaseUrl),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Central de Soluções — Home'),
                  onTap: () => openExternal(OfficialLinks.dominioPublicHome),
                ),
                ListTile(
                  leading: const Icon(Icons.article),
                  title: const Text('Módulo Reforma Tributária — (pode exigir login)'),
                  onTap: () => openExternal(OfficialLinks.dominioModulo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
