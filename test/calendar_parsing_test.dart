import 'package:flutter_test/flutter_test.dart';
import 'package:contador_plus/src/shared/calendar_service.dart';

void main() {
  test('parse obrigacoes.json', () async {
    final svc = CalendarService();
    final payload = await svc.load();
    expect(payload.itens.isNotEmpty, true);
    final dctf = payload.itens.firstWhere((e) => e.sigla == 'DCTFWeb');
    expect(dctf.dataVencimento.year, 2025);
  });
}
