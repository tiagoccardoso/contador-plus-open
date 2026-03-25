import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../shared/camara/camara_api_client.dart';
import '../../shared/camara/cached_camara_api.dart';

class _VotacaoResumida {
  final String id;
  final String descricao;
  final String resultado;
  final DateTime? data;
  final String meuVoto;
  final String uri;
  final String uriEvento;

  _VotacaoResumida({
    required this.id,
    required this.descricao,
    required this.resultado,
    required this.data,
    required this.meuVoto,
    required this.uri,
    required this.uriEvento,
  });
}

class DeputadoDetailScreen extends StatefulWidget {
  final int id;
  final String? nome;
  const DeputadoDetailScreen({super.key, required this.id, this.nome});

  @override
  State<DeputadoDetailScreen> createState() => _DeputadoDetailScreenState();
}

class _DeputadoDetailScreenState extends State<DeputadoDetailScreen>
    with SingleTickerProviderStateMixin {
  // Favoritos
  final Set<int> _favoritos = <int>{};

  bool get _isFavorito => _favoritos.contains(widget.id);

  Future<void> _loadFavs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList('fav_deputados') ?? const [];
      _favoritos
        ..clear()
        ..addAll(list.map((e) => int.tryParse(e) ?? -1).where((e) => e > 0));
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveFavs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(
          'fav_deputados', _favoritos.map((e) => e.toString()).toList());
    } catch (_) {}
  }

  void _toggleFavorito() {
    setState(() {
      if (_favoritos.contains(widget.id)) {
        _favoritos.remove(widget.id);
      } else {
        _favoritos.add(widget.id);
      }
    });
    _saveFavs();
  }

  // Preferências e controles de performance (persistentes)
  bool _votacoesPorMes = true;
  int _maxVotacoesPorAno = 160;
  int _concorrenciaVotos = 8;

  Future<void> _loadPrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _votacoesPorMes = sp.getBool('vot_por_mes') ?? _votacoesPorMes;
      _maxVotacoesPorAno = sp.getInt('vot_limite_ano') ?? _maxVotacoesPorAno;
      _concorrenciaVotos = sp.getInt('vot_concorrencia') ?? _concorrenciaVotos;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('vot_por_mes', _votacoesPorMes);
      await sp.setInt('vot_limite_ano', _maxVotacoesPorAno);
      await sp.setInt('vot_concorrencia', _concorrenciaVotos);
    } catch (_) {}
  }

  late final CachedCamaraApi api;
  late final TabController _tab;

  Map<String, dynamic>? _perfil;
  List<Map<String, dynamic>> _ocupacoes = const [];
  List<Map<String, dynamic>> _despesas = const [];
  List<Map<String, dynamic>> _discursos = const [];
  List<Map<String, dynamic>> _proposicoes = const [];
  List<_VotacaoResumida> _participacoes = const [];

  bool _loadingPerfil = true;
  bool _loadingDespesas = true;
  bool _loadingDiscursos = true;
  bool _loadingProposicoes = true;
  bool _loadingVotacoes = true;

  int anoDespesas = DateTime.now().year;
  int mesDespesas = 0; // 0 = todos os meses
  int anoProjetos = DateTime.now().year;
  int anoVotacoes = DateTime.now().year;

  final df = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  final dfd = DateFormat('dd/MM/yyyy', 'pt_BR');
  final dm = NumberFormat.simpleCurrency(locale: 'pt_BR');

  @override
  void initState() {
    super.initState();
    _loadFavs();
    _loadPrefs();
    final base = CamaraApiV2Client(
        appName: 'Contador+', contact: 'contato@contador-plus.app');
    api = CachedCamaraApi(base, ttlMinutes: 30);
    _tab = TabController(length: 5, vsync: this);
    _refreshAll(noCache: false);
  }

  Future<void> _refreshAll({required bool noCache}) async {
    await Future.wait([
      _loadPerfil(noCache: noCache),
      _loadDespesas(noCache: noCache),
      _loadDiscursos(noCache: noCache),
      _loadProposicoes(noCache: noCache),
      _loadVotacoes(noCache: noCache),
    ]);
  }

  Future<void> _loadPerfil({required bool noCache}) async {
    setState(() => _loadingPerfil = true);
    try {
      final p = await api.obterDeputado(widget.id, noCache: noCache);
      final o = await api.ocupacoesDeputado(widget.id, noCache: noCache);
      setState(() {
        _perfil = p;
        _ocupacoes = o;
      });
    } finally {
      setState(() => _loadingPerfil = false);
    }
  }

  Future<void> _loadDespesas({required bool noCache}) async {
    setState(() => _loadingDespesas = true);
    try {
      final d = await api.despesasDeputado(
        widget.id,
        ano: anoDespesas,
        mes: (mesDespesas > 0 ? mesDespesas : null),
        itens: 100,
        maxPaginas: 12,
        noCache: noCache,
      );
      setState(() => _despesas = d);
    } finally {
      setState(() => _loadingDespesas = false);
    }
  }

  Future<void> _loadDiscursos({required bool noCache}) async {
    setState(() => _loadingDiscursos = true);
    try {
      final ini = DateTime(DateTime.now().year, 1, 1);
      final fim = DateTime(DateTime.now().year, 12, 31);
      final list = await api.discursosDeputado(
        widget.id,
        dataInicio: ini,
        dataFim: fim,
        itens: 100,
        maxPaginas: 6,
        noCache: noCache,
      );
      setState(() => _discursos = list);
    } finally {
      setState(() => _loadingDiscursos = false);
    }
  }

  Future<void> _loadProposicoes({required bool noCache}) async {
    setState(() => _loadingProposicoes = true);
    try {
      final list = await api.proposicoesDoDeputadoPorAno(
        idDeputado: widget.id,
        ano: anoProjetos,
        itens: 100,
        maxPaginas: 12,
        noCache: noCache,
      );
      setState(() => _proposicoes = list);
    } finally {
      setState(() => _loadingProposicoes = false);
    }
  }

  Future<void> _loadVotacoes({required bool noCache}) async {
    setState(() => _loadingVotacoes = true);
    try {
      final out = <_VotacaoResumida>[];
      int processadas = 0;

      // Função auxiliar para processar uma lista de votações com concorrência
      Future<void> processarLote(List<Map<String, dynamic>> votacoes,
          {required bool incremental}) async {
        int i = 0;

        Future<void> process(Map<String, dynamic> v) async {
          if (processadas >= _maxVotacoesPorAno) return;
          final idV = (v['id'] ?? v['idVotacao'] ?? '').toString();
          if (idV.isEmpty) return;

          List<Map<String, dynamic>> votosDaV = const [];
          try {
            votosDaV = await api.votosDaVotacao(
              idV,
              itens: 100,
              maxPaginas: 3,
              noCache: noCache,
            );
          } catch (_) {}

          final meu = votosDaV.firstWhere(
                (it) {
              final any =
                  it['idDeputado'] ?? it['deputado_']?['id'] ?? it['idParlamentar'];
              final idInt = (any is num)
                  ? any.toInt()
                  : int.tryParse(any?.toString() ?? '');
              return idInt == widget.id;
            },
            orElse: () => const {},
          );
          if (meu.isEmpty) return;

          final data = DateTime.tryParse(
            (v['data'] ??
                v['dataHoraAbertura'] ??
                v['dataHoraRegistro'] ??
                '')
                .toString(),
          );

          out.add(_VotacaoResumida(
            id: idV,
            descricao: (v['descricao'] ?? v['ementa'] ?? '').toString(),
            resultado: (v['resultado'] ?? '').toString(),
            data: data,
            meuVoto: (meu['tipoVoto'] ?? meu['voto'] ?? '').toString(),
            uri: (v['uri'] ?? '').toString(),
            uriEvento:
            (v['uriEvento'] ?? v['evento']?['uri'] ?? '').toString(),
          ));
          processadas++;
        }

        while (i < votacoes.length && processadas < _maxVotacoesPorAno) {
          final batch = votacoes.skip(i).take(_concorrenciaVotos).toList();
          await Future.wait(batch.map(process));
          i += batch.length;
          out.sort((a, b) =>
              (b.data ?? DateTime(0)).compareTo(a.data ?? DateTime(0)));
          if (incremental && mounted) {
            setState(() => _participacoes = List.of(out));
          }
        }
      }

      if (_votacoesPorMes) {
        // Busca mês a mês para reduzir payload e dar feedback mais rápido
        for (int mes = 1; mes <= 12; mes++) {
          if (processadas >= _maxVotacoesPorAno) break;
          final ini = DateTime(anoVotacoes, mes, 1);
          final fim = (mes == 12)
              ? DateTime(anoVotacoes, 12, 31)
              : DateTime(anoVotacoes, mes + 1, 1)
              .subtract(const Duration(days: 1));
          final votacoes = await api.listarVotacoes(
            dataInicio: ini,
            dataFim: fim,
            ordem: 'DESC',
            ordenarPor: 'dataHoraRegistro',
            itens: 100,
            maxPaginas: 4,
            noCache: noCache,
          );
          await processarLote(votacoes, incremental: true);
        }
      } else {
        // Jan-Dez em uma tacada só
        final ini = DateTime(anoVotacoes, 1, 1);
        final fim = DateTime(anoVotacoes, 12, 31);
        final votacoes = await api.listarVotacoes(
          dataInicio: ini,
          dataFim: fim,
          ordem: 'DESC',
          ordenarPor: 'dataHoraRegistro',
          itens: 100,
          maxPaginas: 12,
          noCache: noCache,
        );
        await processarLote(votacoes, incremental: true);
      }

      if (mounted) setState(() => _participacoes = List.of(out));
    } finally {
      setState(() => _loadingVotacoes = false);
    }
  }

  String _titulo() {
    final nome = (_perfil?['ultimoStatus']?['nome'] ??
        _perfil?['nomeCivil'] ??
        widget.nome ??
        'Deputado')
        .toString();
    return nome;
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<double> _monthlyTotals() {
    final totals = List<double>.filled(12, 0.0);
    for (final d in _despesas) {
      final dt = DateTime.tryParse((d['dataDocumento'] ?? '').toString());
      final val = (d['valorLiquido'] as num?)?.toDouble() ?? 0.0;
      if (dt != null &&
          dt.year == anoDespesas &&
          dt.month >= 1 &&
          dt.month <= 12) {
        totals[dt.month - 1] += val;
      }
    }
    return totals;
  }

  Map<String, double> _totaisPorCategoria({List<Map<String, dynamic>>? subset}) {
    final m = <String, double>{};
    final fonte = subset ?? _despesas;
    for (final d in fonte) {
      final tipo = (d['tipoDespesa'] ?? 'Sem categoria').toString();
      final val = (d['valorLiquido'] as num?)?.toDouble() ?? 0.0;
      m[tipo] = (m[tipo] ?? 0.0) + val;
    }
    return m;
  }

  List<MapEntry<String, double>> _topFornecedores(
      {int top = 10, List<Map<String, dynamic>>? subset}) {
    final m = <String, double>{};
    final fonte = subset ?? _despesas;
    for (final d in fonte) {
      final forn =
      (d['nomeFornecedor'] ?? 'Fornecedor não informado').toString();
      final val = (d['valorLiquido'] as num?)?.toDouble() ?? 0.0;
      m[forn] = (m[forn] ?? 0.0) + val;
    }
    final list = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(top).toList();
  }

  Future<void> _exportDespesasCsv() async {
    final sb = StringBuffer();
    sb.writeln(
        'dataDocumento;tipoDespesa;cnpjCpfFornecedor;nomeFornecedor;valorDocumento;valorLiquido;numeroDocumento;urlDocumento');
    for (final d in _despesas) {
      String q(Object? v) {
        final s = (v ?? '').toString().replaceAll('"', '""');
        return '"$s"';
      }

      sb.writeln([
        q(d['dataDocumento']),
        q(d['tipoDespesa']),
        q(d['cnpjCpfFornecedor']),
        q(d['nomeFornecedor']),
        q(d['valorDocumento']),
        q(d['valorLiquido']),
        q(d['numeroDocumento']),
        q(d['urlDocumento']),
      ].join(';'));
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/despesas_${widget.id}_$anoDespesas.csv';
    final f = File(path);
    await f.writeAsString(sb.toString(), flush: true);
    await Share.shareXFiles([XFile(path)],
        text: 'Despesas $anoDespesas - ${_titulo()}');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('CSV gerado em: $path')));
  }

  Future<void> _openMonthDetails(int month) async {
    final items = _despesas.where((d) {
      final dt = DateTime.tryParse((d['dataDocumento'] ?? '').toString());
      return dt != null && dt.year == anoDespesas && dt.month == month;
    }).toList()
      ..sort((a, b) {
        final ad = DateTime.tryParse((a['dataDocumento'] ?? '').toString()) ??
            DateTime(1970);
        final bd = DateTime.tryParse((b['dataDocumento'] ?? '').toString()) ??
            DateTime(1970);
        return bd.compareTo(ad);
      });

    final allCats = _totaisPorCategoria(subset: items);
    final allSups = _topFornecedores(subset: items, top: 999);
    final total = items.fold<double>(
        0.0, (s, e) => s + ((e['valorLiquido'] as num?)?.toDouble() ?? 0.0));
    const meses = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            String? catSel;
            String? supSel;

            List<Map<String, dynamic>> filtered() {
              return items.where((d) {
                final c = (d['tipoDespesa'] ?? '').toString();
                final s = (d['nomeFornecedor'] ?? '').toString();
                final okCat = catSel == null || catSel!.isEmpty || c == catSel;
                final okSup = supSel == null || supSel!.isEmpty || s == supSel;
                return okCat && okSup;
              }).toList();
            }

            final filteredItems = filtered();
            final filteredTotal = filteredItems.fold<double>(0.0,
                    (s, e) => s + ((e['valorLiquido'] as num?)?.toDouble() ?? 0.0));

            return SafeArea(
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.9,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (_, controller) {
                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Text('${meses[month - 1]} / $anoDespesas',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                          'Total: ${dm.format(total)} • Filtrado: ${dm.format(filteredTotal)}'),
                      const SizedBox(height: 12),
                      const Text('Filtrar por categoria',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Todas'),
                            selected: catSel == null || catSel!.isEmpty,
                            onSelected: (_) => setSt(() => catSel = null),
                          ),
                          ...allCats.keys.map(
                                (c) => FilterChip(
                              label: Text(c, overflow: TextOverflow.ellipsis),
                              selected: catSel == c,
                              onSelected: (_) => setSt(() => catSel = c),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Filtrar por fornecedor',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Todos'),
                            selected: supSel == null || supSel!.isNotEmpty == false,
                            onSelected: (_) => setSt(() => supSel = null),
                          ),
                          ...allSups.map(
                                (e) => FilterChip(
                              label:
                              Text(e.key, overflow: TextOverflow.ellipsis),
                              selected: supSel == e.key,
                              onSelected: (_) => setSt(() => supSel = e.key),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setSt(() {
                            catSel = null;
                            supSel = null;
                          }),
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpar filtros'),
                        ),
                      ),
                      const Divider(height: 24),
                      const Text('Lançamentos',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      ...filteredItems.map((d) {
                        final dt = DateTime.tryParse(
                            (d['dataDocumento'] ?? '').toString());
                        final valor =
                            (d['valorLiquido'] as num?)?.toDouble() ?? 0.0;
                        final tipo = (d['tipoDespesa'] ?? '').toString();
                        final forn = (d['nomeFornecedor'] ?? '').toString();
                        final urlDoc = (d['urlDocumento'] ?? '').toString();
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(tipo),
                          subtitle: Text([
                            if (dt != null) dfd.format(dt),
                            forn
                          ].where((s) => s.isNotEmpty).join(' • ')),
                          trailing: Text(dm.format(valor)),
                          onTap: urlDoc.isNotEmpty ? () => _open(urlDoc) : null,
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo()),
        actions: [
          IconButton(
            icon: Icon(_isFavorito ? Icons.star : Icons.star_border),
            tooltip: 'Seguir/Desseguir',
            onPressed: _toggleFavorito,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartilhar (WhatsApp)',
            onPressed: _shareDeputadoWhats,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openVotacoesSettings,
          ),
          IconButton(
            tooltip: 'Atualizar agora (ignorar cache)',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshAll(noCache: true),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Perfil'),
            Tab(text: 'Proposições'),
            Tab(text: 'Votações'),
            Tab(text: 'Despesas'),
            Tab(text: 'Discursos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildPerfil(),
          _buildProposicoes(),
          _buildVotacoes(),
          _buildDespesas(),
          _buildDiscursos(),
        ],
      ),
    );
  }

  Widget _buildPerfil() {
    if (_loadingPerfil) {
      return const Center(child: CircularProgressIndicator());
    }
    final u = _perfil ?? const {};
    final st = (u['ultimoStatus'] as Map?)?.cast<String, dynamic>() ?? const {};
    final urlFoto = (st['urlFoto'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundImage:
              urlFoto.isNotEmpty ? NetworkImage(urlFoto) : null,
              child: urlFoto.isEmpty ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_titulo(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                  Text(
                      '${(st['siglaPartido'] ?? '').toString()} • ${(st['siglaUf'] ?? '').toString()}'),
                  if ((u['email'] ?? '').toString().isNotEmpty)
                    Text((u['email']).toString()),
                  const SizedBox(height: 8),
                  // Detalhes civis enriquecidos
                  if ((u['nomeCivil'] ?? '').toString().isNotEmpty)
                    Text('Nome civil: ${(u['nomeCivil']).toString()}'),
                  Builder(builder: (_) {
                    final dn = DateTime.tryParse(
                        (u['dataNascimento'] ?? '').toString());
                    final natural = [
                      (u['municipioNascimento'] ?? '').toString(),
                      (u['ufNascimento'] ?? '').toString()
                    ].where((s) => s.isNotEmpty).join('/');
                    if (dn == null && natural.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final dfd2 = DateFormat('dd/MM/yyyy');
                    final partes = <String>[];
                    if (dn != null) partes.add('Nascimento: ${dfd2.format(dn)}');
                    if (natural.isNotEmpty) partes.add(natural);
                    return Text(partes.join(' • '));
                  }),
                  if ((u['escolaridade'] ?? '').toString().isNotEmpty)
                    Text('Escolaridade: ${(u['escolaridade']).toString()}'),
                  // Gabinete detalhado (ultimoStatus.gabinete)
                  Builder(builder: (_) {
                    final st2 = (u['ultimoStatus'] as Map?)
                        ?.cast<String, dynamic>() ??
                        const {};
                    final gab = (st2['gabinete'] as Map?)
                        ?.cast<String, dynamic>() ??
                        const {};
                    if (gab.isEmpty) return const SizedBox.shrink();
                    final sala = (gab['sala'] ?? '').toString();
                    final anexo = (gab['anexo'] ?? '').toString();
                    final fone = (gab['telefone'] ?? '').toString();
                    final partes = <String>[];
                    if (sala.isNotEmpty) partes.add('Sala $sala');
                    if (anexo.isNotEmpty) partes.add('Anexo $anexo');
                    if (fone.isNotEmpty) partes.add('Fone $fone');
                    if (partes.isEmpty) return const SizedBox.shrink();
                    return Text('Gabinete: ${partes.join(', ')}');
                  }),
                  // Redes sociais
                  Builder(builder: (_) {
                    final redes =
                    (u['redeSocial'] as List? ?? const []).cast<String>();
                    if (redes.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 8,
                        children: redes
                            .map((r) => InkWell(
                          onTap: () => launchUrl(Uri.parse(r),
                              mode: LaunchMode.externalApplication),
                          child: Chip(label: Text(r)),
                        ))
                            .toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Ocupações',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ..._ocupacoes.map(
              (o) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text((o['titulo'] ?? o['cargo'] ?? '').toString()),
            subtitle: Text(((o['entidade'] ?? o['orgao'] ?? '').toString())),
          ),
        ),
      ],
    );
  }

  Widget _buildProposicoes() {
    if (_loadingProposicoes) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Ano'),
                  controller:
                  TextEditingController(text: anoProjetos.toString()),
                  onSubmitted: (v) {
                    setState(() =>
                    anoProjetos = int.tryParse(v) ?? anoProjetos);
                    _loadProposicoes(noCache: false);
                  },
                ),
              ),
              Tooltip(
                message: 'Atualizar agora',
                child: IconButton(
                  onPressed: () => _loadProposicoes(noCache: true),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: _proposicoes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = _proposicoes[i];
              final siglaTipo = (p['siglaTipo'] ?? '').toString();
              final numero = (p['numero'] ?? '').toString();
              final ano = (p['ano'] ?? '').toString();
              final ementa = (p['ementa'] ?? '').toString();
              final uri = (p['uri'] ?? '').toString();
              return ListTile(
                title: Text('$siglaTipo $numero/$ano'),
                subtitle: Text(ementa,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () => _open(uri)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVotacoes() {
    if (_loadingVotacoes) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Ano'),
                  controller:
                  TextEditingController(text: anoVotacoes.toString()),
                  onSubmitted: (v) {
                    setState(() =>
                    anoVotacoes = int.tryParse(v) ?? anoVotacoes);
                    _loadVotacoes(noCache: false);
                  },
                ),
              ),
              Tooltip(
                message: 'Atualizar agora',
                child: IconButton(
                  onPressed: () => _loadVotacoes(noCache: true),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: _participacoes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final v = _participacoes[i];
              final data =
              v.data != null ? df.format(v.data!) : '--/--/---- --:--';
              return ListTile(
                title:
                Text(v.descricao.isNotEmpty ? v.descricao : 'Votação ${v.id}'),
                subtitle: Text(
                  [data, v.resultado, 'Voto: ${v.meuVoto}']
                      .where((s) => s.isNotEmpty)
                      .join(' • '),
                ),
                trailing: Wrap(spacing: 8, children: [
                  if (v.uriEvento.isNotEmpty)
                    IconButton(
                        icon: const Icon(Icons.event),
                        onPressed: () => _open(v.uriEvento)),
                  if (v.uri.isNotEmpty)
                    IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => _open(v.uri)),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Helpers visuais (sem fl_chart) ---
  Widget _monthBars() {
    final monthly = _monthlyTotals();
    final maxV = monthly.fold<double>(0.0, (a, b) => a > b ? a : b);
    const meses = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];

    return Column(
      children: List.generate(12, (i) {
        final v = monthly[i];
        final frac = maxV > 0 ? (v / maxV).clamp(0.0, 1.0) : 0.0;
        return InkWell(
          onTap: () => _openMonthDetails(i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                    width: 30,
                    child: Text(meses[i], style: const TextStyle(fontSize: 12))),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: frac,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
								.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints:
                  const BoxConstraints(minWidth: 80, maxWidth: 120),
                  child: Text(
                    dm.format(v),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _categoriaList() {
    final m = _totaisPorCategoria();
    final total = m.values.fold<double>(0.0, (a, b) => a + b);
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final outros = entries.skip(6);
    final outrosTotal =
    outros.fold<double>(0.0, (a, e) => a + e.value);

    List<MapEntry<String, double>> finalList = [...top];
    if (outrosTotal > 0) finalList.add(MapEntry('Outros', outrosTotal));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Categorias (top)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...finalList.map((e) {
          final pct = total > 0 ? (e.value / total) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                    child: Text(e.key,
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints:
                  const BoxConstraints(minWidth: 80, maxWidth: 120),
                  child: Text(dm.format(e.value),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.fade,
                      softWrap: false),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // --- DESPESAS: 100% scrollável (sem overflow) ---
  Widget _buildDespesas() {
    if (_loadingDespesas) {
      return const Center(child: CircularProgressIndicator());
    }
    final monthly = _monthlyTotals();
    final totalAno = monthly.fold<double>(0.0, (a, b) => a + b);
    final top = _topFornecedores();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Ano'),
                    controller:
                    TextEditingController(text: anoDespesas.toString()),
                    onSubmitted: (v) {
                      setState(() =>
                      anoDespesas = int.tryParse(v) ?? anoDespesas);
                      _loadDespesas(noCache: false);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: mesDespesas,
                  hint: const Text('Mês'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Todos')),
                    DropdownMenuItem(value: 1, child: Text('Jan')),
                    DropdownMenuItem(value: 2, child: Text('Fev')),
                    DropdownMenuItem(value: 3, child: Text('Mar')),
                    DropdownMenuItem(value: 4, child: Text('Abr')),
                    DropdownMenuItem(value: 5, child: Text('Mai')),
                    DropdownMenuItem(value: 6, child: Text('Jun')),
                    DropdownMenuItem(value: 7, child: Text('Jul')),
                    DropdownMenuItem(value: 8, child: Text('Ago')),
                    DropdownMenuItem(value: 9, child: Text('Set')),
                    DropdownMenuItem(value: 10, child: Text('Out')),
                    DropdownMenuItem(value: 11, child: Text('Nov')),
                    DropdownMenuItem(value: 12, child: Text('Dez')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => mesDespesas = v);
                    _loadDespesas(noCache: false);
                  },
                ),
                Text('Total no ano: ${dm.format(totalAno)}'),
                Tooltip(
                  message: 'Exportar CSV',
                  child: IconButton(
                    onPressed: _exportDespesasCsv,
                    icon: const Icon(Icons.download_outlined),
                  ),
                ),
                Tooltip(
                  message: 'Atualizar agora',
                  child: IconButton(
                    onPressed: () => _loadDespesas(noCache: true),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _monthBars(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _categoriaList(),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        const SliverToBoxAdapter(
            child: ListTile(title: Text('Top fornecedores (ano)'))),
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, i) {
              final e = top[i];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.trending_up),
                title:
                Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(dm.format(e.value)),
              );
            },
            childCount: top.length,
          ),
        ),
        const SliverToBoxAdapter(
            child: ListTile(title: Text('Despesas detalhadas'))),
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, i) {
              final d = _despesas[i];
              final tipo = (d['tipoDespesa'] ?? '').toString();
              final fornecedor = (d['nomeFornecedor'] ?? '').toString();
              final dt =
              DateTime.tryParse((d['dataDocumento'] ?? '').toString());
              final valor =
                  (d['valorLiquido'] as num?)?.toDouble() ?? 0.0;
              final urlDoc = (d['urlDocumento'] ?? '').toString();
              return ListTile(
                title: Text(tipo),
                subtitle: Text([
                  fornecedor,
                  if (dt != null) dfd.format(dt)
                ].where((s) => s.isNotEmpty).join(' • ')),
                trailing: Text(dm.format(valor)),
                onTap: urlDoc.isNotEmpty ? () => _open(urlDoc) : null,
              );
            },
            childCount: _despesas.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildDiscursos() {
    if (_loadingDiscursos) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _discursos.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, i) {
        final d = _discursos[i];
        final inicio =
        DateTime.tryParse((d['dataHoraInicio'] ?? '').toString());
        return ListTile(
          title: Text((d['tipoDiscurso'] ?? '').toString()),
          subtitle: Text([
            (d['faseEvento'] ?? '').toString(),
            if (inicio != null) df.format(inicio)
          ].where((s) => s.isNotEmpty).join(' • ')),
          trailing: Wrap(spacing: 8, children: [
            if ((d['urlAudio'] ?? '').toString().isNotEmpty)
              IconButton(
                  icon: const Icon(Icons.audiotrack),
                  onPressed: () => _open((d['urlAudio']).toString())),
            if ((d['urlVideo'] ?? '').toString().isNotEmpty)
              IconButton(
                  icon: const Icon(Icons.ondemand_video),
                  onPressed: () => _open((d['urlVideo']).toString())),
            if ((d['urlTexto'] ?? '').toString().isNotEmpty)
              IconButton(
                  icon: const Icon(Icons.description),
                  onPressed: () => _open((d['urlTexto']).toString())),
          ]),
        );
      },
    );
  }

  void _openVotacoesSettings() async {
    final limiteVals = [80, 120, 160, 200, 240];
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        int tempLimite = _maxVotacoesPorAno;
        bool tempMes = _votacoesPorMes;
        int tempConc = _concorrenciaVotos;
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Configurações de Votações',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Buscar por mês'),
                  subtitle: const Text('Reduz payload e traz resultados mais cedo'),
                  value: tempMes,
                  onChanged: (v) => setModal(() => tempMes = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Limite/ano:'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: limiteVals.contains(tempLimite)
                          ? tempLimite
                          : limiteVals[2],
                      items: limiteVals
                          .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e.toString())))
                          .toList(),
                      onChanged: (v) =>
                          setModal(() => tempLimite = v ?? tempLimite),
                    ),
                    const SizedBox(width: 16),
                    const Text('Concorrência:'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: tempConc.clamp(2, 12),
                      items: [4, 6, 8, 10, 12]
                          .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e.toString())))
                          .toList(),
                      onChanged: (v) =>
                          setModal(() => tempConc = (v ?? tempConc)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _votacoesPorMes = tempMes;
                      _maxVotacoesPorAno = tempLimite;
                      _concorrenciaVotos = tempConc;
                    });
                    _savePrefs();
                    Navigator.of(ctx).pop();
                    _loadVotacoes(noCache: true);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Aplicar'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ====== COMPARTILHAMENTO ======

  // Soma robusta de valores em uma lista de despesas
  double _sumValorDespesas(List<Map<String, dynamic>> lista) {
    double total = 0.0;
    for (final d in lista) {
      final vals = [
        d['valorLiquido'],
        d['valorDocumento'],
        d['valor'],
        d['vlrLiquido'],
      ];
      for (final v in vals) {
        if (v == null) continue;
        final n =
        (v is num) ? v.toDouble() : double.tryParse(v.toString().replaceAll(',', '.'));
        if (n != null) {
          total += n;
          break;
        }
      }
    }
    return total;
  }

  // Busca o total do ANO inteiro (mes: null) para garantir o valor correto mesmo se a tela estiver filtrada por mês.
  Future<double> _fetchTotalDespesasAno(int ano) async {
    try {
      final lista = await api.despesasDeputado(
        widget.id,
        ano: ano,
        mes: null,
        itens: 100,
        maxPaginas: 12,
        noCache: false,
      );
      return _sumValorDespesas(lista);
    } catch (_) {
      // fallback: soma do que estiver carregado na UI
      return _monthlyTotals().fold<double>(0.0, (s, v) => s + v);
    }
  }

  String _buildDeputadoShareText({double? totalAnoOverride}) {
    final u = _perfil ?? const {};
    final st = (u['ultimoStatus'] as Map?)?.cast<String, dynamic>() ?? const {};
    final nome = (st['nome'] ?? u['nomeCivil'] ?? '').toString();
    final partido = (st['siglaPartido'] ?? '').toString();
    final uf = (st['siglaUf'] ?? '').toString();
    final email = (u['email'] ?? '').toString();
    final escolaridade = (u['escolaridade'] ?? '').toString();
    final gab = (st['gabinete'] as Map?)?.cast<String, dynamic>() ?? const {};
    final gabStr = [
      if ((gab['sala'] ?? '').toString().isNotEmpty)
        'Sala ${(gab['sala'] ?? '').toString()}',
      if ((gab['anexo'] ?? '').toString().isNotEmpty)
        'Anexo ${(gab['anexo'] ?? '').toString()}',
      if ((gab['telefone'] ?? '').toString().isNotEmpty)
        'Fone ${(gab['telefone'] ?? '').toString()}',
    ].join(', ');

    final dfd2 = DateFormat('dd/MM/yyyy');
    final cbrl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    String resumoProps() {
      if (_proposicoes.isEmpty) return '—';
      return _proposicoes.take(5).map((p) {
        final sigla = (p['siglaTipo'] ?? '').toString();
        final numero = (p['numero'] ?? '').toString();
        final ano = (p['ano'] ?? '').toString();
        final ementa = (p['ementa'] ?? '').toString();
        return '$sigla $numero/$ano — $ementa';
      }).join('\n');
    }

    String resumoVotos() {
      if (_participacoes.isEmpty) return '—';
      return _participacoes.take(5).map((v) {
        final data = v.data != null ? dfd2.format(v.data!) : '';
        final voto = v.meuVoto.toString();
        final desc = v.descricao.toString();
        return '$data — Voto: $voto — $desc';
      }).join('\n');
    }

    // Agora SOMENTE "Ano XXXX — Total de gastos: R$ ..."
    String resumoDespesas() {
      final totalAno = totalAnoOverride ?? _monthlyTotals().fold<double>(0.0, (s, v) => s + v);
      return 'Ano $anoDespesas — Total de gastos: ${cbrl.format(totalAno)}';
    }

    final linhas = <String>[
      'Deputado(a): $nome${(partido.isNotEmpty || uf.isNotEmpty) ? ' (${[partido, uf].where((s) => s.isNotEmpty).join('-')})' : ''}',
      if (email.isNotEmpty) 'E-mail: $email',
      if (escolaridade.isNotEmpty) 'Escolaridade: $escolaridade',
      if (gabStr.isNotEmpty) 'Gabinete: $gabStr',
      '',
      'Principais proposições:',
      resumoProps(),
      '',
      'Votações recentes:',
      resumoVotos(),
      '',
      'Despesas:',
      resumoDespesas(),
      '',
      'Enviado via App Contabil',
    ];
    return linhas.where((l) => l.isNotEmpty).join('\n');
  }

  Future<void> _shareDeputadoWhats() async {
    // Garante o TOTAL DO ANO todo (independente do filtro mensal atual)
    final totalAno = await _fetchTotalDespesasAno(anoDespesas);
    final text = _buildDeputadoShareText(totalAnoOverride: totalAno);
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        // fallback: tentar abrir como link normal
        await launchUrl(uri);
      }
    } catch (_) {}
  }
}
