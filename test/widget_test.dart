
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:domus/main.dart';

void main() {
  testWidgets('Domus apresenta carregamento durante inicialização',
      (WidgetTester tester) async {
    final inicializacao = Completer<int>();

    await tester.pumpWidget(
      DomusApp(
        gerarRecorrencias: () => inicializacao.future,
      ),
    );

    final aplicativo = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );

    expect(aplicativo.title, 'Domus');
    expect(find.text('Preparando suas contas...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}