import 'package:flutter/material.dart';

/// Chaves das abas da tela "Deputados Estaduais - PR (ALEP)".
///
/// A ordem aqui precisa acompanhar a ordem do TabBar/TabBarView.
enum AlepTabKey {
  deputados,
  proposicoes,
  normas,
  prestacaoContas,
  campos;

  static AlepTabKey fromTabIndex(int index) {
    if (index <= 0) return AlepTabKey.deputados;
    if (index == 1) return AlepTabKey.proposicoes;
    if (index == 2) return AlepTabKey.normas;
    if (index == 3) return AlepTabKey.prestacaoContas;
    return AlepTabKey.campos;
  }

  String get label {
    switch (this) {
      case AlepTabKey.deputados:
        return 'Deputados';
      case AlepTabKey.proposicoes:
        return 'Proposições';
      case AlepTabKey.normas:
        return 'Normas';
      case AlepTabKey.prestacaoContas:
        return 'Prestação de contas';
      case AlepTabKey.campos:
        return 'Campos';
    }
  }
}

/// Payload simples de compartilhamento (texto já pronto).
class AlepShareData {
  final String title;
  final String text;
  final DateTime updatedAt;

  const AlepShareData({
    required this.title,
    required this.text,
    required this.updatedAt,
  });
}

/// Store para que cada aba "publique" o que deve ser compartilhado.
///
/// Motivo de existir:
/// - O botão de share fica no AppBar (fora das abas).
/// - Cada aba sabe melhor quais dados estão carregados/selecionados.
/// - A tela só precisa perguntar: "qual é a aba ativa?" e pegar o texto pronto.
class AlepShareStore extends ChangeNotifier {
  final Map<AlepTabKey, AlepShareData> _byTab = <AlepTabKey, AlepShareData>{};

  AlepShareData? getFor(AlepTabKey key) => _byTab[key];

  String? textFor(AlepTabKey key) => _byTab[key]?.text;

  /// Atualiza o conteúdo de uma aba. Se não mudou, não notifica.
  void update(AlepTabKey key, String text, {String? title}) {
    final prev = _byTab[key];
    final t = (title ?? prev?.title ?? key.label).trim();
    final nextText = text.trimRight();

    if (prev != null && prev.title == t && prev.text == nextText) return;

    _byTab[key] = AlepShareData(
      title: t,
      text: nextText,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }
}

/// Escopo (InheritedNotifier) para acessar o [AlepShareStore] a partir das abas.
class AlepShareScope extends InheritedNotifier<AlepShareStore> {
  const AlepShareScope({
    super.key,
    required AlepShareStore notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AlepShareStore? maybeOf(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<AlepShareScope>();
    return w?.notifier;
  }

  static AlepShareStore of(BuildContext context) => maybeOf(context)!;
}
