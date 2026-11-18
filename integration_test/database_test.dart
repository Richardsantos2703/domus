import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:domus/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Verificar estrutura e regras do banco Domus',
      (tester) async {
    final db = await DatabaseHelper.instance.database;

    // 1. Verifica se as cinco tabelas foram criadas.
    final tabelas = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );

    final nomesTabelas = tabelas.map((t) => t['name']).toList();

    expect(nomesTabelas, contains('categorias'));
    expect(nomesTabelas, contains('recorrencias'));
    expect(nomesTabelas, contains('contas'));
    expect(nomesTabelas, contains('pagamentos'));
    expect(nomesTabelas, contains('configuracoes'));

    // 2. Verifica se as dez categorias padrão foram cadastradas.
    final categorias = await db.query('categorias');

    expect(categorias.length, 10);

    // 3. Verifica se as chaves estrangeiras estão ativadas.
    final foreignKeys = await db.rawQuery('PRAGMA foreign_keys');

    expect(foreignKeys.first['foreign_keys'], 1);

    // 4. Localiza a categoria Moradia.
    final moradia = await db.query(
      'categorias',
      where: 'nome = ?',
      whereArgs: ['Moradia'],
    );

    expect(moradia, isNotEmpty);

    final categoriaId = moradia.first['id'] as int;

    // 5. Cria uma conta temporária para testar os pagamentos.
    final contaId = await db.insert('contas', {
      'nome': 'Conta de teste',
      'valor_total_centavos': 10000,
      'categoria_id': categoriaId,
      'recorrencia_id': null,
      'data_vencimento': '2099-12-31',
      'descricao': 'Registro temporário de teste',
      'criada_em': DateTime.now().toIso8601String(),
    });

    try {
      // 6. Registra um pagamento parcial de R$ 40,00.
      await db.insert('pagamentos', {
        'conta_id': contaId,
        'valor_pago_centavos': 4000,
        'data_pagamento': DateTime.now().toIso8601String(),
        'observacao': 'Pagamento de teste',
      });

      // 7. Confirma que o banco impede pagamentos acima do saldo.
      expect(
        () async {
          await db.insert('pagamentos', {
            'conta_id': contaId,
            'valor_pago_centavos': 7000,
            'data_pagamento': DateTime.now().toIso8601String(),
            'observacao': 'Pagamento inválido',
          });
        },
        throwsA(isA<DatabaseException>()),
      );

      // 8. Confirma que uma conta com pagamento não pode ser excluída.
      expect(
        () async {
          await db.delete(
            'contas',
            where: 'id = ?',
            whereArgs: [contaId],
          );
        },
        throwsA(isA<DatabaseException>()),
      );
    } finally {
      // Remove os registros temporários do teste.
      await db.delete(
        'pagamentos',
        where: 'conta_id = ?',
        whereArgs: [contaId],
      );

      await db.delete(
        'contas',
        where: 'id = ?',
        whereArgs: [contaId],
      );
    }

    // 9. Confirma que uma categoria padrão não pode ser excluída.
    expect(
      () async {
        await db.delete(
          'categorias',
          where: 'id = ?',
          whereArgs: [categoriaId],
        );
      },
      throwsA(isA<DatabaseException>()),
    );
  });
}
