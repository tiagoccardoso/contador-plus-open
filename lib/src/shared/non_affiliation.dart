import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exibe o aviso de não afiliação somente uma vez.
/// Corrige o fechamento do diálogo usando o *contexto do builder* e
/// evita múltiplas aberturas simultâneas que deixam a tela escura.
class NonAffiliationNotice {
  static const _k = 'non_affiliation_seen';
  static bool _showing = false; // reentrância/duplicidade

  /// Agende para rodar após o primeiro frame (use no initState da Home).
  static void scheduleOnce(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _showIfNeeded(context);
    });
  }

  static Future<void> _showIfNeeded(BuildContext context) async {
    if (_showing) return; // já exibindo em outro ponto

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_k) ?? false;
    if (seen) return;
    if (!context.mounted) return;

    _showing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Aviso'),
          content: const Text(
            'Este aplicativo é independente e não representa, não endossa e '
            'não possui qualquer afiliação com órgãos governamentais. '
            'Sempre confirme nos links oficiais indicados.'
          ),
          actions: [
            TextButton(
              // fecha usando o contexto do builder do diálogo
              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );

      // Marca como visto após o fechamento bem-sucedido
      await prefs.setBool(_k, true);
    } finally {
      _showing = false;
    }
  }
}
