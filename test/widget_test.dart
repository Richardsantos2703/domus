import 'package:flutter_test/flutter_test.dart';

import 'package:domus/main.dart';

void main() {
  testWidgets('Domus inicia corretamente', (WidgetTester tester) async {
    await tester.pumpWidget(const DomusApp());

    expect(find.text('Domus'), findsOneWidget);
    expect(find.text('Controle suas contas'), findsOneWidget);
    expect(find.text('Total do mês'), findsOneWidget);
    expect(find.text('Próximas contas'), findsOneWidget);
  });
}