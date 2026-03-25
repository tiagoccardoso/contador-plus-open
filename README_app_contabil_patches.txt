App Contabil — Patches integrados (2025-10-15 12:37:05)

Arquivos substituídos neste pacote:
- /mnt/data/lib_extracted/lib/src/shared/camara/camara_api_client.dart
- /mnt/data/lib_extracted/lib/src/shared/camara/cached_camara_api.dart
- /mnt/data/lib_extracted/lib/src/features/deputados/deputado_detail_screen.dart

Observações:
- Se algum arquivo esperado não foi encontrado no seu lib.zip, ele consta abaixo.
  Você pode copiar manualmente a partir de /mnt/data (verdownloads anexos no chat):
  (n/a)

Dependências necessárias no pubspec.yaml (adicione/atualize):
  dependencies:
    url_launcher: ^6.3.0
    shared_preferences: ^2.2.0
    intl: any

Android:
  - AndroidManifest.xml: adicione <queries> para intents de http/https se necessário (Android 11+) e verifique permissões de internet.
iOS:
  - Verifique LSApplicationQueriesSchemes para "https" se estiver usando canOpenURL em URLs externas.

Dicas de teste rápido:
- Tela "Deputado": validar abas Perfil/Proposições/Votações/Despesas/Discursos.
- Votações: abrir configurações (ícone no AppBar), alterar "Buscar por mês" e "Limite/ano" e recarregar.
- Compartilhar: botão de compartilhar no AppBar → WhatsApp com perfil + proposições + votações + despesas (período selecionado).
- Favoritar: estrela no AppBar (persiste em SharedPreferences).
