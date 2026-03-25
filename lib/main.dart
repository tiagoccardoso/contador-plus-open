import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'src/shared/agenda_federal_service.dart';

import 'src/app_theme.dart';
import 'src/features/home/home_screen.dart';
import 'src/features/calendar/calendar_screen.dart';
import 'src/features/deadline/deadline_screen.dart';
import 'src/features/learning/learning_screen.dart';
import 'src/features/deputados/deputados_screen.dart';
import 'src/features/deputados/deputado_detail_screen.dart'; // <-- NOVO
import 'src/features/senadores/senadores_screen.dart';
import 'src/features/senadores/senador_detail_screen.dart';
import 'src/features/deputados_estaduais_pr/deputados_estaduais_pr_screen.dart';
import 'src/features/tse/tse_screen.dart';
import 'src/features/settings/settings_screen.dart';
import 'src/features/normas/normas_screen.dart';
import 'src/features/reforma/reforma_screen.dart';
import 'src/features/reforma_timeline/rt_timeline_screen.dart';
import 'src/features/about/about_sources_screen.dart';
import 'src/features/podcast/podcast_screen.dart';

// Exibe erros de renderização na UI (evita "tela branca" silenciosa)
void _installGlobalErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFF6F4F8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Falha ao iniciar/renderizar:\n\n${details.exceptionAsString()}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorWidget();
  // Carrega .env se existir, sem travar caso não exista
  try {
    try { await dotenv.load(fileName: '.env'); } catch (_) {
      try { await dotenv.load(fileName: 'assets/.env'); } catch (_) {
        try { await dotenv.load(fileName: 'assets/env/.env'); } catch (_) {}
      }
    }
  } catch (_) {
    // segue sem .env
  }

  // Pré-carrega cache da Agenda Federal do mês atual e próximo (render instantânea)
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 1);
  final nextMonth = DateTime(now.year, now.month + 1, 1);
  await AgendaFederalService.instance.hydrateFromDisk(months: [thisMonth, nextMonth]);
  runApp(const ProviderScope(child: ContadorPlusApp()));
}

class ContadorPlusApp extends ConsumerWidget {
  const ContadorPlusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/sources', builder: (context, state) => const AboutSourcesScreen()),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (ctx, st) => const HomeScreen()),
            GoRoute(path: '/calendar', builder: (ctx, st) => const CalendarScreen()),
            GoRoute(path: '/learning', builder: (ctx, st) => const LearningScreen()),
            GoRoute(path: '/deputados', builder: (ctx, st) => const DeputadosFederaisScreen()),
            // ---------- NOVA ROTA: detalhes do deputado ----------
            GoRoute(
              path: '/deputados/:id',
              builder: (ctx, st) {
                final id = int.parse(st.pathParameters['id']!);
                final nome = (st.extra is Map) ? (st.extra as Map)['nome'] as String? : null;
                return DeputadoDetailScreen(id: id, nome: nome);
              },
            ),
            // -----------------------------------------------------

            GoRoute(path: '/senadores', builder: (ctx, st) => const SenadoresScreen()),
            GoRoute(
              path: '/senadores/:id',
              builder: (ctx, st) {
                final id = st.pathParameters['id']!;
                final nome = (st.extra is Map) ? (st.extra as Map)['nome'] as String? : null;
                return SenadorDetailScreen(
                  codigo: id,
                  nome: nome,
                );
              },
            ),

            GoRoute(
              path: '/deputados-estaduais-pr',
              builder: (ctx, st) => const DeputadosEstaduaisPrScreen(),
            ),

            GoRoute(
              path: '/tse',
              builder: (ctx, st) => const TseScreen(),
            ),

            GoRoute(path: '/reforma', builder: (ctx, st) => const ReformaTributariaScreen()),
            GoRoute(path: '/reforma/timeline', builder: (ctx, st) => const ReformaTimelineScreen()),
            GoRoute(path: '/normas', builder: (ctx, st) => const NormasScreen()),
            GoRoute(path: '/settings', builder: (ctx, st) => const SettingsScreen()),
            GoRoute(
              path: '/podcast',
              builder: (ctx, st) => const PodcastScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/deadline/:id',
          builder: (ctx, st) => DeadlineScreen(id: st.pathParameters['id']!),
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Contador Plus',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  void _go(BuildContext context, String path) {
    context.go(path);
    Navigator.of(context).maybePop(); // fecha o Drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contador+')),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const ListTile(
                title: Text('Menu'),
                leading: Icon(Icons.menu),
              ),
              const Divider(),
              // Ordem solicitada: 'Inicio', 'Calendario', 'Aprender', 'Deputados Federais', 'Senadores', 'Reforma Tributária', 'Normas', 'Podcast', 'Ajustes', 'Sobre & Fontes'
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Inicio'),
                onTap: () => _go(context, '/'),
              ),
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: const Text('Calendario'),
                onTap: () => _go(context, '/calendar'),
              ),
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Aprender'),
                onTap: () => _go(context, '/learning'),
              ),
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('Deputados Federais'),
                onTap: () => _go(context, '/deputados'),
              ),
              ListTile(
                leading: const Icon(Icons.how_to_vote_outlined),
                title: const Text('Senadores'),
                onTap: () => _go(context, '/senadores'),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_outlined),
                title: const Text('Deputados Estaduais - PR'),
                onTap: () => _go(context, '/deputados-estaduais-pr'),
              ),
              ListTile(
                leading: const Icon(Icons.how_to_vote_outlined),
                title: const Text('TSE'),
                onTap: () => _go(context, '/tse'),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Reforma Tributária'),
                onTap: () => _go(context, '/reforma'),
              ),
              ListTile(
                leading: const Icon(Icons.balance_outlined),
                title: const Text('Normas'),
                onTap: () => _go(context, '/normas'),
              ),
              ListTile(
                leading: const Icon(Icons.podcasts_outlined),
                title: const Text('Podcast'),
                onTap: () => _go(context, '/podcast'),
              ),
              const Divider(),
              // Ajustes sempre por último
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Ajustes'),
                onTap: () => _go(context, '/settings'),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Sobre & Fontes'),
                onTap: () => _go(context, '/sources'),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(child: widget.child),
    );
  }
}
