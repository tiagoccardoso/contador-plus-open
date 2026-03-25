import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'open_link.dart';

/// Compartilha [text] abrindo o WhatsApp quando possível.
/// 
/// Estratégia:
/// 1) Tenta deep link `whatsapp://send?text=...` (abre direto o app)
/// 2) Se falhar, tenta `https://wa.me/?text=...`
/// 3) Se falhar (web/desktop/sem WhatsApp), cai no share sheet do sistema
Future<void> shareToWhatsApp(BuildContext context, String text) async {
  final encoded = Uri.encodeComponent(text);

  final candidates = <Uri>[
    Uri.parse('whatsapp://send?text=$encoded'),
    Uri.parse('https://wa.me/?text=$encoded'),
  ];

  for (final uri in candidates) {
    try {
      await openExternal(uri);
      return;
    } catch (_) {
      // tenta a próxima opção
    }
  }

  // Fallback: compartilhamento padrão do sistema (usuário escolhe o app).
  try {
    await Share.share(text);
    return;
  } catch (_) {}

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Não foi possível abrir o WhatsApp para compartilhar.')),
  );
}
