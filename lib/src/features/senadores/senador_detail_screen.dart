import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/open_link.dart';
import '../../shared/whatsapp_share.dart';
import '../../shared/senado/adm_senado_api_client.dart';
import '../../shared/senado/cached_senado_api.dart';
import '../../shared/senado/senado_models.dart';

class SenadorDetailScreen extends StatefulWidget {
  final String codigo;
  final String? nome;

  const SenadorDetailScreen({
    super.key,
    required this.codigo,
    this.nome,
  });

  @override
  State<SenadorDetailScreen> createState() => _SenadorDetailScreenState();
}

class _SenadorDetailScreenState extends State<SenadorDetailScreen>
    with SingleTickerProviderStateMixin {
  final _api = CachedSenadoApi();
  final _adm = AdmSenadoApiClient();

  late final TabController _tabs;

  static const List<String> _tabTitles = <String>[
    'Resumo',
    'Detalhes',
    'Mandatos',
    'CEAPS',
    'Links',
  ];

  int _currentTab = 0;

  late Future<SenadorResumo> _futureResumo;
  late Future<Map<String, dynamic>> _futureDetalhe;
  late Future<Map<String, dynamic>> _futureMandatos;

  int _anoCeaps = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);

    _currentTab = _tabs.index;
    _tabs.addListener(() {
      // Rebuild apenas quando o índice mudar de fato (evita rebuild contínuo durante swipe).
      if (!mounted) return;
      final idx = _tabs.index;
      if (idx != _currentTab && !_tabs.indexIsChanging) {
        setState(() => _currentTab = idx);
      }
    });

    _futureResumo = _carregarResumo();
    _futureDetalhe = _api.obterDetalheSenadorRaw(widget.codigo);
    _futureMandatos = _api.obterMandatosSenadorRaw(widget.codigo);

    // Evita ano futuro “vazio” quando o device estiver adiantado.
    final now = DateTime.now();
    _anoCeaps = now.year;
  }

  Future<SenadorResumo> _carregarResumo() async {
    final list = await _api.listarSenadoresEmExercicio();
    return list.firstWhere(
      (s) => s.codigo == widget.codigo,
      orElse: () => SenadorResumo(
        codigo: widget.codigo,
        nome: widget.nome ?? widget.codigo,
        nomeCompleto: null,
        uf: null,
        partido: null,
        fotoUrl: null,
        paginaUrl: null,
        email: null,
        telefone: null,
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _adm.close();
    super.dispose();
  }

  String _tabName(int index) {
    if (index < 0 || index >= _tabTitles.length) return 'Aba';
    return _tabTitles[index];
  }

  Future<void> _shareActiveTab(BuildContext context, SenadorResumo s) async {
    final idx = _tabs.index;
    try {
      final msg = await _buildShareMessageForTab(idx, s);
      if (!context.mounted) return;
      await shareToWhatsApp(context, msg);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível preparar o compartilhamento.\n$e')),
      );
    }
  }

  Future<String> _buildShareMessageForTab(int tabIndex, SenadorResumo s) async {
    switch (tabIndex) {
      case 0:
        return _shareResumoText(s);
      case 1:
        return _shareDetalhesText(s);
      case 2:
        return _shareMandatosText(s);
      case 3:
        return _shareCeapsText(s);
      case 4:
        return _shareLinksText(s);
      default:
        return _shareResumoText(s);
    }
  }

  String _shareHeader(SenadorResumo s, {String? tabName}) {
    final partido = (s.partido ?? '').trim();
    final uf = (s.uf ?? '').trim();
    final suf = [partido, uf].where((e) => e.isNotEmpty).join('-');
    final base = 'Senador(a): ${s.nome}${suf.isEmpty ? '' : ' ($suf)'}';
    return tabName == null ? base : '$base\nAba: $tabName';
  }

  String _shareResumoText(SenadorResumo s) {
    final perfil = (s.paginaUrl != null && s.paginaUrl!.trim().isNotEmpty)
        ? s.paginaUrl!.trim()
        : 'https://www25.senado.leg.br/web/senadores/senador/-/perfil/${s.codigo}';

    final msg = [
      _shareHeader(s, tabName: _tabName(0)),
      if ((s.nomeCompleto ?? '').trim().isNotEmpty && (s.nomeCompleto ?? '').trim() != s.nome)
        'Nome completo: ${s.nomeCompleto}',
      if ((s.email ?? '').trim().isNotEmpty) 'E-mail: ${s.email}',
      if ((s.telefone ?? '').trim().isNotEmpty) 'Telefone: ${s.telefone}',
      'Perfil: $perfil',
      '',
      'Fonte: Senado Federal',
    ].where((e) => e.trim().isNotEmpty).join('\n');

    return msg;
  }

  Future<String> _shareDetalhesText(SenadorResumo s) async {
    final data = await _futureDetalhe;
    final ident = _mapAt(data, ['DetalheParlamentar', 'Parlamentar', 'IdentificacaoParlamentar']) ??
        const <String, dynamic>{};
    final basicos = _mapAt(data, ['DetalheParlamentar', 'Parlamentar', 'DadosBasicosParlamentar']) ??
        const <String, dynamic>{};

    final nome = _pick([ident['NomeParlamentar'], s.nome, widget.nome, widget.codigo]);
    final nomeCompleto = _s(ident['NomeCompletoParlamentar']);
    final partido = _s(ident['SiglaPartidoParlamentar']);
    final uf = _s(ident['UfParlamentar']);
    final email = _s(ident['EmailParlamentar']);
    final pagina = _s(ident['UrlPaginaParlamentar']);
    final nascimento = _formatDate(_s(basicos['DataNascimento']));
    final naturalidade = _s(basicos['Naturalidade']);
    final sexo = _s(basicos['SexoParlamentar']);

    final perfil = pagina.isNotEmpty
        ? pagina
        : 'https://www25.senado.leg.br/web/senadores/senador/-/perfil/${s.codigo}';

    final suf = [partido, uf].where((e) => e.isNotEmpty).join('-');

    return [
      'Senador(a): $nome${suf.isEmpty ? '' : ' ($suf)'}',
      'Aba: ${_tabName(1)}',
      if (nomeCompleto.isNotEmpty && nomeCompleto != nome) 'Nome completo: $nomeCompleto',
      if (sexo.isNotEmpty) 'Sexo: $sexo',
      if (nascimento.isNotEmpty) 'Nascimento: $nascimento',
      if (naturalidade.isNotEmpty) 'Naturalidade: $naturalidade',
      if (email.isNotEmpty) 'E-mail: $email',
      'Perfil: $perfil',
      '',
      'Fonte: Senado Federal',
    ].where((e) => e.trim().isNotEmpty).join('\n');
  }

  Future<String> _shareMandatosText(SenadorResumo s) async {
    final data = await _futureMandatos;
    final mandatos = _listAt(data, ['MandatoParlamentar', 'Parlamentar', 'Mandatos'], 'Mandato');

    final lines = <String>[
      _shareHeader(s, tabName: _tabName(2)),
      '',
      if (mandatos.isEmpty) 'Nenhum mandato encontrado.' else 'Mandatos:',
    ];

    for (final raw in mandatos.take(12)) {
      final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final inicio = _formatDate(_s(m['DataInicio']));
      final fim = _formatDate(_s(m['DataFim']));
      final uf = _s(m['UfParlamentar']);
      final participacao = _s(m['DescricaoParticipacao'] ?? m['TipoMandato']);
      final legislatura = _s(
        (m['PrimeiraLegislaturaDoMandato'] is Map)
            ? (m['PrimeiraLegislaturaDoMandato'] as Map)['NumeroLegislatura']
            : (m['NumeroLegislatura'] ?? ''),
      );
      final periodo = [inicio, fim].where((e) => e.isNotEmpty).join(' → ');

      final head = [
        if (participacao.isNotEmpty) participacao,
        [uf, legislatura].where((e) => e.isNotEmpty).join(' • '),
      ].where((e) => e.isNotEmpty).join(' — ');

      lines.add('• ${head.isEmpty ? 'Mandato' : head}${periodo.isEmpty ? '' : '\n  Período: $periodo'}');
    }

    if (mandatos.length > 12) {
      lines.add('• … e mais ${mandatos.length - 12}');
    }

    lines.addAll(['', 'Fonte: Senado Federal']);
    return lines.where((e) => e.trim().isNotEmpty).join('\n');
  }

  Future<String> _shareCeapsText(SenadorResumo s) async {
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

    // Usa o mesmo critério da aba (nome normalizado vindo do detalhe) para filtrar com robustez.
    final detalhe = await _futureDetalhe;
    final ident = _mapAt(detalhe, ['DetalheParlamentar', 'Parlamentar', 'IdentificacaoParlamentar']) ??
        const <String, dynamic>{};
    final nomeSenador = _pick([ident['NomeParlamentar'], s.nome, widget.nome, widget.codigo]).toLowerCase().trim();

    final r = await _adm.queryCeaps(senadorCodigo: widget.codigo, ano: _anoCeaps);
    if (r.data == null || !r.ok) {
      return [
        _shareHeader(s, tabName: _tabName(3)),
        'Ano: $_anoCeaps',
        '',
        'Não foi possível obter dados de CEAPS.',
        if ((r.error ?? '').trim().isNotEmpty) 'Erro: ${r.error}',
        if (r.usedUrl != null) 'Consulta: ${r.usedUrl}',
        '',
        'Fonte: Senado Federal (Dados Abertos Administrativo)',
      ].where((e) => e.trim().isNotEmpty).join('\n');
    }

    final raw = r.data;
    final list = (raw is List)
        ? raw
        : (raw is Map && raw['data'] is List)
            ? raw['data'] as List
            : <dynamic>[];

    final items = list.where((e) {
      if (e is! Map) return false;
      final m = Map<String, dynamic>.from(e);
      final n = _s(m['nomeSenador']).toLowerCase().trim();
      return n == nomeSenador;
    }).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    double total = 0;
    final byTipo = <String, double>{};
    for (final it in items) {
      final tipo = _s(it['tipoDespesa']).isNotEmpty ? _s(it['tipoDespesa']) : 'Outros';
      final v = it['valorReembolsado'];
      double? valor;
      if (v is num) valor = v.toDouble();
      if (v is String) valor = double.tryParse(v.replaceAll('.', '').replaceAll(',', '.'));
      if (valor == null) continue;
      total += valor;
      byTipo[tipo] = (byTipo[tipo] ?? 0) + valor;
    }

    final tiposTop = byTipo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final lines = <String>[
      _shareHeader(s, tabName: _tabName(3)),
      'Ano: $_anoCeaps',
      'Itens: ${items.length}',
      'Total reembolsado: ${money.format(total)}',
      '',
      if (tiposTop.isNotEmpty) 'Top categorias:' else 'Sem detalhamento por categoria.',
      ...tiposTop.take(5).map((e) => '• ${e.key}: ${money.format(e.value)}'),
      if (tiposTop.length > 5) '• … e mais ${tiposTop.length - 5} categorias',
      if (r.usedUrl != null) 'Consulta: ${r.usedUrl}',
      '',
      'Fonte: Senado Federal (Dados Abertos Administrativo)',
    ];

    return lines.where((e) => e.trim().isNotEmpty).join('\n');
  }

  Future<String> _shareLinksText(SenadorResumo s) async {
    final data = await _futureDetalhe;
    final ident = _mapAt(data, ['DetalheParlamentar', 'Parlamentar', 'IdentificacaoParlamentar']) ??
        const <String, dynamic>{};

    final links = <String, String>{};

    void add(String label, dynamic url) {
      final s = _s(url);
      if (s.isEmpty) return;
      if (!s.startsWith('http')) return;
      if (s.contains('noNamespaceSchemaLocation')) return;
      if (s.endsWith('.xsd')) return;
      links[label] = s;
    }

    add('Página oficial', ident['UrlPaginaParlamentar']);
    add('Foto', ident['UrlFotoParlamentar']);
    add('Perfil', 'https://www25.senado.leg.br/web/senadores/senador/-/perfil/${s.codigo}');

    // Extras (com labels numeradas)
    var extraIndex = 1;
    for (final u in _extractLinks(data)) {
      final v = u.toString();
      if (v.contains('noNamespaceSchemaLocation')) continue;
      if (v.endsWith('.xsd')) continue;
      if (!v.startsWith('http')) continue;
      if (links.values.contains(v)) continue;
      links['Link $extraIndex'] = v;
      extraIndex++;
      if (extraIndex > 8) break; // evita mensagens enormes
    }

    final entries = links.entries.toList();
    if (entries.isEmpty) {
      return [
        _shareHeader(s, tabName: _tabName(4)),
        '',
        'Nenhum link útil encontrado.',
        '',
        'Fonte: Senado Federal',
      ].where((e) => e.trim().isNotEmpty).join('\n');
    }

    return [
      _shareHeader(s, tabName: _tabName(4)),
      '',
      ...entries.take(12).map((e) => '${e.key}: ${e.value}'),
      if (entries.length > 12) '… e mais ${entries.length - 12} links',
      '',
      'Fonte: Senado Federal',
    ].where((e) => e.trim().isNotEmpty).join('\n');
  }

  Future<void> openLink(BuildContext context, String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link inválido.')),
        );
        return;
      }
      await openExternal(uri);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o link.\n$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SenadorResumo>(
      future: _futureResumo,
      builder: (context, snap) {
        final title = snap.data?.nome ?? widget.nome ?? 'Senador';
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                tooltip: 'Compartilhar no WhatsApp (${_tabName(_currentTab)})',
                icon: const Icon(Icons.share_outlined),
                onPressed: (snap.data == null)
                    ? null
                    : () async => _shareActiveTab(context, snap.data!),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Resumo'),
                Tab(text: 'Detalhes'),
                Tab(text: 'Mandatos'),
                Tab(text: 'CEAPS'),
                Tab(text: 'Links'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _tabResumo(snap),
              _tabDetalhes(),
              _tabMandatos(),
              _tabCeaps(),
              _tabLinks(),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------
  // ABA: RESUMO
  // ---------------------------

  Widget _tabResumo(AsyncSnapshot<SenadorResumo> snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snap.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Falha ao carregar resumo.\n\n${snap.error}', textAlign: TextAlign.center),
        ),
      );
    }

    final s = snap.data!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (s.fotoUrl != null && s.fotoUrl!.isNotEmpty)
          Center(
            child: CircleAvatar(
              radius: 46,
              backgroundImage: NetworkImage(s.fotoUrl!),
            ),
          )
        else
          const Center(child: CircleAvatar(radius: 46, child: Icon(Icons.person, size: 34))),
        const SizedBox(height: 12),
        Center(
          child: Text(
            s.nome,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        if (s.partido != null || s.uf != null)
          Center(
            child: Text(
              [
                if (s.partido != null && s.partido!.isNotEmpty) s.partido!,
                if (s.uf != null && s.uf!.isNotEmpty) s.uf!,
              ].join(' • '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              if (s.email != null && s.email!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('E-mail'),
                  subtitle: Text(s.email!),
                  onTap: () => openExternal(Uri.parse('mailto:${s.email}')),
                ),
              if (s.paginaUrl != null && s.paginaUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Página oficial'),
                  subtitle: Text(s.paginaUrl!),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => openLink(context, s.paginaUrl!),
                ),
              if (s.telefone != null && s.telefone!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.call_outlined),
                  title: const Text('Telefone'),
                  subtitle: Text(s.telefone!),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Use as abas (ou arraste para os lados) para ver detalhes, mandatos, '
              'prestação de contas (CEAPS) e links úteis.',
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------
  // ABA: DETALHES (formatado)
  // ---------------------------

  Widget _tabDetalhes() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _futureDetalhe,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Falha ao carregar detalhes.\n\n${snap.error}', textAlign: TextAlign.center),
            ),
          );
        }

        final data = snap.data!;
        final ident = _mapAt(data, ['DetalheParlamentar', 'Parlamentar', 'IdentificacaoParlamentar']) ?? const <String, dynamic>{};
        final basicos = _mapAt(data, ['DetalheParlamentar', 'Parlamentar', 'DadosBasicosParlamentar']) ?? const <String, dynamic>{};

        final nome = _pick([ident['NomeParlamentar'], widget.nome, widget.codigo]);
        final nomeCompleto = _s(ident['NomeCompletoParlamentar']);
        final partido = _s(ident['SiglaPartidoParlamentar']);
        final uf = _s(ident['UfParlamentar']);
        final email = _s(ident['EmailParlamentar']);
        final foto = _s(ident['UrlFotoParlamentar']);
        final pagina = _s(ident['UrlPaginaParlamentar']);

        final nascimento = _formatDate(_s(basicos['DataNascimento']));
        final naturalidade = _s(basicos['Naturalidade']);
        final sexo = _s(basicos['SexoParlamentar']);

        final cards = <Widget>[
          Text('Perfil', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: (foto.isNotEmpty)
                        ? CircleAvatar(backgroundImage: NetworkImage(foto))
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(nome, style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text([partido, uf].where((e) => e.isNotEmpty).join(' • ')),
                  ),
                  if (nomeCompleto.isNotEmpty) _infoRow('Nome completo', nomeCompleto),
                  if (sexo.isNotEmpty) _infoRow('Sexo', sexo),
                  if (nascimento.isNotEmpty) _infoRow('Nascimento', nascimento),
                  if (naturalidade.isNotEmpty) _infoRow('Naturalidade', naturalidade),
                ],
              ),
            ),
          ),
        ];

        final contatos = <Widget>[];
        if (email.isNotEmpty) {
          contatos.add(
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('E-mail'),
              subtitle: Text(email),
              onTap: () => openExternal(Uri.parse('mailto:$email')),
            ),
          );
        }
        if (pagina.isNotEmpty) {
          contatos.add(
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Página oficial'),
              subtitle: Text(pagina),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openLink(context, pagina),
            ),
          );
        }

        if (contatos.isNotEmpty) {
          cards.add(const SizedBox(height: 12));
          cards.add(Text('Contatos', style: Theme.of(context).textTheme.titleLarge));
          cards.add(const SizedBox(height: 12));
          cards.add(Card(child: Column(children: contatos)));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: cards,
        );
      },
    );
  }

  // ---------------------------
  // ABA: MANDATOS (formatado)
  // ---------------------------

  Widget _tabMandatos() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _futureMandatos,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Falha ao carregar mandatos.\n\n${snap.error}', textAlign: TextAlign.center),
            ),
          );
        }

        final data = snap.data!;
        final mandatos = _listAt(data, ['MandatoParlamentar', 'Parlamentar', 'Mandatos'], 'Mandato');

        if (mandatos.isEmpty) {
          return const Center(child: Text('Nenhum mandato encontrado.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: mandatos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final raw = mandatos[i];
            final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

            final inicio = _formatDate(_s(m['DataInicio']));
            final fim = _formatDate(_s(m['DataFim']));
            final uf = _s(m['UfParlamentar']);
            final participacao = _s(m['DescricaoParticipacao'] ?? m['TipoMandato']);
            final legislatura = _s(
              (m['PrimeiraLegislaturaDoMandato'] is Map)
                  ? (m['PrimeiraLegislaturaDoMandato'] as Map)['NumeroLegislatura']
                  : (m['NumeroLegislatura'] ?? ''),
            );

            final periodo = [inicio, fim].where((e) => e.isNotEmpty).join(' → ');

            return Card(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text([uf, legislatura].where((e) => e.isNotEmpty).join(' • ')),
                subtitle: Text(
                  [
                    if (participacao.isNotEmpty) participacao,
                    if (periodo.isNotEmpty) 'Período: $periodo',
                  ].join('\n'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------
  // ABA: CEAPS (prestação de contas)
  // ---------------------------

  Widget _tabCeaps() {
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

    return FutureBuilder<Map<String, dynamic>>(
      future: _futureDetalhe,
      builder: (context, snapDetalhe) {
        if (snapDetalhe.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapDetalhe.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Falha ao carregar dados do senador.\n\n${snapDetalhe.error}', textAlign: TextAlign.center),
            ),
          );
        }

        final detalhe = snapDetalhe.data!;
        final ident = _mapAt(detalhe, ['DetalheParlamentar', 'Parlamentar', 'IdentificacaoParlamentar']) ?? const <String, dynamic>{};
        final nomeSenador = _pick([ident['NomeParlamentar'], widget.nome, widget.codigo]).toLowerCase().trim();

        return FutureBuilder<AdmQueryResult>(
          future: _adm.queryCeaps(senadorCodigo: widget.codigo, ano: _anoCeaps),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ceapsErro(snap.error.toString());
            }

            final r = snap.data;
            if (r == null || !r.ok || r.data == null) {
              return _ceapsErro(r?.error ?? 'Não foi possível obter dados de CEAPS.');
            }

            // Normaliza payload: pode vir List direto ou Map contendo lista em "data"
            final raw = r.data;
            final list = (raw is List)
                ? raw
                : (raw is Map && raw['data'] is List)
                    ? raw['data'] as List
                    : <dynamic>[];

            // Filtra por nome (robusto quando codigos não batem entre fontes)
            final items = list.where((e) {
              if (e is! Map) return false;
              final m = Map<String, dynamic>.from(e);
              final n = _s(m['nomeSenador']).toLowerCase().trim();
              return n == nomeSenador;
            }).map((e) => Map<String, dynamic>.from(e as Map)).toList();

            double total = 0;
            for (final it in items) {
              final v = it['valorReembolsado'];
              if (v is num) total += v.toDouble();
              if (v is String) {
                final parsed = double.tryParse(v.replaceAll('.', '').replaceAll(',', '.'));
                if (parsed != null) total += parsed;
              }
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Prestação de contas (CEAPS)', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    DropdownButton<int>(
                      value: _anoCeaps,
                      items: List.generate(7, (i) => DateTime.now().year - i)
                          .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _anoCeaps = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _metricRow('Itens', '${items.length}'),
                        const SizedBox(height: 8),
                        _metricRow('Total reembolsado', money.format(total)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nenhum registro encontrado para este senador no ano selecionado.'),
                    ),
                  ),
                ...items.map((it) => _ceapsItemCard(it, money)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _ceapsErro(String error) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Prestação de contas (CEAPS)', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Não foi possível obter dados de CEAPS.\n\n$error'),
          ),
        ),
      ],
    );
  }

  Widget _ceapsItemCard(Map<String, dynamic> it, NumberFormat money) {
    final tipo = _s(it['tipoDespesa']).isNotEmpty ? _s(it['tipoDespesa']) : 'Despesa';
    final data = _formatDate(_s(it['data']));
    final fornecedor = _s(it['fornecedor']);
    final doc = _s(it['documento']);
    final detalhe = _s(it['detalhamento']);

    final v = it['valorReembolsado'];
    double? valor;
    if (v is num) valor = v.toDouble();
    if (v is String) valor = double.tryParse(v.replaceAll('.', '').replaceAll(',', '.'));

    final lines = <String>[
      if (data.isNotEmpty) 'Data: $data',
      if (fornecedor.isNotEmpty) 'Fornecedor: $fornecedor',
      if (doc.isNotEmpty) 'Documento: $doc',
      if (detalhe.isNotEmpty) detalhe,
    ];

    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(tipo),
        subtitle: Text(lines.join('\n')),
        trailing: Text(valor == null ? '-' : money.format(valor), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ---------------------------
  // ABA: LINKS (úteis e limpos)
  // ---------------------------

  Widget _tabLinks() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _futureDetalhe,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Falha ao carregar links.\n\n${snap.error}', textAlign: TextAlign.center),
            ),
          );
        }

        final data = snap.data!;
        final ident = _mapAt(data, ['DetalheParlamentar', 'Parlamentar', 'IdentificacaoParlamentar']) ?? const <String, dynamic>{};

        final links = <String, String>{};

        void add(String label, dynamic url) {
          final s = _s(url);
          if (s.isEmpty) return;
          if (!s.startsWith('http')) return;
          if (s.contains('noNamespaceSchemaLocation')) return;
          if (s.endsWith('.xsd')) return;
          links[label] = s;
        }

        add('Página oficial', ident['UrlPaginaParlamentar']);
        add('Foto', ident['UrlFotoParlamentar']);

        // Coleta links extras do payload, mas filtra bem para não virar “lixo”.
        for (final u in _extractLinks(data)) {
          final s = u.toString();
          if (s.contains('noNamespaceSchemaLocation')) continue;
          if (s.endsWith('.xsd')) continue;
          if (!s.startsWith('http')) continue;
          if (links.values.contains(s)) continue;
          links['Link'] = s; // fallback; não spammar labels
        }

        if (links.isEmpty) {
          return const Center(child: Text('Nenhum link útil encontrado.'));
        }

        final entries = links.entries.toList();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = entries[i];
            return ListTile(
              leading: const Icon(Icons.link),
              title: Text(e.key),
              subtitle: Text(e.value),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openLink(context, e.value),
            );
          },
        );
      },
    );
  }

  // ---------------------------
  // Helpers de parsing
  // ---------------------------

  static String _s(dynamic v) => (v == null) ? '' : v.toString().trim();

  static String _pick(List<dynamic> vals) {
    for (final v in vals) {
      final s = _s(v);
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static Map<String, dynamic>? _mapAt(Map<String, dynamic>? root, List<String> path) {
    dynamic cur = root;
    for (final k in path) {
      if (cur is Map<String, dynamic> && cur[k] is Map) {
        cur = Map<String, dynamic>.from(cur[k] as Map);
      } else {
        return null;
      }
    }
    return cur as Map<String, dynamic>?;
  }

  static List<dynamic> _listAt(Map<String, dynamic>? root, List<String> path, String key) {
    final m = _mapAt(root, path);
    final v = m == null ? null : m[key];
    if (v is List) return v;
    if (v == null) return const [];
    return [v];
  }

  static String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    // Tenta padrões comuns: YYYY-MM-DD e DD/MM/YYYY
    try {
      if (raw.contains('-')) {
        final dt = DateTime.tryParse(raw);
        if (dt != null) return DateFormat('dd/MM/yyyy').format(dt);
      }
      if (raw.contains('/')) {
        final parts = raw.split('/');
        if (parts.length == 3) {
          final d = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final y = int.tryParse(parts[2]);
          if (d != null && m != null && y != null) {
            final dt = DateTime(y, m, d);
            return DateFormat('dd/MM/yyyy').format(dt);
          }
        }
      }
    } catch (_) {}
    return raw;
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value),
      ],
    );
  }

  static List<Uri> _extractLinks(dynamic data) {
    final out = <Uri>[];

    void walk(dynamic v) {
      if (v is Map) {
        for (final entry in v.entries) {
          walk(entry.value);
        }
      } else if (v is List) {
        for (final x in v) walk(x);
      } else if (v is String) {
        final s = v.trim();
        if (s.startsWith('http://') || s.startsWith('https://')) {
          final u = Uri.tryParse(s);
          if (u != null) out.add(u);
        }
      }
    }

    walk(data);
    // Dedup
    final seen = <String>{};
    return out.where((u) => seen.add(u.toString())).toList();
  }
}
