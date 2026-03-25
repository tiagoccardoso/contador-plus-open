import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Exibe um JSON de forma "bonita" (indentado), com rolagem e botão de copiar.
class PrettyJsonView extends StatelessWidget {
  final dynamic data;
  final double? maxHeight;

  const PrettyJsonView({
    super.key,
    required this.data,
    this.maxHeight,
  });

  String _pretty(dynamic value) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(value);
    } catch (_) {
      return value?.toString() ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _pretty(data);
    final cappedHeight = maxHeight ?? MediaQuery.of(context).size.height * 0.55;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: cappedHeight),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(fontFamily: 'monospace', height: 1.25),
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton(
                tooltip: 'Copiar JSON',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON copiado para a área de transferência')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
