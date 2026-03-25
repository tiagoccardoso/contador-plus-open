// lib/src/features/calendar/calendar_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/settings/settings_screen.dart' show AppSettingsKeys;
import '../../shared/agenda_federal_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with WidgetsBindingObserver {
  late DateTime _cursor;

  // Ajustes (carregados de SharedPreferences)
  bool _autoUpdateOnMonthTurn = true;
  bool _checkOnResume = true;
  bool _weekStartsMonday = true;
  bool _showFederalBadge = true;

  // Federais (via serviço compartilhado)
  Timer? _monthTimer;
  DateTime _fedMonthKey = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<FedObligation> _fedMonthList = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _cursor = DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addObserver(this);

    // Carrega ajustes primeiro; depois agenda o watcher
    _loadSettings().then((_) {
      _scheduleMonthWatcher();
    });

    _loadFederalFor(_fedMonthKey);
  }

  @override
  void dispose() {
    _monthTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // =====================
  // Preferências (settings)
  // =====================
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoUpdateOnMonthTurn =
          prefs.getBool(AppSettingsKeys.autoUpdateOnMonthTurn) ?? true;
      _checkOnResume =
          prefs.getBool(AppSettingsKeys.checkOnResume) ?? true;
      _weekStartsMonday =
          prefs.getBool('settings.weekStartsMonday') ?? true;
      _showFederalBadge =
          prefs.getBool('settings.showFederalBadge') ?? true;
    } catch (e) {
      // mantém defaults seguros
      debugPrint('Falha lendo ajustes do calendário: $e');
    }
    if (mounted) setState(() {});
  }

  // =====================
  // Ciclo de vida do app
  // =====================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _checkOnResume) {
      final n = DateTime.now();
      final m = DateTime(n.year, n.month, 1);

      if (m.year != _cursor.year || m.month != _cursor.month) {
        setState(() => _cursor = m);
      }
      if (m.year != _fedMonthKey.year || m.month != _fedMonthKey.month) {
        _fedMonthKey = m;
        _loadFederalFor(_fedMonthKey);
      }
      _scheduleMonthWatcher();
      // Recarrega ajustes (caso o usuário tenha mudado algo nos Ajustes)
      _loadSettings();
    }
  }

  // =====================
  // Watcher da meia-noite
  // =====================
  void _scheduleMonthWatcher() {
    _monthTimer?.cancel();
    if (!_autoUpdateOnMonthTurn) return;

    final now = DateTime.now();
    final nextMidnight =
    DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    // Folga de 5s para evitar jitter/DST
    final fireAt = nextMidnight.add(const Duration(seconds: 5));
    final delay = fireAt.difference(now);

    _monthTimer = Timer(delay, () async {
      if (!mounted) return;
      final n = DateTime.now();
      final month = DateTime(n.year, n.month, 1);

      if (_cursor.year != month.year || _cursor.month != month.month) {
        setState(() => _cursor = month);
      }
      if (month.year != _fedMonthKey.year || month.month != _fedMonthKey.month) {
        _fedMonthKey = month;
        await _loadFederalFor(_fedMonthKey);
      }

      // Rearma para a próxima noite
      _scheduleMonthWatcher();
    });
  }

  Future<void> _loadFederalFor(DateTime monthKey) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _fedMonthList = await AgendaFederalService.instance.getMonth(monthKey);
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========
  // Navegação
  // =========
  void _prev() {
    setState(() {
      _cursor = DateTime(_cursor.year, _cursor.month - 1, 1);
      _fedMonthKey = DateTime(_cursor.year, _cursor.month, 1);
    });
    _loadFederalFor(_fedMonthKey);
  }

  void _next() {
    setState(() {
      _cursor = DateTime(_cursor.year, _cursor.month + 1, 1);
      _fedMonthKey = DateTime(_cursor.year, _cursor.month, 1);
    });
    _loadFederalFor(_fedMonthKey);
  }

  void _goToday() {
    final n = DateTime.now();
    setState(() {
      _cursor = DateTime(n.year, n.month, 1);
      _fedMonthKey = DateTime(_cursor.year, _cursor.month, 1);
    });
    _loadFederalFor(_fedMonthKey);
  }

  // =========
  // UI/BUILD
  // =========
  @override
  Widget build(BuildContext context) {
    final monthLabel = _monthLabel(_cursor);
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendário — $monthLabel'),
        actions: [
          IconButton(onPressed: _prev, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: _next, icon: const Icon(Icons.chevron_right)),
          TextButton(onPressed: _goToday, child: const Text('Hoje')),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Não foi possível atualizar do gov.br:\n$_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(child: _buildMonthGrid(context)),
        ],
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const nomes = [
      'janeiro','fevereiro','março','abril','maio','junho',
      'julho','agosto','setembro','outubro','novembro','dezembro'
    ];
    return '${nomes[d.month - 1]} de ${d.year}';
  }

  /// GRID à prova de overflow (Stack + AspectRatio), respeitando início da semana.
  Widget _buildMonthGrid(BuildContext context) {
    final fedByDay = <int, List<FedObligation>>{};
    for (final f in _fedMonthList) {
      if (f.date.year == _cursor.year && f.date.month == _cursor.month) {
        fedByDay.putIfAbsent(f.date.day, () => []).add(f);
      }
    }

    final localCount = __localCountByDay(DateTime(_cursor.year, _cursor.month, 1));
    final cells = <Widget>[];

    // Cabeçalho: semana começa na segunda (S T Q Q S S D) ou no domingo (D S T Q Q S S)
    final weekDays = _weekStartsMonday
        ? const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']
        : const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    cells.addAll(weekDays.map((w) => Center(
      child: Text(w, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    )));

    // Offset até o 1º dia
    // weekday: 1..7 (Mon..Sun)
    // Monday-first -> offset = (weekday + 6) % 7
    // Sunday-first -> offset = weekday % 7
    final firstWeekday = DateTime(_cursor.year, _cursor.month, 1).weekday; // 1..7
    final startOffset = _weekStartsMonday ? (firstWeekday + 6) % 7 : (firstWeekday % 7);
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox.shrink());
    }

    final daysInMonth = DateUtils.getDaysInMonth(_cursor.year, _cursor.month);
    final now = DateTime.now();

    for (int d = 1; d <= daysInMonth; d++) {
      final fed = fedByDay[d] ?? const [];
      final loc = localCount[d] ?? 0;
      final total = loc + fed.length;
      final isToday = now.year == _cursor.year && now.month == _cursor.month && now.day == d;

      cells.add(GestureDetector(
        onTap: () {
          if (loc > 0) {
            __openLocalDay(context, DateTime(_cursor.year, _cursor.month, d));
          } else if (fed.isNotEmpty) {
            __fedShowFederalDay(context, d, fed);
          }
        },
        onLongPress: () {
          if (loc > 0 && fed.isNotEmpty) {
            showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.event_note),
                      title: const Text('Abrir obrigações locais'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        __openLocalDay(context, DateTime(_cursor.year, _cursor.month, d));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('Abrir obrigações federais'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        __fedShowFederalDay(context, d, fed);
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        },
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              color: total == 0
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.primary.withValues(alpha: (total.clamp(1, 6) / 12.0)),
            ),
            child: Stack(
              children: [
                // Dia
                Positioned(
                  top: 4, left: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$d', style: TextStyle(
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      )),
                      if (isToday)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.circle, size: 6),
                        ),
                    ],
                  ),
                ),
                // Contador
                if (total > 0)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Theme.of(context).colorScheme.secondaryContainer,
                      ),
                      child: Text('$total',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                // Pontinhos locais
                if (loc > 0)
                  Positioned(
                    left: 6, bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(loc.clamp(1, 3), (i) => Container(
                        width: 6, height: 6,
                        margin: EdgeInsets.only(right: i < (loc.clamp(1, 3) - 1) ? 4 : 0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )),
                    ),
                  ),
                // Selo FED (respeita ajuste showFederalBadge)
                if (_showFederalBadge && fed.isNotEmpty)
                  Positioned(
                    right: 6, bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.65),
                      ),
                      child: Text('FED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ));
    }

    return GridView.count(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      crossAxisCount: 7,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.0,
      children: cells,
    );
  }

  /// Sheet: federais do dia (rolável) + “Pergunte para IA”
  void __fedShowFederalDay(BuildContext context, int day, List<FedObligation> fed) {
    fed.sort((a, b) => a.title.compareTo(b.title));
    final selectedDate = DateTime(_cursor.year, _cursor.month, day);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Obrigações federais — $day/${_cursor.month}/${_cursor.year}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: fed.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final o = fed[i];
                        final prompt = __aiPromptForObligation(o, selectedDate);
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.flag_outlined, size: 18),
                          title: Text(o.title),
                          subtitle: Text(o.code == null ? o.sourceUrl : 'Código: ${o.code}'),
                          onTap: () => __openAskAI(context, prompt),
                          trailing: IconButton(
                            tooltip: 'Perguntar para IA',
                            icon: const Icon(Icons.auto_awesome),
                            onPressed: () => __openAskAI(context, prompt),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Fechar'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String __aiPromptForObligation(FedObligation o, DateTime date) {
    final dd = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final code = o.code == null ? '' : ' (código ${o.code})';
    return 'Explique a obrigação federal a seguir, em linguagem simples, considerando vencimento em $dd$code. '
        'Inclua: quem deve cumprir, base legal, forma de preparo/entrega, comprovantes, multas por atraso e boas práticas.\n\n'
        '${o.title}\n\nFonte oficial: ${o.sourceUrl}';
  }

  Future<void> __openAskAI(BuildContext context, String question) async {
    Navigator.of(context).maybePop();
    await Future.delayed(const Duration(milliseconds: 60));
    if (!context.mounted) return;
    try {
      context.push('/learning', extra: question);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: question));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pergunta copiada. Abra a tela "Aprender" e cole para perguntar.')),
      );
    }
  }

  // ================
  // GANCHOS locais
  // ================
  Map<int, int> __localCountByDay(DateTime firstOfMonth) {
    return const {};
  }

  void __openLocalDay(BuildContext context, DateTime day) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Abrir obrigações locais em ${day.day}/${day.month}/${day.year} (implemente __openLocalDay)')),
    );
  }
}
