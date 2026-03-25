import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable; // <- ADICIONE ESTA LINHA
import 'package:url_launcher/url_launcher.dart';

class OuvirTab extends StatelessWidget {
  // Mantemos um Map do episódio selecionado, simples e robusto
  final ValueListenable<Map<String, dynamic>?> selectedEpisode;
  const OuvirTab({super.key, required this.selectedEpisode});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: selectedEpisode,
      builder: (context, ep, _) {
        if (ep == null) {
          return const Center(
            child: Text('Selecione um episódio na aba Episódios para ouvir.'),
          );
        }

        final title = ep['name'] ?? 'Episódio';
        final images = (ep['images'] as List?) ?? const [];
        final imageUrl = images.isNotEmpty ? images.first['url'] as String? : null;
        final spotifyUrl =
        (ep['external_urls'] != null) ? ep['external_urls']['spotify'] as String? : null;
        final description = ep['description'] ?? '';

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(imageUrl, width: 240, height: 240, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(description),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Abrir no Spotify'),
                  onPressed: (spotifyUrl == null)
                      ? null
                      : () async {
                    final uri = Uri.parse(spotifyUrl);
                    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                      await launchUrl(uri, mode: LaunchMode.platformDefault);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
