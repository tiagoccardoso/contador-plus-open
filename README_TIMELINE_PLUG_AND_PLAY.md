# Linha do Tempo — Reforma Tributária (PRO + IA integrada)

**Pronto para colar** na raiz do projeto. Estrutura incluída:

```
assets/reforma/events.json
lib/router/reforma_timeline_routes.dart
lib/src/features/reforma_timeline/rt_models.dart
lib/src/features/reforma_timeline/rt_repository.dart
lib/src/features/reforma_timeline/rt_providers.dart
lib/src/features/reforma_timeline/rt_ai.dart
lib/src/features/reforma_timeline/rt_widgets.dart
lib/src/features/reforma_timeline/rt_timeline_screen.dart
lib/src/features/reforma_timeline/reforma_timeline_menu_tile.dart
```

## Integração em 3 passos
1. **Assets** (`pubspec.yaml`):
```yaml
flutter:
  assets:
    - assets/reforma/events.json
```
2. **Rotas (GoRouter)** — em `lib/router/app_router.dart`:
```dart
import 'reforma_timeline_routes.dart';
reformaTimelineRoute(),
```
3. **Menu “Reforma Tributária”** — em `lib/src/features/reforma/reforma_screen.dart`:
```dart
import '../reforma_timeline/reforma_timeline_menu_tile.dart';
const ReformaTimelineMenuTile(),
```

A IA usa o **OpenAiService** do app (`lib/src/shared/openai_service.dart`).