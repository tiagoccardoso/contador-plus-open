
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Ignora qualquer deep link com esquema `contadorplus://` (retorno do OAuth)
/// e redireciona para a rota inicial, evitando "Page Not Found".
String? authDeepLinkGuard(BuildContext context, GoRouterState state) {
  final uri = state.uri; // go_router >= 10
  if (uri.scheme == 'contadorplus') {
    return '/';
  }
  return null;
}

/// Rota sumidouro para `/auth/callback` (nada a renderizar).
class AuthCallbackPage extends StatelessWidget {
  const AuthCallbackPage({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
