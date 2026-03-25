Melhorias aplicadas:
- Botão **Atualizar agora** (ignora cache) no AppBar do detalhe e nas abas Proposições/Votações/Despesas.
- **Exportar CSV** das despesas do ano (gera arquivo e abre compartilhamento).
- **Gráfico de pizza** por categoria de despesa (top 6 + Outros) e seção **Top fornecedores**.
- Mantidos favoritos e cache local.

Passos:
1) Copie estes arquivos para o projeto (sobrescrevendo os existentes):
   - lib/src/shared/camara/cached_camara_api.dart
   - lib/src/features/deputados/deputado_detail_screen.dart
2) No `pubspec.yaml`, confirme:
dependencies:
  share_plus: ^8.0.3
  path_provider: ^2.1.3
  fl_chart: ^0.66.2
  intl: ^0.19.0
  http: ^1.2.2
  url_launcher: ^6.3.0
  hooks_riverpod: ^2.5.1
3) `flutter pub get` e rodar.
