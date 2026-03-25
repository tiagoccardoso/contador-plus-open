import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/camara/camara_api_client.dart';

class DeputadosFederaisScreen extends StatefulWidget {
  const DeputadosFederaisScreen({super.key});

  @override
  State<DeputadosFederaisScreen> createState() => _DeputadosFederaisScreenState();
}

class _DeputadosFederaisScreenState extends State<DeputadosFederaisScreen> {
  late final CamaraApiV2Client api;
  final txtNome = TextEditingController();
  final txtUf = TextEditingController();
  final txtPartido = TextEditingController();

  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    api = CamaraApiV2Client(appName: 'Contador+', contact: 'contato@contador-plus.app');
    _buscar();
  }

  void _buscar() {
    setState(() {
      _future = api.listarDeputados(
        nome: txtNome.text.trim().isEmpty ? null : txtNome.text.trim(),
        siglaUf: txtUf.text.trim().isEmpty ? null : txtUf.text.trim().toUpperCase(),
        siglaPartido: txtPartido.text.trim().isEmpty ? null : txtPartido.text.trim().toUpperCase(),
        ordenarPor: 'nome',
        ordem: 'ASC',
        itens: 100,
        maxPaginas: 5,
      );
    });
  }

  @override
  void dispose() {
    txtNome.dispose();
    txtUf.dispose();
    txtPartido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deputados Federais')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: txtNome,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Pesquisar por nome',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _buscar(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: ElevatedButton(onPressed: _buscar, child: const Text('Buscar')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: txtUf,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'UF', border: UnderlineInputBorder()),
                      onSubmitted: (_) => _buscar(),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: txtPartido,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Partido', border: UnderlineInputBorder()),
                      onSubmitted: (_) => _buscar(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('Erro: ${snap.error}'));
                    }
                    final dados = snap.data ?? const <Map<String, dynamic>>[];
                    if (dados.isEmpty) {
                      return const Center(child: Text('Nada encontrado.'));
                    }
                    return ListView.separated(
                      itemCount: dados.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final d = dados[i];
                        final nome = (d['nome'] ?? '').toString();
                        final partido = (d['siglaPartido'] ?? '').toString();
                        final uf = (d['siglaUf'] ?? '').toString();
                        final foto = (d['urlFoto'] ?? '').toString();
                        final id = (d['id'] as num).toInt();
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (foto.isNotEmpty) ? NetworkImage(foto) : null,
                            child: (foto.isEmpty) ? Text(nome.isNotEmpty ? nome.characters.first : '?') : null,
                          ),
                          title: Text(nome, overflow: TextOverflow.ellipsis),
                          subtitle: Text('$partido • $uf', overflow: TextOverflow.ellipsis),
                          onTap: () => context.push('/deputados/$id', extra: {'nome': nome}),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
