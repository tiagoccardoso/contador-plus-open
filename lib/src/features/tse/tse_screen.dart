import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/open_link.dart';
import '../../shared/whatsapp_share.dart';
import '../../shared/tse/cached_tse_api.dart';

class TseScreen extends StatefulWidget {
  const TseScreen({super.key});

  @override
  State<TseScreen> createState() => _TseScreenState();
}

class _TseScreenState extends State<TseScreen> {
  final _api = CachedTseApi();

  // Protege contra condições de corrida quando o usuário troca filtros rapidamente.
  int _loadToken = 0;

  final _buscaCtrl = TextEditingController();

  // Share: cada aba prepara seu texto e o AppBar compartilha o conteúdo da aba ativa.
  final Map<int, String> _shareTextByTab = <int, String>{};

  void _setShareTextForTab(int tabIndex, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _shareTextByTab[tabIndex] = t;
  }

  bool _loadingBase = true;
  String? _errorBase;

  List<Map<String, dynamic>> _eleicoes = const [];
  List<Map<String, dynamic>> _ufs = const [];
  List<Map<String, dynamic>> _municipios = const [];
  List<Map<String, dynamic>> _cargos = const [];
  List<Map<String, dynamic>> _candidatos = const [];

  Map<String, dynamic>? _eleicao;
  String _escopo = 'UF'; // BR | UF | MUN
  String? _uf;
  Map<String, dynamic>? _municipio;
  Map<String, dynamic>? _cargo;

  Map<String, dynamic>? _candidatoSelecionado; // item da lista
  Future<Map<String, dynamic>>? _candidatoDetalheFuture;

  @override
  void initState() {
    super.initState();
    _init();
    _buscaCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _api.dispose();
    _buscaCtrl.dispose();
    super.dispose();
  }

  int? get _anoEleitoral {
    final v = _eleicao?['ano'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  int? get _idEleicao {
    final v = _eleicao?['id'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }


  bool get _isEleicaoMunicipal {
    final t = _eleicao?['tipoAbrangencia']?.toString().toUpperCase();
    return t == 'M';
  }


  
  String? _extractMunicipioCodigoTse(Map<String, dynamic> m) {
    // O DivulgaCandContas usa o *código TSE do município* (geralmente 4-6 dígitos),
    // e NÃO o código IBGE (7 dígitos). Como o nome do campo pode variar entre endpoints,
    // aplicamos: (1) candidatos por chaves comuns; (2) heurística por valores numéricos.
    final candidates = <Object?>[
      m['codigo'],
      m['codigoMunicipio'],
      m['codigoMunicipioTse'],
      m['codigoMunicipioTSE'],
      m['codigoTse'],
      m['codigoTSE'],
      m['codMunicipio'],
      m['cdMunicipio'],
      m['codMun'],
      m['cdMun'],
      m['idMunicipio'],
      m['id'],
      m['cod'],
      m['cd'],
      m['codigoMunicipioSuperior'],
      m['codigoIBGE'],
      m['codigoIbge'],
      m['ibge'],
    ];

    String? pick(Object? v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty || s.toLowerCase() == 'null') return null;

      // Se for "12345" ou 12345...
      final onlyDigits = RegExp(r'^\d+$');
      if (!onlyDigits.hasMatch(s)) return null;

      // IBGE tem 7 dígitos (ex.: 4118501). TSE costuma ter <= 6.
      if (s.length == 7) return null;

      return s;
    }

    // 1) tenta pelos campos conhecidos
    for (final v in candidates) {
      final s = pick(v);
      if (s != null) return s;
    }

    // 2) heurística: varre todos os valores e pega o "mais plausível"
    // Preferência: 5 dígitos (comum), depois 4-6.
    String? best;
    int bestScore = -1;

    void consider(Object? v) {
      final s = pick(v);
      if (s == null) return;

      final len = s.length;
      int score = 0;
      if (len == 5) score = 3;
      else if (len == 4 || len == 6) score = 2;
      else score = 1;

      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }

    for (final entry in m.entries) {
      consider(entry.value);
    }

    // 3) alguns retornos aninham dados em "municipio"
    final nested = m['municipio'];
    if (nested is Map) {
      final mm = Map<String, dynamic>.from(nested);
      for (final entry in mm.entries) {
        consider(entry.value);
      }
    }

    return best;
  }

  String? get _municipioCodigo {
    final m = _municipio;
    if (m == null) return null;

    final code = _extractMunicipioCodigoTse(m);
    if (code != null) return code;

    // Fallback: se o item já veio normalizado apenas com 'codigo' e ele não é numérico,
    // ainda assim retornamos (evita quebrar fluxos antigos), mas isso pode não funcionar na API.
    final v = m['codigo'];
    final s = v?.toString().trim();
    if (s != null && s.isNotEmpty && s.toLowerCase() != 'null') return s;

    return null;
  }


  String? get _siglaBusca {
    switch (_escopo) {
      case 'BR':
        return 'BR';
      case 'UF':
        return _uf;
      case 'MUN':
        // Para escopo municipal, a API usa o *código do município* (não uma sigla).
        // Normalizamos isso ao carregar a lista.
        return _municipioCodigo;
    }
    return null;
  }

  int? get _cargoCodigo {
    final v = _cargo?['codigo'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  int? get _candidatoId {
    final v = _candidatoSelecionado?['id'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  Future<void> _init({bool hardRefresh = false}) async {
    final token = ++_loadToken;
    if (mounted) {
      setState(() {
        _loadingBase = true;
        _errorBase = null;
      });
    }

    try {
      final rs = await Future.wait<List<dynamic>>([
        _api.eleicoesOrdinarias(forceRefresh: hardRefresh),
        _api.ufs(forceRefresh: hardRefresh),
      ]);

      final eleicoes = rs[0]
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      eleicoes.sort((a, b) {
        final aa = int.tryParse('${a['ano'] ?? 0}') ?? 0;
        final bb = int.tryParse('${b['ano'] ?? 0}') ?? 0;
        if (aa != bb) return bb.compareTo(aa);
        final ida = int.tryParse('${a['id'] ?? 0}') ?? 0;
        final idb = int.tryParse('${b['id'] ?? 0}') ?? 0;
        return idb.compareTo(ida);
      });

      final ufs = rs[1]
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      ufs.sort((a, b) => ('${a['sigla'] ?? ''}').compareTo('${b['sigla'] ?? ''}'));

      // Defaults razoáveis (para o público do app: PR costuma ser o foco)
      final defaultEleicao = eleicoes.isNotEmpty ? eleicoes.first : null;
      final hasPR = ufs.any((u) => (u['sigla']?.toString().toUpperCase() == 'PR'));
      final defaultUf = hasPR ? 'PR' : (ufs.isNotEmpty ? ufs.first['sigla']?.toString() : null);

      final defaultIsMunicipal = (defaultEleicao?['tipoAbrangencia']?.toString().toUpperCase() == 'M');

      if (!mounted || token != _loadToken) return;

      setState(() {
        _eleicoes = eleicoes;
        _ufs = ufs;
        _eleicao = defaultEleicao;
        _uf = defaultUf;
        _escopo = defaultIsMunicipal ? 'MUN' : 'UF';
        _municipios = const [];
        _municipio = null;
        _loadingBase = false;
      });

      await _reloadAfterGeoChange(token: token, hardRefresh: hardRefresh);
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _loadingBase = false;
        _errorBase = e.toString();
      });
    }
  }

  Future<void> _reloadAfterGeoChange({required int token, bool hardRefresh = false}) async {
    // Carrega municípios (se escopo municipal), cargos e candidatos.
    final idEleicao = _idEleicao;
    final ano = _anoEleitoral;
    if (idEleicao == null || ano == null) return;

    // Eleições municipais (tipoAbrangencia == 'M') exigem recorte por município.
    // Se o usuário estiver em UF/BR, a API tende a retornar listas vazias e a UI acaba exibindo zeros.
    if (_isEleicaoMunicipal && _escopo != 'MUN') {
      if (mounted && token == _loadToken) {
        setState(() {
          _escopo = 'MUN';
          _municipios = const [];
          _municipio = null;
        });
      }
    }


    if (_escopo == 'MUN' && _uf != null) {
      try {
        final ms = await _api.municipios(_uf!, forceRefresh: hardRefresh);
        // A API pode retornar uma lista de objetos (Map) ou, em casos raros,
        // uma lista de strings. Normalizamos para {codigo, nome}.
        final municipios = <Map<String, dynamic>>[];
        for (final it in ms) {
          if (it is Map) {
            final m = Map<String, dynamic>.from(it);

            final nome = (m['nome'] ?? m['nomeMunicipio'] ?? m['descricao'] ?? m['ds'] ?? '').toString();
            final codigoTse = _extractMunicipioCodigoTse(m);

            // Preserva o payload original (para compatibilidade futura) e normaliza os campos usados pela UI.
            final item = <String, dynamic>{...m, 'nome': nome};
            if (codigoTse != null) item['codigo'] = codigoTse;

            municipios.add(item);
          } else if (it is String) {
            final nome = it.trim();
            // Alguns endpoints podem retornar diretamente o código como string numérica.
            final codigoTse = RegExp(r'^\d+$').hasMatch(nome) && nome.length != 7 ? nome : null;
            final item = <String, dynamic>{'nome': nome};
            if (codigoTse != null) item['codigo'] = codigoTse;
            municipios.add(item);
          }
        }
        municipios.sort((a, b) => ('${a['nome'] ?? ''}').compareTo('${b['nome'] ?? ''}'));

        if (!mounted || token != _loadToken) return;
        setState(() {
          _municipios = municipios;
          // Se ainda não tem município selecionado, escolhe o primeiro.
          _municipio ??= (municipios.isNotEmpty ? municipios.first : null);
        });
      } catch (_) {
        // se falhar, mantém vazio e deixa UX lidar
        if (!mounted || token != _loadToken) return;
        setState(() => _municipios = const []);
      }
    } else {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _municipios = const [];
        _municipio = null;
      });
    }

    // Recalcula siglaBusca (pode ter mudado ao escolher município default)
    final sigla = _siglaBusca;
    if (sigla == null) return;

    await _reloadCargosAndCandidatos(token: token, hardRefresh: hardRefresh);
  }

  Future<void> _reloadCargosAndCandidatos({
    required int token,
    bool hardRefresh = false,
    bool reloadCargos = true,
  }) async {
    final idEleicao = _idEleicao;
    final ano = _anoEleitoral;
    final siglaBusca = _siglaBusca;

    // No escopo municipal, o TSE exige um *código* de município.
    // Se o endpoint de municípios não trouxe o código (ou mudou o campo),
    // evitamos a chamada e mostramos um aviso para o usuário.
    if (_escopo == 'MUN' && _municipio != null && _municipioCodigo == null) {
      if (mounted && token == _loadToken) {
        setState(() => _errorBase = 'Não foi possível identificar o código do município selecionado. Troque o município ou atualize os dados (pull-to-refresh).');
      }
      return;
    }

    if (idEleicao == null || ano == null || siglaBusca == null) return;

    // Não zera _cargo aqui: isso quebra o dropdown (ele “volta” para o primeiro).
    // Em troca de cargo (reloadCargos=false), mantemos também a lista de cargos
    // para evitar “piscar”/resetar o Dropdown.
    if (mounted && token == _loadToken) {
      setState(() {
        if (reloadCargos) _cargos = const [];
        _candidatos = const [];
        _candidatoSelecionado = null;
        _candidatoDetalheFuture = null;
      });
    }

    try {
      if (reloadCargos) {
        final cargosResp = await _api.cargos(idEleicao: idEleicao, siglaBusca: siglaBusca, forceRefresh: hardRefresh);
        final cargosList = (cargosResp['cargos'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        cargosList.sort((a, b) {
          final na = '${a['nome'] ?? ''}';
          final nb = '${b['nome'] ?? ''}';
          return na.compareTo(nb);
        });

        // tenta manter cargo atual; senão escolhe o primeiro
        Map<String, dynamic>? chosen;
        if (_cargo != null) {
          final cod = _cargoCodigo;
          chosen = cargosList.firstWhere(
            (c) => (int.tryParse('${c['codigo'] ?? ''}') ?? -1) == cod,
            orElse: () => cargosList.isNotEmpty ? cargosList.first : <String, dynamic>{},
          );
          if (chosen.isEmpty) chosen = null;
        } else {
          chosen = cargosList.isNotEmpty ? cargosList.first : null;
        }

        if (!mounted || token != _loadToken) return;
        setState(() {
          _cargos = cargosList;
          _cargo = chosen;
        });
      }

      final cargoCod = _cargoCodigo;
      if (cargoCod == null) return;

      final candResp = await _api.candidatos(
        anoEleitoral: ano,
        siglaBusca: siglaBusca,
        idEleicao: idEleicao,
        cargo: cargoCod,
        forceRefresh: hardRefresh,
      );

      final candList = (candResp['candidatos'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      candList.sort((a, b) => ('${a['nomeUrna'] ?? a['nomeCompleto'] ?? ''}')
          .compareTo('${b['nomeUrna'] ?? b['nomeCompleto'] ?? ''}'));

      if (!mounted || token != _loadToken) return;
      setState(() => _candidatos = candList);
    } catch (e) {
      // Mantém a tela utilizável, mas mostra erro no tab de consulta.
      if (!mounted || token != _loadToken) return;
      setState(() => _errorBase = e.toString());
    }
  }


  List<String?> _consultaDetailLines() {
    final eleicaoNome = _eleicao?['nomeEleicao'] ??
        _eleicao?['descricaoEleicao'] ??
        _eleicao?['nome'] ??
        _eleicao?['descricao'];

    final municipioNome = _municipio?['nome'] ?? _municipio?['descricao'];
    final cargoNome = _cargo?['nome'] ?? _cargo?['descricao'];
    final filtro = _buscaCtrl.text.trim();

    return [
      if (eleicaoNome != null && eleicaoNome.toString().trim().isNotEmpty) 'Eleição: ${eleicaoNome.toString().trim()}',
      if (_anoEleitoral != null) 'Ano: $_anoEleitoral',
      'Escopo: $_escopo',
      if (_uf != null) 'UF: $_uf',
      if (municipioNome != null && municipioNome.toString().trim().isNotEmpty) 'Município: ${municipioNome.toString().trim()}',
      if (cargoNome != null && cargoNome.toString().trim().isNotEmpty) 'Cargo: ${cargoNome.toString().trim()}',
      if (filtro.isNotEmpty) 'Filtro: $filtro',
    ];
  }

  String _buildShareFallback(int tabIndex) {
    const tabs = <int, String>{
      0: 'Consulta',
      1: 'Perfil',
      2: 'Bens',
      3: 'Arquivos',
      4: 'Contas',
      5: 'Histórico',
      6: 'Mais',
    };
    final aba = tabs[tabIndex] ?? 'TSE';
    final cand = _candidatoSelecionado;

    if (tabIndex == 0) {
      return _tseJoinLines([
        'TSE — DivulgaCandContas',
        'Aba: $aba',
        ..._consultaDetailLines(),
        '',
        'Fonte: TSE (DivulgaCandContas)',
      ]);
    }

    if (cand == null) {
      return _tseJoinLines([
        'TSE — DivulgaCandContas',
        'Aba: $aba',
        ..._consultaDetailLines(),
        '',
        'Nenhum candidato selecionado.',
        '',
        'Fonte: TSE (DivulgaCandContas)',
      ]);
    }

    final nome = _tseCandidateName(cand);
    final numero = cand['numero']?.toString().trim();

    final partido = (cand['partido'] is Map) ? Map<String, dynamic>.from(cand['partido']) : <String, dynamic>{};
    final pSigla = partido['sigla']?.toString().trim();

    final situacao = (cand['descricaoSituacao']?.toString() ?? cand['descricaoTotalizacao']?.toString() ?? '').trim();

    return _tseJoinLines([
      'TSE — DivulgaCandContas',
      'Aba: $aba',
      'Candidato(a): $nome',
      if (numero != null && numero.isNotEmpty) 'Número: $numero',
      if (pSigla != null && pSigla.isNotEmpty) 'Partido: $pSigla',
      if (situacao.isNotEmpty) 'Situação: $situacao',
      if (_anoEleitoral != null) 'Ano: $_anoEleitoral',
      '',
      'Conteúdo desta aba ainda está carregando.',
      'Fonte: TSE (DivulgaCandContas)',
    ]);
  }

  void _selectCandidate(BuildContext context, Map<String, dynamic> cand) {
    final idEleicao = _idEleicao;
    final ano = _anoEleitoral;
    final siglaBusca = _siglaBusca;

    final candId = int.tryParse('${cand['id'] ?? ''}');

    if (idEleicao == null || ano == null || siglaBusca == null || candId == null) {
      setState(() {
        _candidatoSelecionado = cand;
        _candidatoDetalheFuture = Future.value(Map<String, dynamic>.from(cand));
      });
      return;
    }

    setState(() {
      _candidatoSelecionado = cand;
      _candidatoDetalheFuture = _api.candidatoDetalhe(
        anoEleitoral: ano,
        siglaBusca: siglaBusca,
        idEleicao: idEleicao,
        candidato: candId,
      );
    });

    // UX: pula direto para a aba Perfil.
    final controller = DefaultTabController.of(context);
    controller.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Builder(
        builder: (ctx) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('TSE - DivulgaCandContas'),
              actions: [
                IconButton(
                  tooltip: 'Compartilhar no WhatsApp',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () async {
                    final controller = DefaultTabController.of(ctx);
                    final tabIndex = controller.index;

                    final msg = _shareTextByTab[tabIndex] ?? _buildShareFallback(tabIndex);
                    shareToWhatsApp(ctx, msg);
                  },
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Consulta', icon: Icon(Icons.search_outlined)),
                  Tab(text: 'Perfil', icon: Icon(Icons.badge_outlined)),
                  Tab(text: 'Bens', icon: Icon(Icons.savings_outlined)),
                  Tab(text: 'Arquivos', icon: Icon(Icons.folder_open_outlined)),
                  Tab(text: 'Contas', icon: Icon(Icons.account_balance_wallet_outlined)),
                  Tab(text: 'Histórico', icon: Icon(Icons.timeline_outlined)),
                  Tab(text: 'Mais', icon: Icon(Icons.more_horiz)),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _ConsultaTab(
                  loadingBase: _loadingBase,
                  errorBase: _errorBase,
                  eleicoes: _eleicoes,
                  ufs: _ufs,
                  municipios: _municipios,
                  cargos: _cargos,
                  candidatos: _candidatos,
                  eleicao: _eleicao,
                  isMunicipal: _isEleicaoMunicipal,
                  escopo: _escopo,
                  uf: _uf,
                  municipio: _municipio,
                  cargo: _cargo,
                  buscaCtrl: _buscaCtrl,
                  onRefreshBase: () => _init(hardRefresh: true),
                  onChangeEleicao: (v) async {
                    final token = ++_loadToken;
                    final isMunicipal = (v?['tipoAbrangencia']?.toString().toUpperCase() == 'M');
                    setState(() {
                      _eleicao = v;
                      _escopo = isMunicipal ? 'MUN' : 'UF';
                      _municipios = const [];
                      _municipio = null;
                      _cargo = null;
                      _candidatoSelecionado = null;
                      _candidatoDetalheFuture = null;
                      _cargos = const [];
                      _candidatos = const [];
                    });
                    await _reloadAfterGeoChange(token: token);
                  },
                  onChangeEscopo: (v) async {
                    if (_isEleicaoMunicipal) return;
                    final token = ++_loadToken;
                    setState(() {
                      _escopo = v;
                      _municipio = null;
                      _candidatoSelecionado = null;
                      _candidatoDetalheFuture = null;
                      _cargos = const [];
                      _candidatos = const [];
                    });
                    await _reloadAfterGeoChange(token: token);
                  },
                  onChangeUf: (v) async {
                    final token = ++_loadToken;
                    setState(() {
                      _uf = v;
                      _municipio = null;
                      _candidatoSelecionado = null;
                      _candidatoDetalheFuture = null;
                      _cargos = const [];
                      _candidatos = const [];
                    });
                    await _reloadAfterGeoChange(token: token);
                  },
                  onChangeMunicipio: (v) async {
                    final token = ++_loadToken;
                    setState(() {
                      _municipio = v;
                      _candidatoSelecionado = null;
                      _candidatoDetalheFuture = null;
                      _cargos = const [];
                      _candidatos = const [];
                    });
                    await _reloadCargosAndCandidatos(token: token, reloadCargos: true);
                  },
                  onChangeCargo: (v) async {
                    final token = ++_loadToken;
                    setState(() {
                      _cargo = v;
                      _candidatoSelecionado = null;
                      _candidatoDetalheFuture = null;
                      _candidatos = const [];
                    });
                    // Troca de cargo não precisa recarregar a lista de cargos;
                    // isso evita o dropdown “voltar” para o primeiro.
                    await _reloadCargosAndCandidatos(token: token, reloadCargos: false);
                  },
                  onSelectCandidato: (cand) => _selectCandidate(ctx, cand),
                  onShareTextChanged: (t) => _setShareTextForTab(0, t),
                ),
                _PerfilTab(detailFuture: _candidatoDetalheFuture, onShareTextChanged: (t) => _setShareTextForTab(1, t)),
                _BensTab(detailFuture: _candidatoDetalheFuture, onShareTextChanged: (t) => _setShareTextForTab(2, t)),
                _ArquivosTab(detailFuture: _candidatoDetalheFuture, onShareTextChanged: (t) => _setShareTextForTab(3, t)),
                _ContasTab(
                  api: _api,
                  detailFuture: _candidatoDetalheFuture,
                  idEleicao: _idEleicao,
                  anoEleitoral: _anoEleitoral,
                  siglaBusca: _siglaBusca,
                  cargoCodigo: _cargoCodigo,
                  candidatoId: _candidatoId,
                  candidateBase: _candidatoSelecionado,
                  onShareTextChanged: (t) => _setShareTextForTab(4, t),
                ),
                _HistoricoTab(detailFuture: _candidatoDetalheFuture, onShareTextChanged: (t) => _setShareTextForTab(5, t)),
                _MaisTab(detailFuture: _candidatoDetalheFuture, onShareTextChanged: (t) => _setShareTextForTab(6, t)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -------------------------------
// TABS
// -------------------------------

class _ConsultaTab extends StatelessWidget {
  final bool loadingBase;
  final String? errorBase;

  final List<Map<String, dynamic>> eleicoes;
  final List<Map<String, dynamic>> ufs;
  final List<Map<String, dynamic>> municipios;
  final List<Map<String, dynamic>> cargos;
  final List<Map<String, dynamic>> candidatos;

  final Map<String, dynamic>? eleicao;
  final bool isMunicipal;
  final String escopo;
  final String? uf;
  final Map<String, dynamic>? municipio;
  final Map<String, dynamic>? cargo;

  final TextEditingController buscaCtrl;

  final Future<void> Function() onRefreshBase;
  final Future<void> Function(Map<String, dynamic>?) onChangeEleicao;
  final Future<void> Function(String) onChangeEscopo;
  final Future<void> Function(String?) onChangeUf;
  final Future<void> Function(Map<String, dynamic>?) onChangeMunicipio;
  final Future<void> Function(Map<String, dynamic>?) onChangeCargo;
  final void Function(Map<String, dynamic>) onSelectCandidato;
  final void Function(String)? onShareTextChanged;

  const _ConsultaTab({
    required this.loadingBase,
    required this.errorBase,
    required this.eleicoes,
    required this.ufs,
    required this.municipios,
    required this.cargos,
    required this.candidatos,
    required this.eleicao,
    required this.isMunicipal,
    required this.escopo,
    required this.uf,
    required this.municipio,
    required this.cargo,
    required this.buscaCtrl,
    required this.onRefreshBase,
    required this.onChangeEleicao,
    required this.onChangeEscopo,
    required this.onChangeUf,
    required this.onChangeMunicipio,
    required this.onChangeCargo,
    required this.onSelectCandidato,
    this.onShareTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingBase) {
      _scheduleShareUpdate(
        context,
        onShareTextChanged,
        _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Consulta',
          'Carregando…',
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]),
      );
      return const Center(child: CircularProgressIndicator());
    }

    final q = buscaCtrl.text.trim().toLowerCase();
    final filtered = (q.isEmpty)
        ? candidatos
        : candidatos.where((c) {
            final nome = ('${c['nomeUrna'] ?? ''} ${c['nomeCompleto'] ?? ''}').toLowerCase();
            final num = '${c['numero'] ?? ''}'.toLowerCase();
            final partido = ('${(c['partido'] is Map) ? (c['partido']['sigla'] ?? '') : ''} ${((c['partido'] is Map) ? (c['partido']['numero'] ?? '') : '')}')
                .toLowerCase();
            return nome.contains(q) || num.contains(q) || partido.contains(q);
          }).toList();

    final effectiveEscopo = isMunicipal ? 'MUN' : escopo;

    final eleicaoNome = eleicao?['nomeEleicao'] ?? eleicao?['descricaoEleicao'] ?? eleicao?['nome'] ?? eleicao?['descricao'];
    final ano = eleicao?['ano']?.toString();
    final municipioNome = municipio?['nome'] ?? municipio?['descricao'];
    final cargoNome = cargo?['nome'] ?? cargo?['descricao'];
    final filtro = buscaCtrl.text.trim();

    final ufLocal = uf;
    final top = filtered.take(10).map((c) {
      final nome = _tseCandidateName(c);
      final num = (c['numero'] ?? '').toString().trim();
      final partido = (c['partido'] is Map) ? Map<String, dynamic>.from(c['partido']) : <String, dynamic>{};
      final sigla = (partido['sigla'] ?? '').toString().trim();
      final s = [
        if (nome.isNotEmpty) nome,
        if (num.isNotEmpty) 'Nº $num',
        if (sigla.isNotEmpty) '(${sigla})',
      ].join(' ');
      return s.isEmpty ? null : '• $s';
    }).whereType<String>().toList();

    _scheduleShareUpdate(
      context,
      onShareTextChanged,
      _tseJoinLines([
        'TSE — DivulgaCandContas',
        'Aba: Consulta',
        if (eleicaoNome != null && eleicaoNome.toString().trim().isNotEmpty) 'Eleição: ${eleicaoNome.toString().trim()}',
        if (ano != null && ano.isNotEmpty) 'Ano: $ano',
        'Escopo: $effectiveEscopo',
        if (ufLocal != null && ufLocal.trim().isNotEmpty) 'UF: $ufLocal',
        if (effectiveEscopo == 'MUN' && municipioNome != null && municipioNome.toString().trim().isNotEmpty)
          'Município: ${municipioNome.toString().trim()}',
        if (cargoNome != null && cargoNome.toString().trim().isNotEmpty) 'Cargo: ${cargoNome.toString().trim()}',
        if (filtro.isNotEmpty) 'Filtro: $filtro',
        'Resultados: ${filtered.length}/${candidatos.length}',
        if (top.isNotEmpty) '',
        ...top,
        '',
        'Fonte: TSE (DivulgaCandContas)',
      ]),
    );

    return RefreshIndicator(
      onRefresh: onRefreshBase,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (errorBase != null) ...[
            _InfoBanner(
              title: 'Aviso',
              message: errorBase!,
              icon: Icons.warning_amber_outlined,
            ),
            const SizedBox(height: 12),
          ],

          _SectionTitle('Filtros'),
          const SizedBox(height: 8),

          DropdownButtonFormField<Map<String, dynamic>>(
            value: eleicao,
            items: eleicoes
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(_fmtEleicao(e), overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Eleição',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => onChangeEleicao(v),
          ),
          const SizedBox(height: 12),

          if (isMunicipal) ...[
            _InfoBanner(
              title: 'Recorte obrigatório',
              message: 'Esta eleição é municipal. Para consultar candidatos e contas, selecione um município (o TSE não retorna dados consolidados por UF/BR nesse pleito).',
              icon: Icons.info_outline,
            ),
            const SizedBox(height: 12),
          ],

          // Em telas estreitas (ou com fonte grande), dois Dropdowns lado a lado
          // podem estourar altura. Aqui a gente faz layout responsivo.
          LayoutBuilder(
            builder: (context, c) {
              final isNarrow = c.maxWidth < 520;

              final escopoField = DropdownButtonFormField<String>(
                isExpanded: true,
                value: effectiveEscopo,
                items: isMunicipal
                    ? const [
                        DropdownMenuItem(value: 'MUN', child: Text('Município', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]
                    : const [
                        DropdownMenuItem(value: 'BR', child: Text('Brasil (BR)', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'UF', child: Text('Unidade Federativa (UF)', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'MUN', child: Text('Município', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                decoration: const InputDecoration(
                  labelText: 'Escopo',
                  border: OutlineInputBorder(),
                ),
                onChanged: isMunicipal
                    ? null
                    : (v) {
                        if (v != null) onChangeEscopo(v);
                      },
              );

              final ufField = DropdownButtonFormField<String>(
                isExpanded: true,
                value: uf,
                items: ufs
                    .map(
                      (u) => DropdownMenuItem(
                        value: u['sigla']?.toString(),
                        child: Text(
                          '${u['sigla'] ?? ''} - ${u['nome'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(
                  labelText: 'UF',
                  border: OutlineInputBorder(),
                ),
                onChanged: (effectiveEscopo == 'BR') ? null : (v) => onChangeUf(v),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    escopoField,
                    const SizedBox(height: 12),
                    ufField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: escopoField),
                  const SizedBox(width: 12),
                  Expanded(child: ufField),
                ],
              );
            },
          ),

          if (effectiveEscopo == 'MUN') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: municipio,
              items: municipios
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text('${m['nome'] ?? ''}', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              decoration: const InputDecoration(
                labelText: 'Município',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => onChangeMunicipio(v),
            ),
          ],

          const SizedBox(height: 12),

          DropdownButtonFormField<Map<String, dynamic>>(
            value: cargo,
            items: cargos
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c['nome'] ?? ''}', overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Cargo',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => onChangeCargo(v),
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller: buscaCtrl,
            decoration: const InputDecoration(
              labelText: 'Buscar (nome, número, partido)',
              prefixIcon: Icon(Icons.search_outlined),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),
          _SectionTitle('Candidatos (${filtered.length})'),
          const SizedBox(height: 8),

          if (filtered.isEmpty)
            const _EmptyState(
              icon: Icons.person_search_outlined,
              title: 'Nada por aqui…',
              message: 'Ajuste os filtros (eleição/escopo/cargo) para listar candidatos.',
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final c = filtered[i];
                return _CandidatoTile(cand: c, onTap: () => onSelectCandidato(c));
              },
            ),
        ],
      ),
    );
  }

  static String _fmtEleicao(Map<String, dynamic> e) {
    final ano = e['ano']?.toString() ?? '';
    final nome = e['nomeEleicao']?.toString() ?? e['descricaoEleicao']?.toString() ?? 'Eleição';
    final turno = e['turno']?.toString();
    return [ano, nome, if (turno != null && turno.isNotEmpty) 'Turno $turno'].join(' • ');
  }
}

class _CandidatoTile extends StatelessWidget {
  final Map<String, dynamic> cand;
  final VoidCallback onTap;

  const _CandidatoTile({required this.cand, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String? nomeUrna = cand['nomeUrna']?.toString();
    final String nome = (nomeUrna != null && nomeUrna.trim().isNotEmpty)
        ? nomeUrna
        : (cand['nomeCompleto']?.toString() ?? '');

    final numero = cand['numero']?.toString() ?? '';
    final situacao = cand['descricaoSituacao']?.toString() ?? cand['descricaoTotalizacao']?.toString() ?? '';

    final partido = (cand['partido'] is Map)
        ? Map<String, dynamic>.from(cand['partido'])
        : <String, dynamic>{};
    final pSigla = partido['sigla']?.toString() ?? '';
    final pNum = partido['numero']?.toString() ?? '';

    final fotoUrl = cand['fotoUrl']?.toString();

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundImage: (fotoUrl != null && fotoUrl.trim().isNotEmpty)
              ? NetworkImage(_normalizeTseUrl(fotoUrl))
              : null,
          child: (fotoUrl == null || fotoUrl.trim().isEmpty) ? const Icon(Icons.person_outline) : null,
        ),
        title: Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (pSigla.isNotEmpty) pSigla,
            if (pNum.isNotEmpty) '(${pNum})',
            if (numero.isNotEmpty) '• Nº $numero',
            if (situacao.isNotEmpty) '• $situacao',
          ].join(' '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _PerfilTab extends StatelessWidget {
  final Future<Map<String, dynamic>>? detailFuture;
  final void Function(String)? onShareTextChanged;

  const _PerfilTab({required this.detailFuture, this.onShareTextChanged});

  @override
  Widget build(BuildContext context) {
    if (detailFuture == null) {
      _scheduleShareUpdate(
        context,
        onShareTextChanged,
        _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Perfil',
          'Nenhum candidato selecionado.',
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]),
      );
      return const _EmptyState(
        icon: Icons.touch_app_outlined,
        title: 'Selecione um candidato',
        message: 'Na aba “Consulta”, toque em um candidato para ver os detalhes.',
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: detailFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          _scheduleShareUpdate(
            context,
            onShareTextChanged,
            _tseJoinLines([
              'TSE — DivulgaCandContas',
              'Aba: Perfil',
              'Carregando…',
              '',
              'Fonte: TSE (DivulgaCandContas)',
            ]),
          );
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _EmptyState(
            icon: Icons.error_outline,
            title: 'Falha ao carregar',
            message: '${snap.error}',
          );
        }

        final c = snap.data ?? const <String, dynamic>{};
        final nomeUrnaRaw = c['nomeUrna']?.toString();
        final nomeUrna = (nomeUrnaRaw ?? '').trim().isNotEmpty ? nomeUrnaRaw : null;
        final nomeCompleto = c['nomeCompleto']?.toString();
        final numero = c['numero']?.toString();
        final sexo = c['descricaoSexo']?.toString();
        final situacao = c['descricaoSituacao']?.toString() ?? c['descricaoSituacaoCandidato']?.toString();
        final fotoUrl = c['fotoUrl']?.toString();

        final cargo = (c['cargo'] is Map) ? Map<String, dynamic>.from(c['cargo']) : <String, dynamic>{};
        final partido = (c['partido'] is Map) ? Map<String, dynamic>.from(c['partido']) : <String, dynamic>{};

        final emails = (c['emails'] as List? ?? const []).whereType<String>().toList();
        final sites = (c['sites'] as List? ?? const []).whereType<String>().toList();

        final nascimento = _parseDate(c['dataDeNascimento']);

        final shareMsg = _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Perfil',
          'Candidato(a): ${_tseCandidateName(c)}',
          if ((cargo['nome'] ?? '').toString().trim().isNotEmpty) 'Cargo: ${cargo['nome']}',
          if ((partido['sigla'] ?? '').toString().trim().isNotEmpty) 'Partido: ${partido['sigla']}',
          if ((numero ?? '').trim().isNotEmpty) 'Número: $numero',
          if ((situacao ?? '').trim().isNotEmpty) 'Situação: $situacao',
          if ((sexo ?? '').trim().isNotEmpty) 'Sexo: $sexo',
          if (nascimento != null) 'Nascimento: ${DateFormat('dd/MM/yyyy').format(nascimento)}',
          if ((c['localCandidatura'] ?? '').toString().trim().isNotEmpty) 'Local: ${c['localCandidatura']}',
          if ((c['ufCandidatura'] ?? '').toString().trim().isNotEmpty) 'UF: ${c['ufCandidatura']}',
          if (emails.isNotEmpty) 'Emails: ${emails.join(', ')}',
          if (sites.isNotEmpty) 'Sites: ${sites.take(5).join(' • ')}',
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]);

        _scheduleShareUpdate(context, onShareTextChanged, shareMsg);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FotoCandidato(url: fotoUrl, size: 88),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (nomeUrna ?? nomeCompleto ?? 'Candidato'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (nomeUrna != null && nomeCompleto != null && nomeCompleto.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                nomeCompleto,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if ((cargo['nome']?.toString() ?? '').isNotEmpty)
                                Chip(label: Text('${cargo['nome']}')),
                              if ((partido['sigla']?.toString() ?? '').isNotEmpty)
                                Chip(label: Text('${partido['sigla']}')),
                              if ((numero ?? '').isNotEmpty) Chip(label: Text('Nº $numero')),
                              if ((situacao ?? '').isNotEmpty) Chip(label: Text(situacao!)),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            _SectionTitle('Dados pessoais'),
            const SizedBox(height: 8),

            _KeyValueCard(items: [
              _kv('Sexo', sexo),
              _kv('Nascimento', nascimento != null ? DateFormat('dd/MM/yyyy').format(nascimento) : null),
              _kv('Nacionalidade', c['nacionalidade']),
              _kv('Grau de instrução', c['grauInstrucao']),
              _kv('Ocupação', c['ocupacao']),
              _kv('Estado civil', c['descricaoEstadoCivil']),
              _kv('Cor/raça', c['descricaoCorRaca']),
              _kv('Naturalidade', c['descricaoNaturalidade']),
              _kv('Município de nascimento', c['nomeMunicipioNascimento']),
              _kv('UF de nascimento', c['sgUfNascimento']),
            ]),

            const SizedBox(height: 12),
            _SectionTitle('Candidatura'),
            const SizedBox(height: 8),

            _KeyValueCard(items: [
              _kv('Local', c['localCandidatura']),
              _kv('UF', c['ufCandidatura']),
              _kv('UF superior', c['ufSuperiorCandidatura']),
              _kv('Coligação', c['nomeColigacao']),
              _kv('Composição', c['composicaoColigacao']),
              _kv('Processo', c['numeroProcesso']),
              _kv('Processo (Drap)', c['numeroProcessoDrap']),
              _kv('Protocolo', c['numeroProtocolo']),
              _kv('CNPJ campanha', c['cnpjcampanha']),
              _kv('Divulgação', _boolStr(c['st_DIVULGA'])),
              _kv('Divulga bens', _boolStr(c['st_DIVULGA_BENS'])),
              _kv('Divulga arquivos', _boolStr(c['st_DIVULGA_ARQUIVOS'])),
              _kv('Reeleição', _boolStr(c['st_REELEICAO'])),
            ]),

            if (emails.isNotEmpty || sites.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionTitle('Contato'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (emails.isNotEmpty) ...[
                        Text('Emails', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: emails.map((e) => Chip(label: Text(e))).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (sites.isNotEmpty) ...[
                        Text('Sites / redes (detectadas)', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 6),
                        ..._sitesAsTiles(context, sites),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            if ((c['vices'] as List? ?? const []).isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionTitle('Vices / suplentes'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: (c['vices'] as List)
                      .whereType<Map>()
                      .map((m) => Map<String, dynamic>.from(m))
                      .map(
                        (v) => ListTile(
                          leading: CircleAvatar(
                            foregroundImage: (v['urlFoto'] is String && (v['urlFoto'] as String).isNotEmpty)
                                ? NetworkImage(_normalizeTseUrl(v['urlFoto'] as String))
                                : null,
                            child: const Icon(Icons.person_outline),
                          ),
                          title: Text('${v['nm_URNA'] ?? v['nm_CANDIDATO'] ?? 'Vice'}'),
                          subtitle: Text('${v['sg_PARTIDO'] ?? ''} ${v['nm_PARTIDO'] ?? ''}'.trim()),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}


mixin _ShareTextEmitter<T extends StatefulWidget> on State<T> {
  String? _lastShareText;

  void _emitShare(BuildContext context, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    if (t == _lastShareText) return;
    _lastShareText = t;

    void Function(String)? cb;
    try {
      cb = (widget as dynamic).onShareTextChanged as void Function(String)?;
    } catch (_) {
      cb = null;
    }

    _scheduleShareUpdate(context, cb, t);
  }
}

class _BensTab extends StatefulWidget {
  final Future<Map<String, dynamic>>? detailFuture;
  final void Function(String)? onShareTextChanged;

  const _BensTab({required this.detailFuture, this.onShareTextChanged});

  @override
  State<_BensTab> createState() => _BensTabState();
}

class _BensTabState extends State<_BensTab> with _ShareTextEmitter {
  final _qCtrl = TextEditingController();
  String? _tipo;
  String _ordem = 'maior'; // maior | menor



  @override
  void initState() {
    super.initState();
    _qCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final future = widget.detailFuture;
    if (future == null) {
      _emitShare(
        context,
        _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Bens',
          'Nenhum candidato selecionado.',
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]),
      );
      return const _EmptyState(
        icon: Icons.touch_app_outlined,
        title: 'Selecione um candidato',
        message: 'Na aba “Consulta”, toque em um candidato para ver os bens declarados.',
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _EmptyState(icon: Icons.error_outline, title: 'Falha ao carregar', message: '${snap.error}');
        }

        final c = snap.data ?? const <String, dynamic>{};
        final divulgaBens = c['st_DIVULGA_BENS'];
        final bens = (c['bens'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final total = (c['totalDeBens'] is num)
            ? c['totalDeBens'] as num
            : num.tryParse('${c['totalDeBens'] ?? ''}');

        if (divulgaBens == false || bens.isEmpty) {
          final shareMsg = _tseJoinLines([
            'TSE — DivulgaCandContas',
            'Aba: Bens',
            'Candidato(a): ${_tseCandidateName(c)}',
            'Sem bens divulgados.',
            '',
            'Fonte: TSE (DivulgaCandContas)',
          ]);
          _emitShare(context, shareMsg);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoBanner(
                title: 'Sem bens divulgados',
                message: 'O TSE pode não ter publicado bens para esta candidatura (ou não há bens declarados).',
                icon: Icons.info_outline,
              ),
            ],
          );
        }

        final q = _qCtrl.text.trim().toLowerCase();
        // `bens` pode vir como List.unmodifiable do decode/cache; nunca ordene/edite a lista original.
        var filtered = bens.toList();

        if (_tipo != null && _tipo!.isNotEmpty) {
          filtered = filtered
              .where((b) => (b['descricaoDeTipoDeBem']?.toString() ?? '').toLowerCase() == _tipo!.toLowerCase())
              .toList();
        }

        if (q.isNotEmpty) {
          filtered = filtered
              .where((b) => ('${b['descricao'] ?? ''} ${b['descricaoDeTipoDeBem'] ?? ''}').toLowerCase().contains(q))
              .toList();
        }

        filtered.sort((a, b) {
          final va = (a['valor'] is num) ? a['valor'] as num : num.tryParse('${a['valor'] ?? 0}') ?? 0;
          final vb = (b['valor'] is num) ? b['valor'] as num : num.tryParse('${b['valor'] ?? 0}') ?? 0;
          return _ordem == 'maior' ? vb.compareTo(va) : va.compareTo(vb);
        });

        final tipos = bens
            .map((b) => b['descricaoDeTipoDeBem']?.toString() ?? '')
            .where((s) => s.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        final shareMsg = _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Bens',
          'Candidato(a): ${_tseCandidateName(c)}',
          if (total != null) 'Total declarado: ${_fmtMoney(total)}',
          'Exibindo: ${filtered.length}/${bens.length}',
          if ((_tipo ?? '').trim().isNotEmpty) 'Tipo: ${_tipo!}',
          if (_qCtrl.text.trim().isNotEmpty) 'Busca: ${_qCtrl.text.trim()}',
          "Ordenação: ${_ordem == 'maior' ? 'Maior valor' : 'Menor valor'}",
          '',
          if (filtered.isNotEmpty) 'Bens:',
          ...filtered.take(10).map((b) {
            final d = b['descricao']?.toString() ?? '';
            final t = b['descricaoDeTipoDeBem']?.toString() ?? '';
            final v = (b['valor'] is num) ? b['valor'] as num : num.tryParse('${b['valor'] ?? ''}');
            final parts = <String>[
              if (d.trim().isNotEmpty) d.trim(),
              if (t.trim().isNotEmpty) t.trim(),
            ];
            final head = parts.isEmpty ? '(sem descrição)' : parts.join(' — ');
            return '- $head: ${_fmtMoney(v)}';
          }),
          if (filtered.length > 10) '…e mais ${filtered.length - 10} item(ns).',
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]);
        _emitShare(context, shareMsg);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.savings_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Total declarado: ${_fmtMoney(total)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text('${filtered.length}/${bens.length}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            _SectionTitle('Filtros'),
            const SizedBox(height: 8),

            TextField(
              controller: _qCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar (descrição/tipo)',
                prefixIcon: Icon(Icons.search_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _tipo,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos os tipos')),
                      ...tipos.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _tipo = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _ordem,
                    items: const [
                      DropdownMenuItem(value: 'maior', child: Text('Maior valor')),
                      DropdownMenuItem(value: 'menor', child: Text('Menor valor')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Ordenar',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _ordem = v ?? 'maior'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _SectionTitle('Bens'),
            const SizedBox(height: 8),

            ...filtered.map((b) {
              final descricao = b['descricao']?.toString() ?? '';
              final tipo = b['descricaoDeTipoDeBem']?.toString() ?? '';
              final valor = (b['valor'] is num) ? b['valor'] as num : num.tryParse('${b['valor'] ?? ''}');
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(descricao, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(tipo),
                  trailing: Text(_fmtMoney(valor)),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _ArquivosTab extends StatefulWidget {
  final Future<Map<String, dynamic>>? detailFuture;
  final void Function(String)? onShareTextChanged;

  const _ArquivosTab({required this.detailFuture, this.onShareTextChanged});

  @override
  State<_ArquivosTab> createState() => _ArquivosTabState();
}

class _ArquivosTabState extends State<_ArquivosTab> with _ShareTextEmitter {
  final _qCtrl = TextEditingController();
  String? _tipo;


  @override
  void initState() {
    super.initState();
    _qCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final future = widget.detailFuture;
    if (future == null) {
      _scheduleShareUpdate(
        context,
        widget.onShareTextChanged,
        _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Arquivos',
          'Nenhum candidato selecionado.',
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]),
      );
      return const _EmptyState(
        icon: Icons.touch_app_outlined,
        title: 'Selecione um candidato',
        message: 'Na aba “Consulta”, toque em um candidato para ver arquivos (plano de governo, certidões, etc.).',
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          _scheduleShareUpdate(
            context,
            widget.onShareTextChanged,
            _tseJoinLines([
              'TSE — DivulgaCandContas',
              'Aba: Arquivos',
              'Carregando…',
              '',
              'Fonte: TSE (DivulgaCandContas)',
            ]),
          );
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _EmptyState(icon: Icons.error_outline, title: 'Falha ao carregar', message: '${snap.error}');
        }

        final c = snap.data ?? const <String, dynamic>{};
        final divulgaArquivos = c['st_DIVULGA_ARQUIVOS'];

        final arquivos = (c['arquivos'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        if (divulgaArquivos == false || arquivos.isEmpty) {
          final shareMsg = _tseJoinLines([
            'TSE — DivulgaCandContas',
            'Aba: Arquivos',
            'Candidato(a): ${_tseCandidateName(c)}',
            'Sem arquivos publicados.',
            '',
            'Fonte: TSE (DivulgaCandContas)',
          ]);
          _emitShare(context, shareMsg);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _EmptyState(
                icon: Icons.folder_off_outlined,
                title: 'Sem arquivos publicados',
                message: 'O TSE pode não ter publicado arquivos para esta candidatura.',
              ),
            ],
          );
        }

        final q = _qCtrl.text.trim().toLowerCase();
        var filtered = arquivos;

        if (_tipo != null && _tipo!.isNotEmpty) {
          filtered = filtered.where((a) => (a['tipo']?.toString() ?? '').toLowerCase() == _tipo!.toLowerCase()).toList();
        }

        if (q.isNotEmpty) {
          filtered = filtered
              .where((a) => ('${a['nome'] ?? ''} ${a['tipo'] ?? ''} ${a['codTipo'] ?? ''}').toLowerCase().contains(q))
              .toList();
        }

        final tipos = arquivos
            .map((a) => a['tipo']?.toString() ?? '')
            .where((s) => s.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        // Prioriza plano de governo no topo (quando existir)
        filtered.sort((a, b) {
          final ta = (a['tipo']?.toString() ?? '').toLowerCase();
          final tb = (b['tipo']?.toString() ?? '').toLowerCase();
          final pa = ta.contains('plano');
          final pb = tb.contains('plano');
          if (pa != pb) return pb ? 1 : -1;
          return ('${a['nome'] ?? ''}').compareTo('${b['nome'] ?? ''}');
        });

        final topFiles = filtered.take(10).map((a) {
          final nome = (a['nome'] ?? '').toString().trim();
          final tipo = (a['tipo'] ?? '').toString().trim();
          final url = (a['url'] ?? '').toString().trim();
          final parts = <String>[
            if (nome.isNotEmpty) nome,
            if (tipo.isNotEmpty) '($tipo)',
            if (url.isNotEmpty) _normalizeTseUrl(url),
          ];
          final line = parts.join(' • ').trim();
          return line.isEmpty ? null : '• $line';
        }).whereType<String>().toList();

        final shareMsg = _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Arquivos',
          'Candidato(a): ${_tseCandidateName(c)}',
          'Arquivos: ${filtered.length}/${arquivos.length}',
          if (_tipo != null && _tipo!.trim().isNotEmpty) 'Tipo: ${_tipo!.trim()}',
          if (_qCtrl.text.trim().isNotEmpty) 'Filtro: ${_qCtrl.text.trim()}',
          if (topFiles.isNotEmpty) '',
          ...topFiles,
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]);

        if (shareMsg != _lastShareText) {
          _lastShareText = shareMsg;
          _scheduleShareUpdate(context, widget.onShareTextChanged, shareMsg);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle('Filtros'),
            const SizedBox(height: 8),
            TextField(
              controller: _qCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar arquivo',
                prefixIcon: Icon(Icons.search_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _tipo,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos os tipos')),
                ...tipos.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))),
              ],
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _tipo = v),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Arquivos (${filtered.length})'),
            const SizedBox(height: 8),
            ...filtered.map((a) {
              final nome = a['nome']?.toString() ?? 'Arquivo';
              final tipo = a['tipo']?.toString() ?? '';
              final url = a['url']?.toString();
              final cod = a['codTipo']?.toString();

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(nome, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text([if (tipo.isNotEmpty) tipo, if (cod != null && cod.isNotEmpty) '($cod)'].join(' ')),
                  trailing: IconButton(
                    tooltip: 'Abrir',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: (url == null || url.trim().isEmpty)
                        ? null
                        : () => _safeOpenExternal(context, Uri.parse(_normalizeTseUrl(url))),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _ContasTab extends StatefulWidget {
  final CachedTseApi api;
  final Future<Map<String, dynamic>>? detailFuture;

  // Base (lista) do candidato, útil para contexto em share.
  final Map<String, dynamic>? candidateBase;
  final void Function(String)? onShareTextChanged;

  final int? idEleicao;
  final int? anoEleitoral;
  final String? siglaBusca;
  final int? cargoCodigo;
  final int? candidatoId;

  const _ContasTab({
    required this.api,
    required this.detailFuture,
    this.candidateBase,
    this.onShareTextChanged,
    required this.idEleicao,
    required this.anoEleitoral,
    required this.siglaBusca,
    required this.cargoCodigo,
    required this.candidatoId,
  });

  @override
  State<_ContasTab> createState() => _ContasTabState();
}

class _ContasTabState extends State<_ContasTab> with _ShareTextEmitter {
  int _mode = 0; // 0 resumo | 1 buscar


  Future<Map<String, dynamic>>? _prestadorFuture;

  final _buscaDoadorCtrl = TextEditingController();
  dynamic _buscaDoadorResult;
  String? _buscaDoadorError;
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _rebuildPrestadorFuture();
  }

  @override
  void didUpdateWidget(covariant _ContasTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idEleicao != widget.idEleicao ||
        oldWidget.anoEleitoral != widget.anoEleitoral ||
        oldWidget.siglaBusca != widget.siglaBusca ||
        oldWidget.cargoCodigo != widget.cargoCodigo ||
        oldWidget.candidatoId != widget.candidatoId) {
      _rebuildPrestadorFuture();
    }
  }

  @override
  void dispose() {
    _buscaDoadorCtrl.dispose();
    super.dispose();
  }

  void _rebuildPrestadorFuture() {
    final idEleicao = widget.idEleicao;
    final ano = widget.anoEleitoral;
    final siglaBusca = widget.siglaBusca;
    final cargo = widget.cargoCodigo;
    final cand = widget.candidatoId;

    if (idEleicao == null || ano == null || siglaBusca == null || cargo == null || cand == null) {
      setState(() => _prestadorFuture = null);
      return;
    }

    setState(() {
      _prestadorFuture = widget.api.prestador(
        idEleicao: idEleicao,
        anoEleitoral: ano,
        siglaBusca: siglaBusca,
        cargo: cargo,
        candidato: cand,
      );
    });
  }

  Future<void> _buscarDoadorFornecedor() async {
    final idEleicao = widget.idEleicao;
    final raw = _buscaDoadorCtrl.text.trim();
    if (idEleicao == null || raw.isEmpty) return;

    setState(() {
      _buscando = true;
      _buscaDoadorError = null;
      _buscaDoadorResult = null;
    });

    try {
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      final isDoc = digits.length >= 11; // heurística (CPF/CNPJ)

      final r = await widget.api.doadorFornecedor(
        idEleicao: idEleicao,
        nome: isDoc ? null : raw,
        cpfCnpj: isDoc ? digits : null,
      );

      setState(() => _buscaDoadorResult = r);
    } catch (e) {
      setState(() => _buscaDoadorError = e.toString());
    } finally {
      setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.detailFuture == null) {
      _emitShare(
        context,
        _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Contas',
          'Nenhum candidato selecionado.',
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]),
      );
return const _EmptyState(
        icon: Icons.touch_app_outlined,
        title: 'Selecione um candidato',
        message: 'Na aba “Consulta”, toque em um candidato para ver prestação de contas (quando disponível).',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              avatar: const Icon(Icons.summarize_outlined, size: 18),
              label: const Text('Resumo'),
              selected: _mode == 0,
              onSelected: (_) => setState(() => _mode = 0),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.manage_search_outlined, size: 18),
              label: const Text('Buscar doador/fornecedor'),
              selected: _mode == 1,
              onSelected: (_) => setState(() => _mode = 1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_mode == 0)
          _ResumoContas(
            prestadorFuture: _prestadorFuture,
            candidateBase: widget.candidateBase,
            onShare: _emitShare,
          )
        else
          _BuscaDoadorFornecedor(
          controller: _buscaDoadorCtrl,
          buscando: _buscando,
          error: _buscaDoadorError,
          result: _buscaDoadorResult,
          candidateBase: widget.candidateBase,
          onShare: _emitShare,
          onBuscar: _buscarDoadorFornecedor,
        ),
      ],
    );
  }
}

class _ResumoContas extends StatelessWidget {
  final Future<Map<String, dynamic>>? prestadorFuture;
  final Map<String, dynamic>? candidateBase;
  final void Function(BuildContext, String)? onShare;

  const _ResumoContas({
    required this.prestadorFuture,
    required this.candidateBase,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    if (prestadorFuture == null) {
      final cand = _tseCandidateName(candidateBase);
      final shareMsg = _tseJoinLines([
        'TSE — DivulgaCandContas',
        'Aba: Contas (Resumo)',
        if (cand.isNotEmpty) 'Candidato(a): $cand',
        'Sem dados de contas (parâmetros insuficientes).',
        '',
        'Fonte: TSE (DivulgaCandContas)',
      ]);
      onShare?.call(context, shareMsg);

      return const _EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Sem dados de contas',
        message: 'Não foi possível montar a consulta (faltam parâmetros da eleição/cargo/candidato).',
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: prestadorFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          final cand = _tseCandidateName(candidateBase);
          final shareMsg = _tseJoinLines([
            'TSE — DivulgaCandContas',
            'Aba: Contas (Resumo)',
            if (cand.isNotEmpty) 'Candidato(a): $cand',
            'Carregando…',
            '',
            'Fonte: TSE (DivulgaCandContas)',
          ]);
      onShare?.call(context, shareMsg);

          return const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          final cand = _tseCandidateName(candidateBase);
          final shareMsg = _tseJoinLines([
            'TSE — DivulgaCandContas',
            'Aba: Contas (Resumo)',
            if (cand.isNotEmpty) 'Candidato(a): $cand',
            'Falha ao carregar: ${snap.error}',
            '',
            'Fonte: TSE (DivulgaCandContas)',
          ]);
      onShare?.call(context, shareMsg);

          return _EmptyState(icon: Icons.error_outline, title: 'Falha ao carregar', message: '${snap.error}');
        }


	      final m = snap.data ?? const <String, dynamic>{};

	      // A API do TSE varia o "shape" entre ciclos/anos/cargos.
	      // Além disso, valores monetários costumam vir como string PT-BR ("1.234,56").
	      // Se a gente não normaliza e não busca os campos com alguma tolerância, tudo cai em 0.
	      final dados = _extractDadosConsolidados(m);

	      final totalRecebido = _toNum(
	        dados['totalRecebido'] ?? dados['totalReceita'] ?? dados['totalReceitas'] ?? dados['totalArrecadado'],
	      );
	      final totalDespesasPagas = _toNum(
	        dados['totalDespesasPagas'] ?? dados['totalDespesaPaga'] ?? dados['totalGastosPagos'] ?? dados['totalDespesas'],
	      );
	      final totalDespesasContratadas = _toNum(
	        dados['totalDespesasContratadas'] ?? dados['totalDespesaContratada'] ?? dados['totalGastosContratados'],
	      );

        final rankingDoadores = (m['rankingDoadores'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final rankingFornecedores = (m['rankingFornecedores'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        rankingDoadores.sort((a, b) => (_toNum(b['valor'])).compareTo(_toNum(a['valor'])));
        rankingFornecedores.sort((a, b) => (_toNum(b['valor'])).compareTo(_toNum(a['valor'])));

        final cand = _tseCandidateName(candidateBase);

        final topDoadores = rankingDoadores.take(5).map((d) {
          final nome = (d['nome'] ?? '').toString().trim();
          final valor = _fmtMoney(_toNum(d['valor']));
          final line = [nome, valor].where((s) => s.trim().isNotEmpty).join(' — ');
          return line.isEmpty ? null : '• $line';
        }).whereType<String>().toList();

        final topFornecedores = rankingFornecedores.take(5).map((d) {
          final nome = (d['nome'] ?? '').toString().trim();
          final valor = _fmtMoney(_toNum(d['valor']));
          final line = [nome, valor].where((s) => s.trim().isNotEmpty).join(' — ');
          return line.isEmpty ? null : '• $line';
        }).whereType<String>().toList();

        final shareMsg = _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Contas (Resumo)',
          if (cand.isNotEmpty) 'Candidato(a): $cand',
          'Total recebido: ${_fmtMoney(totalRecebido)}',
          'Despesas pagas: ${_fmtMoney(totalDespesasPagas)}',
          'Despesas contratadas: ${_fmtMoney(totalDespesasContratadas)}',
          if (topDoadores.isNotEmpty) '',
          if (topDoadores.isNotEmpty) 'Top doadores:',
          ...topDoadores,
          if (topFornecedores.isNotEmpty) '',
          if (topFornecedores.isNotEmpty) 'Top fornecedores:',
          ...topFornecedores,
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]);
      onShare?.call(context, shareMsg);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Totais consolidados'),
            const SizedBox(height: 8),
            _MetricRow(metrics: [
              _Metric(label: 'Total recebido', value: _fmtMoney(totalRecebido)),
              _Metric(label: 'Despesas pagas', value: _fmtMoney(totalDespesasPagas)),
              _Metric(label: 'Despesas contratadas', value: _fmtMoney(totalDespesasContratadas)),
            ]),

            const SizedBox(height: 16),
            _SectionTitle('Ranking de doadores'),
            const SizedBox(height: 8),
            if (rankingDoadores.isEmpty)
              const _InfoBanner(title: 'Sem dados', message: 'O endpoint não retornou ranking de doadores.', icon: Icons.info_outline)
            else
              ...rankingDoadores.take(15).map((d) => _RankTile(
                    icon: Icons.volunteer_activism_outlined,
                    nome: d['nome']?.toString() ?? 'Doador',
                    doc: d['cpfCnpj']?.toString(),
                    valor: _fmtMoney(_toNum(d['valor'])),
                  )),

            const SizedBox(height: 16),
            _SectionTitle('Ranking de fornecedores'),
            const SizedBox(height: 8),
            if (rankingFornecedores.isEmpty)
              const _InfoBanner(title: 'Sem dados', message: 'O endpoint não retornou ranking de fornecedores.', icon: Icons.info_outline)
            else
              ...rankingFornecedores.take(15).map((d) => _RankTile(
                    icon: Icons.storefront_outlined,
                    nome: d['nome']?.toString() ?? 'Fornecedor',
                    doc: d['cpfCnpj']?.toString(),
                    valor: _fmtMoney(_toNum(d['valor'])),
                  )),
          ],
        );
      },
    );
  }
}

class _BuscaDoadorFornecedor extends StatelessWidget {
  final TextEditingController controller;
  final bool buscando;
  final String? error;
  final dynamic result;

  final Map<String, dynamic>? candidateBase;
  final void Function(BuildContext, String)? onShare;
  final VoidCallback onBuscar;

  const _BuscaDoadorFornecedor({
    required this.controller,
    required this.buscando,
    required this.error,
    required this.result,
    required this.candidateBase,
    required this.onShare,
    required this.onBuscar,
  });

  @override
  Widget build(BuildContext context) {
    final cand = _tseCandidateName(candidateBase);
    final q = controller.text.trim();

    String status;
    if (buscando) {
      status = 'Buscando…';
    } else if (error != null) {
      status = 'Falha: $error';
    } else if (result == null) {
      status = q.isEmpty ? 'Pronto para buscar (digite nome ou CPF/CNPJ).' : 'Sem resposta ainda.';
    } else if (result is List) {
      final list = (result as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      status = 'Resultados: ${list.length}';
    } else {
      status = 'Resultado recebido.';
    }

    final lines = <String?>[
      'TSE — DivulgaCandContas',
      'Aba: Contas (Busca)',
      if (cand.isNotEmpty) 'Candidato(a): $cand',
      if (q.isNotEmpty) 'Consulta: $q',
      status,
    ];

    if (!buscando && error == null && result is List) {
      final list = (result as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        ..sort((a, b) => _toNum(b['valor']).compareTo(_toNum(a['valor'])));
      final top = list.take(10).map((d) {
        final nome = (d['nome'] ?? '').toString().trim();
        final doc = (d['cpfCnpj'] ?? '').toString().trim();
        final valor = _fmtMoney(_toNum(d['valor']));
        final parts = <String>[
          if (nome.isNotEmpty) nome,
          if (doc.isNotEmpty) doc,
          if (valor.trim().isNotEmpty) valor,
        ];
        final line = parts.join(' • ').trim();
        return line.isEmpty ? null : '• $line';
      }).whereType<String>().toList();

      if (top.isNotEmpty) {
        lines.add('');
        lines.add('Top resultados:');
        lines.addAll(top);
      }
    }

    lines.add('');
    lines.add('Fonte: TSE (DivulgaCandContas)');

    final shareMsg = _tseJoinLines(lines);
    onShare?.call(context, shareMsg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Busca'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Nome ou CPF/CNPJ',
                  prefixIcon: Icon(Icons.search_outlined),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onBuscar(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: buscando ? null : onBuscar,
              icon: buscando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
              label: const Text('Buscar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (error != null)
          _InfoBanner(title: 'Falha', message: error!, icon: Icons.error_outline)
        else if (result == null)
          const _InfoBanner(
            title: 'Dica',
            message: 'Digite um nome (ex.: “Maria”) ou um CPF/CNPJ (somente números).',
            icon: Icons.lightbulb_outline,
          )
        else
          _renderResult(result),
      ],
    );
  }

  Widget _renderResult(dynamic r) {
    if (r is List) {
      final list = r.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (list.isEmpty) {
        return const _EmptyState(icon: Icons.search_off_outlined, title: 'Sem resultados', message: 'Nenhum doador/fornecedor encontrado.');
      }
      list.sort((a, b) => _toNum(b['valor']).compareTo(_toNum(a['valor'])));
      return Column(
        children: list.take(30).map((d) {
          final nome = d['nome']?.toString() ?? 'Registro';
          final doc = d['cpfCnpj']?.toString();
          final valor = _fmtMoney(_toNum(d['valor']));
          return Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(nome, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(doc ?? ''),
              trailing: Text(valor),
            ),
          );
        }).toList(),
      );
    }

    if (r is Map) {
      final m = Map<String, dynamic>.from(r);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: m.entries.map((e) => _kvLine(e.key, e.value)).toList(),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(r.toString()),
      ),
    );
  }
}

class _HistoricoTab extends StatefulWidget {
  final Future<Map<String, dynamic>>? detailFuture;
  final void Function(String)? onShareTextChanged;

  const _HistoricoTab({required this.detailFuture, this.onShareTextChanged});

  @override
  State<_HistoricoTab> createState() => _HistoricoTabState();
}

class _HistoricoTabState extends State<_HistoricoTab> with _ShareTextEmitter {
  final _qCtrl = TextEditingController();


  @override
  void initState() {
    super.initState();
    _qCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final future = widget.detailFuture;
    if (future == null) {
      _scheduleShareUpdate(
        context,
        widget.onShareTextChanged,
        _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Histórico',
          'Nenhum candidato selecionado.',
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]),
      );
      return const _EmptyState(
        icon: Icons.touch_app_outlined,
        title: 'Selecione um candidato',
        message: 'Na aba “Consulta”, toque em um candidato para ver eleições anteriores.',
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          _scheduleShareUpdate(
            context,
            widget.onShareTextChanged,
            _tseJoinLines([
              'TSE — DivulgaCandContas',
              'Aba: Histórico',
              'Carregando…',
              '',
              'Fonte: TSE (DivulgaCandContas)',
            ]),
          );
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final shareMsg = _tseJoinLines([
            'TSE — DivulgaCandContas',
            'Aba: Histórico',
            'Falha ao carregar: ${snap.error}',
            '',
            'Fonte: TSE (DivulgaCandContas)',
          ]);
          _emitShare(context, shareMsg);

          return _EmptyState(icon: Icons.error_outline, title: 'Falha ao carregar', message: '${snap.error}');
        }

        final c = snap.data ?? const <String, dynamic>{};
        final hist = (c['eleicoesAnteriores'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        if (hist.isEmpty) {
          final shareMsg = _tseJoinLines([
            'TSE — DivulgaCandContas',
            'Aba: Histórico',
            'Candidato(a): ${_tseCandidateName(c)}',
            'Sem histórico.',
            '',
            'Fonte: TSE (DivulgaCandContas)',
          ]);
          _emitShare(context, shareMsg);

          return const _EmptyState(
            icon: Icons.timeline_outlined,
            title: 'Sem histórico',
            message: 'O TSE não retornou eleições anteriores para esta candidatura.',
          );
        }

        hist.sort((a, b) {
          final aa = int.tryParse('${a['nrAno'] ?? 0}') ?? 0;
          final bb = int.tryParse('${b['nrAno'] ?? 0}') ?? 0;
          return bb.compareTo(aa);
        });

        final q = _qCtrl.text.trim().toLowerCase();
        final filtered = q.isEmpty
            ? hist
            : hist.where((e) {
                final s = ('${e['nrAno'] ?? ''} ${e['cargo'] ?? ''} ${e['local'] ?? ''} ${e['partido'] ?? ''} ${e['situacaoTotalizacao'] ?? ''}')
                    .toLowerCase();
                return s.contains(q);
              }).toList();

        final top = filtered.take(10).map((e) {
          final ano = (e['nrAno'] ?? '').toString().trim();
          final cargo = (e['cargo'] ?? '').toString().trim();
          final local = (e['local'] ?? '').toString().trim();
          final partido = (e['partido'] ?? '').toString().trim();
          final situacao = (e['situacaoTotalizacao'] ?? '').toString().trim();
          final line = [
            if (ano.isNotEmpty) ano,
            if (cargo.isNotEmpty) cargo,
            if (local.isNotEmpty) local,
            if (partido.isNotEmpty) partido,
            if (situacao.isNotEmpty) situacao,
          ].join(' • ').trim();
          return line.isEmpty ? null : '• $line';
        }).whereType<String>().toList();

        final shareMsg = _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Histórico',
          'Candidato(a): ${_tseCandidateName(c)}',
          'Registros: ${filtered.length}/${hist.length}',
          if (_qCtrl.text.trim().isNotEmpty) 'Filtro: ${_qCtrl.text.trim()}',
          if (top.isNotEmpty) '',
          ...top,
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]);

        if (shareMsg != _lastShareText) {
          _lastShareText = shareMsg;
          _scheduleShareUpdate(context, widget.onShareTextChanged, shareMsg);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _qCtrl,
              decoration: const InputDecoration(
                labelText: 'Filtrar (ano, cargo, local, partido)',
                prefixIcon: Icon(Icons.search_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Eleições anteriores (${filtered.length})'),
            const SizedBox(height: 8),
            ...filtered.map((e) {
              final ano = e['nrAno']?.toString() ?? '';
              final cargo = e['cargo']?.toString() ?? '';
              final local = e['local']?.toString() ?? '';
              final partido = e['partido']?.toString() ?? '';
              final situacao = e['situacaoTotalizacao']?.toString() ?? '';
              final link = e['txLink']?.toString();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.how_to_vote_outlined),
                  title: Text('$ano • $cargo'),
                  subtitle: Text([local, partido, situacao].where((s) => s.trim().isNotEmpty).join(' • ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new),
                    tooltip: 'Abrir no TSE',
                    onPressed: (link == null || link.trim().isEmpty)
                        ? null
                        : () => _safeOpenExternal(context, Uri.parse(_normalizeTseUrl(link))),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _MaisTab extends StatefulWidget {
  final Future<Map<String, dynamic>>? detailFuture;
  final void Function(String)? onShareTextChanged;

  const _MaisTab({required this.detailFuture, this.onShareTextChanged});

  @override
  State<_MaisTab> createState() => _MaisTabState();
}

class _MaisTabState extends State<_MaisTab> with _ShareTextEmitter {
  final _qCtrl = TextEditingController();


  @override
  void initState() {
    super.initState();
    _qCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final future = widget.detailFuture;
    if (future == null) {
      _scheduleShareUpdate(
        context,
        widget.onShareTextChanged,
        _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Mais',
          'Nenhum candidato selecionado.',
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]),
      );
      return const _EmptyState(
        icon: Icons.touch_app_outlined,
        title: 'Selecione um candidato',
        message: 'Na aba “Consulta”, toque em um candidato para ver os demais campos da API.',
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          _scheduleShareUpdate(
            context,
            widget.onShareTextChanged,
            _tseJoinLines([
              'TSE — DivulgaCandContas',
              'Aba: Mais',
              'Carregando…',
              '',
              'Fonte: TSE (DivulgaCandContas)',
            ]),
          );
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final shareMsg = _tseJoinLines([
            'TSE — DivulgaCandContas',
            'Aba: Mais',
            'Falha ao carregar: ${snap.error}',
            '',
            'Fonte: TSE (DivulgaCandContas)',
          ]);
          _emitShare(context, shareMsg);

          return _EmptyState(icon: Icons.error_outline, title: 'Falha ao carregar', message: '${snap.error}');
        }

        final c = snap.data ?? const <String, dynamic>{};
        final entries = c.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        final q = _qCtrl.text.trim().toLowerCase();
        final filtered = q.isEmpty
            ? entries
            : entries.where((e) => e.key.toLowerCase().contains(q)).toList();

        final top = filtered.take(15).map((e) {
          final k = e.key;
          final v = e.value;
          String pretty;
          if (v is Map) {
            pretty = 'Objeto (${v.length} chaves)';
          } else if (v is List) {
            pretty = 'Lista (${v.length} itens)';
          } else {
            pretty = (v == null) ? '—' : v.toString();
          }
          final line = '$k: $pretty'.trim();
          return line.isEmpty ? null : '• $line';
        }).whereType<String>().toList();

        final shareMsg = _tseJoinLines([
          'TSE — DivulgaCandContas',
          'Aba: Mais',
          'Candidato(a): ${_tseCandidateName(c)}',
          'Campos: ${filtered.length}/${entries.length}',
          if (_qCtrl.text.trim().isNotEmpty) 'Filtro: ${_qCtrl.text.trim()}',
          if (top.isNotEmpty) '',
          ...top,
          '',
          'Fonte: TSE (DivulgaCandContas)',
        ]);

        if (shareMsg != _lastShareText) {
          _lastShareText = shareMsg;
          _scheduleShareUpdate(context, widget.onShareTextChanged, shareMsg);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _qCtrl,
              decoration: const InputDecoration(
                labelText: 'Filtrar campos (digite o nome do campo)',
                prefixIcon: Icon(Icons.search_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Campos (${filtered.length})'),
            const SizedBox(height: 8),
            ...filtered.map((e) {
              final v = e.value;
              String pretty;
              if (v is Map) {
                pretty = 'Objeto (${v.length} chaves)';
              } else if (v is List) {
                pretty = 'Lista (${v.length} itens)';
              } else {
                pretty = (v == null) ? '—' : v.toString();
              }
              return Card(
                child: ListTile(
                  title: Text(e.key),
                  subtitle: Text(pretty, maxLines: 3, overflow: TextOverflow.ellipsis),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// -------------------------------
// UI HELPERS
// -------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyState({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _InfoBanner({required this.title, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FotoCandidato extends StatelessWidget {
  final String? url;
  final double size;

  const _FotoCandidato({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final u = (url == null || url!.trim().isEmpty) ? null : _normalizeTseUrl(url!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: u == null
            ? const Icon(Icons.person_outline, size: 40)
            : Image.network(
                u,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.person_outline, size: 40),
              ),
      ),
    );
  }
}

class _KeyValueCard extends StatelessWidget {
  final List<_KV> items;
  const _KeyValueCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final visible = items.where((i) => i.value != null && i.value.toString().trim().isNotEmpty).toList();
    if (visible.isEmpty) {
      return const _InfoBanner(
        title: 'Sem dados',
        message: 'O TSE não retornou informações para este bloco.',
        icon: Icons.info_outline,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: visible.map((i) => _kvLine(i.label, i.value)).toList(),
        ),
      ),
    );
  }
}

class _KV {
  final String label;
  final dynamic value;
  const _KV(this.label, this.value);
}

_KV _kv(String label, dynamic value) => _KV(label, value);

Widget _kvLine(String label, dynamic value) {
  final v = (value == null) ? '—' : value.toString();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Expanded(flex: 6, child: Text(v)),
      ],
    ),
  );
}

class _MetricRow extends StatelessWidget {
  final List<_Metric> metrics;
  const _MetricRow({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: metrics
          .map(
            (m) => Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.label, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Text(m.value, style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});
}

class _RankTile extends StatelessWidget {
  final IconData icon;
  final String nome;
  final String? doc;
  final String valor;

  const _RankTile({required this.icon, required this.nome, required this.doc, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(nome, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(doc ?? ''),
        trailing: Text(valor),
      ),
    );
  }
}

// -------------------------------


// -------------------------------
// Share helpers
// -------------------------------

String _tseJoinLines(Iterable<String?> lines) {
  final out = <String>[];
  var lastBlank = false;

  for (final raw in lines) {
    final s = (raw ?? '').toString();

    // Preserva intenção de "linha em branco", mas colapsa múltiplas.
    if (s.trim().isEmpty) {
      if (out.isNotEmpty && !lastBlank) {
        out.add('');
        lastBlank = true;
      }
      continue;
    }

    out.add(s.trimRight());
    lastBlank = false;
  }

  while (out.isNotEmpty && out.last.trim().isEmpty) {
    out.removeLast();
  }

  return out.join('\n');
}

String _tseCandidateName(Map<String, dynamic>? cand) {
  if (cand == null) return '';
  final nomeUrna = (cand['nomeUrna'] ?? cand['nome'] ?? '').toString().trim();
  if (nomeUrna.isNotEmpty) return nomeUrna;

  final nomeCompleto = (cand['nomeCompleto'] ?? cand['nomeCandidato'] ?? '').toString().trim();
  if (nomeCompleto.isNotEmpty) return nomeCompleto;

  return '';
}

void _scheduleShareUpdate(BuildContext context, void Function(String)? onShareTextChanged, String text) {
  if (onShareTextChanged == null) return;
  final t = text.trim();
  if (t.isEmpty) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    onShareTextChanged(t);
  });
}

// Parsing / Formatting helpers
// -------------------------------

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;

  // O swagger marca como int64, e na prática costuma vir como epoch em ms.
  final n = (v is int) ? v : int.tryParse(v.toString());
  if (n == null) return null;

  // Heurística:
  // - >= 1e12: ms
  // - >= 1e9: segundos
  // - >= 1e7: YYYYMMDD
  if (n >= 1000000000000) {
    return DateTime.fromMillisecondsSinceEpoch(n);
  }
  if (n >= 1000000000) {
    return DateTime.fromMillisecondsSinceEpoch(n * 1000);
  }
  if (n >= 10000000) {
    final s = n.toString().padLeft(8, '0');
    final y = int.tryParse(s.substring(0, 4));
    final m = int.tryParse(s.substring(4, 6));
    final d = int.tryParse(s.substring(6, 8));
    if (y != null && m != null && d != null) {
      return DateTime(y, m, d);
    }
  }
  return null;
}

String _fmtMoney(num? v) {
  if (v == null) return '—';
  return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
}

String _boolStr(dynamic v) {
  if (v == null) return '—';
  if (v is bool) return v ? 'Sim' : 'Não';
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1' || s == 's') return 'Sim';
  if (s == 'false' || s == '0' || s == 'n') return 'Não';
  return v.toString();
}

num _toNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;

  // A API do TSE frequentemente devolve valores monetários como string em PT-BR:
  // "1.234,56". Também aparecem variantes como "1234,56", "1234.56" e "R$ 1.234,56".
  var s = v.toString().trim();
  if (s.isEmpty) return 0;

  // Remove moeda/espaços e mantém somente dígitos + separadores.
  s = s.replaceAll(RegExp(r'[^0-9,\.\-]'), '');
  if (s.isEmpty) return 0;

  final hasComma = s.contains(',');
  final hasDot = s.contains('.');

  if (hasComma && hasDot) {
    // Decide qual é o separador decimal pelo último que aparece.
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    final decimalIsComma = lastComma > lastDot;
    if (decimalIsComma) {
      // 1.234,56
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // 1,234.56
      s = s.replaceAll(',', '');
    }
  } else if (hasComma && !hasDot) {
    // 1234,56
    s = s.replaceAll(',', '.');
  } else {
    // 1234.56 ou 1234
  }

  return num.tryParse(s) ?? 0;
}

/// Procura recursivamente (DFS) o primeiro Map que contenha algum dos [keys].
Map<String, dynamic>? _findFirstMapWithKeys(dynamic root, Set<String> keys) {
  if (root is Map) {
    final m = Map<String, dynamic>.from(root);
    if (m.keys.any(keys.contains)) return m;
    for (final v in m.values) {
      final found = _findFirstMapWithKeys(v, keys);
      if (found != null) return found;
    }
    return null;
  }
  if (root is List) {
    for (final it in root) {
      final found = _findFirstMapWithKeys(it, keys);
      if (found != null) return found;
    }
  }
  return null;
}

/// Extrai o bloco de totais consolidados de forma resiliente.
///
/// Em diferentes ciclos/anos/cargos, o TSE pode mudar o "shape" do JSON.
/// Este helper evita que a UI caia em R$ 0,00 só por estar procurando no lugar errado.
Map<String, dynamic> _extractDadosConsolidados(Map<String, dynamic> m) {
  final dc = m['dadosConsolidados'];
  if (dc is Map) return Map<String, dynamic>.from(dc);

  // Tenta localizar o bloco onde quer que ele esteja.
  final keys = <String>{
    'totalRecebido',
    'totalReceita',
    'totalReceitas',
    'totalArrecadado',
    'totalDespesasPagas',
    'totalDespesaPaga',
    'totalDespesasContratadas',
    'totalDespesaContratada',
    'totalGastosPagos',
    'totalGastosContratados',
  };
  return _findFirstMapWithKeys(m, keys) ?? <String, dynamic>{};
}

String _normalizeTseUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
  const host = 'divulgacandcontas.tse.jus.br';
  // A API costuma devolver paths relativos.
  final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return Uri.https(host, path).toString();
}

String _normalizeExternalUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
  return 'https://$trimmed';
}

Future<void> _safeOpenExternal(BuildContext context, Uri uri) async {
  try {
    await openExternal(uri);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o link.')),
    );
  }
}

List<Widget> _sitesAsTiles(BuildContext context, List<String> sites) {
  final normalized = sites.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  String labelFor(String u) {
    final l = u.toLowerCase();
    if (l.contains('instagram.com')) return 'Instagram';
    if (l.contains('facebook.com')) return 'Facebook';
    if (l.contains('youtube.com') || l.contains('youtu.be')) return 'YouTube';
    if (l.contains('tiktok.com')) return 'TikTok';
    if (l.contains('twitter.com') || l.contains('x.com')) return 'X (Twitter)';
    if (l.contains('linkedin.com')) return 'LinkedIn';
    if (l.contains('wa.me') || l.contains('whatsapp.com')) return 'WhatsApp';
    return 'Site';
  }

  return normalized.map((u) {
    final label = labelFor(u);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.link),
      title: Text(label),
      subtitle: Text(u, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.open_in_new),
      onTap: () async => _safeOpenExternal(context, Uri.parse(_normalizeExternalUrl(u))),
    );
  }).toList();
}