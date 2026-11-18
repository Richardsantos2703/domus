import 'package:domus/database/database_helper.dart';

class PagamentosRepository {
  // Registra um pagamento total ou parcial.
  Future<int> registrarPagamento({
    required int contaId,
    required int valorCentavos,
    required DateTime dataPagamento,
    String? observacao,
  }) async {
    if (valorCentavos <= 0) {
      throw ArgumentError('O valor do pagamento deve ser maior que zero.');
    }

    final db = await DatabaseHelper.instance.database;

    final dataFormatada =
        '${dataPagamento.year.toString().padLeft(4, '0')}-'
        '${dataPagamento.month.toString().padLeft(2, '0')}-'
        '${dataPagamento.day.toString().padLeft(2, '0')}';

    return await db.insert('pagamentos', {
      'conta_id': contaId,
      'valor_pago_centavos': valorCentavos,
      'data_pagamento': dataFormatada,
      'observacao': observacao,
    });
  }

  // Lista o histórico de pagamentos de uma conta.
  Future<List<Map<String, Object?>>> listarPorConta(int contaId) async {
    final db = await DatabaseHelper.instance.database;

    return await db.query(
      'pagamentos',
      where: 'conta_id = ?',
      whereArgs: [contaId],
      orderBy: 'data_pagamento DESC, id DESC',
    );
  }

  // Consulta os pagamentos realizados dentro de um período.
  Future<List<Map<String, Object?>>> listarPorPeriodo({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final db = await DatabaseHelper.instance.database;

    String formatarData(DateTime data) {
      return '${data.year.toString().padLeft(4, '0')}-'
          '${data.month.toString().padLeft(2, '0')}-'
          '${data.day.toString().padLeft(2, '0')}';
    }

    return await db.rawQuery(
      '''
      SELECT
        p.*,
        c.nome AS conta_nome,
        cat.nome AS categoria_nome

      FROM pagamentos p

      INNER JOIN contas c
        ON c.id = p.conta_id

      INNER JOIN categorias cat
        ON cat.id = c.categoria_id

      WHERE p.data_pagamento BETWEEN ? AND ?

      ORDER BY p.data_pagamento DESC, p.id DESC
    ''',
      [formatarData(inicio), formatarData(fim)],
    );
  }

  // Calcula quanto já foi pago em uma conta.
  Future<int> totalPago(int contaId) async {
    final db = await DatabaseHelper.instance.database;

    final resultado = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(valor_pago_centavos), 0)
        AS total
      FROM pagamentos
      WHERE conta_id = ?
    ''',
      [contaId],
    );

    return resultado.first['total'] as int;
  }

  // Calcula o saldo restante de uma conta.
  Future<int?> saldoRestante(int contaId) async {
    final db = await DatabaseHelper.instance.database;

    final resultado = await db.rawQuery(
      '''
      SELECT
        c.valor_total_centavos -
        COALESCE(SUM(p.valor_pago_centavos), 0)
        AS saldo

      FROM contas c

      LEFT JOIN pagamentos p
        ON p.conta_id = c.id

      WHERE c.id = ?

      GROUP BY c.id
    ''',
      [contaId],
    );

    if (resultado.isEmpty) {
      return null;
    }

    return resultado.first['saldo'] as int;
  }

  // Exclui um pagamento do histórico.
  Future<int> excluirPagamento(int pagamentoId) async {
    final db = await DatabaseHelper.instance.database;

    return await db.delete(
      'pagamentos',
      where: 'id = ?',
      whereArgs: [pagamentoId],
    );
  }
}
