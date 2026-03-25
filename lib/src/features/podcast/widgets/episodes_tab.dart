import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../episode_model.dart';

class EpisodesTabWidget extends StatefulWidget {
  final Future<List<Episode>> Function() loadEpisodes;
  const EpisodesTabWidget({super.key, required this.loadEpisodes});

  @override
  State<EpisodesTabWidget> createState() => _EpisodesTabWidgetState();
}

class _EpisodesTabWidgetState extends State<EpisodesTabWidget> {
  late Future<List<Episode>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loadEpisodes();
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Episode>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erro ao carregar episódios:\n${snapshot.error}'),
            ),
          );
        }
        final eps = snapshot.data ?? const <Episode>[];
        if (eps.isEmpty) {
          return const Center(child: Text('Nenhum episódio encontrado.'));
        }
        return ListView.separated(
          itemCount: eps.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = eps[i];
            return ListTile(
              leading: const Icon(Icons.podcasts_outlined),
              title: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(e.releaseDate.toLocal().toIso8601String().split('T').first),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => _open(e.externalUrl), // expects String
            );
          },
        );
      },
    );
  }
}
