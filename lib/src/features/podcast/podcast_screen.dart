import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PodcastScreen extends StatelessWidget {
  const PodcastScreen({super.key});

  static const List<_PodcastChannel> _channels = [
    _PodcastChannel(
      title: 'Canal 1',
      subtitle: 'Abrir programa no Spotify',
      url: 'https://open.spotify.com/show/36pSkw1EtZgTnNrXmJcNPm',
    ),
    _PodcastChannel(
      title: 'Canal 2',
      subtitle: 'Abrir programa no Spotify',
      url: 'https://open.spotify.com/show/7iH3UWkTdoQ6OtYxsjJKut',
    ),
  ];

  Future<void> _openChannel(BuildContext context, String url) async {
    final uri = Uri.parse(url);

    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }

    if (await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o link do Spotify.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Podcast')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Escolha um canal para abrir diretamente no Spotify.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'A página foi simplificada para acesso direto aos programas, sem consulta à API do Spotify.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final channel in _channels)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openChannel(context, channel.url),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.podcasts_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    channel.title,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(channel.subtitle),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          channel.url,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => _openChannel(context, channel.url),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Abrir no Spotify'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PodcastChannel {
  final String title;
  final String subtitle;
  final String url;

  const _PodcastChannel({
    required this.title,
    required this.subtitle,
    required this.url,
  });
}
