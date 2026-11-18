import 'package:domus/database/database_helper.dart';

class ContaComPagamentosException implements Exception {
  @override
  String toString() {
    return 'Esta conta possui pagamentos registrados. '
        'Exclua os pagamentos antes de excluir a conta.';
  }
}

class UltimaContaRecorrenteException implements Exception {
  @override
  String toString() {
    return 'Esta é a última conta vinculada a uma recorrência ativa. '
        'Desative a recorrência antes de excluir esta conta.';
  }
}

class ContasRepository {
  static const String _consultaBase = '''
    SELECT
      c.*,
      cat.nome AS categoria_nome,
      cat.cor AS categoria_cor,

      COALESCE(SUM(p.valor_pago_centavos), 0)
        AS valor_pago_centavos,

      c.valor_total_centavos -
        COALESCE(SUM(p.valor_pago_centavos), 0)
        AS saldo_centavos,

      CASE
        WHEN COALESCE(SUM(p.valor_pago_centavos), 0)
             >= c.valor_total_centavos
          THEN 'paga'

        WHEN c.data_vencimento < date('now', 'localtime')
          THEN 'atrasada'

        WHEN COALESCE(SUM(p.valor_pago_centavos), 0) > 0
          THEN 'parcial'

        ELSE 'pendente'
      END AS status

    FROM contas c

    INNER JOIN categorias cat
      ON cat.id = c.categoria_id

    LEFT JOIN pagamentos p
      ON p.conta_id = c.id
  ''';

  // Cadastra uma nova conta.
  Future<int> adicionar(Map<String, Object?> dados) async {
    final db = await DatabaseHelper.instance.database;

    return await db.insert('contas', dados);
  }

  // Lista todas as contas com seus pagamentos e situação atual.
  Future<List<Map<String, Object?>>> listar() async {
    final db = await DatabaseHelper.instance.database;

    return await db.rawQuery('''
      $_consultaBase

      GROUP BY c.id

      ORDER BY
        CASE status
          WHEN 'atrasada' THEN 0
          WHEN 'pendente' THEN 1
          WHEN 'parcial' THEN 1
          WHEN 'paga' THEN 2
        END,

        c.data_vencimento ASC
    ''');
  }

  // Lista todas as contas com vencimento no mês selecionado.
  // Inclui o total pago até o momento, mesmo que o pagamento
  // tenha sido realizado depois do mês de vencimento.
  Future<List<Map<String, Object?>>> listarPorMes({
    DateTime? referencia,
  }) async {
    final db = await DatabaseHelper.instance.database;

    final mes = referencia ?? DateTime.now();
    final inicioMes = DateTime(mes.year, mes.month, 1);
    final inicioProximoMes = DateTime(mes.year, mes.month + 1, 1);

    String formatarData(DateTime data) {
      final ano = data.year.toString().padLeft(4, '0');
      final numeroMes = data.month.toString().padLeft(2, '0');
      final dia = data.day.toString().padLeft(2, '0');

      return '$ano-$numeroMes-$dia';
    }

    return await db.rawQuery(
      '''
      $_consultaBase

      WHERE
        c.data_vencimento >= ?
        AND c.data_vencimento < ?

      GROUP BY c.id

      ORDER BY
        c.data_vencimento ASC,
        c.id ASC
      ''',
      [formatarData(inicioMes), formatarData(inicioProximoMes)],
    );
  }

  // Retorna os valores e as quantidades para o resumo mensal.
  Future<Map<String, Object?>> resumoMes({DateTime? referencia}) async {
    final db = await DatabaseHelper.instance.database;

    final mes = referencia ?? DateTime.now();

    final inicioMes = DateTime(mes.year, mes.month, 1);
    final inicioProximoMes = DateTime(mes.year, mes.month + 1, 1);

    final hoje = DateTime.now();

    String formatarData(DateTime data) {
      final ano = data.year.toString().padLeft(4, '0');
      final numeroMes = data.month.toString().padLeft(2, '0');
      final dia = data.day.toString().padLeft(2, '0');

      return '$ano-$numeroMes-$dia';
    }

    final resultado = await db.rawQuery(
      '''
      WITH contas_mes AS (
        SELECT
          c.id,
          c.valor_total_centavos,
          c.data_vencimento,

          COALESCE(SUM(p.valor_pago_centavos), 0)
            AS valor_pago_centavos

        FROM contas c

        LEFT JOIN pagamentos p
          ON p.conta_id = c.id

        WHERE
          c.data_vencimento >= ?
          AND c.data_vencimento < ?

        GROUP BY c.id
      ),

      contas_status AS (
        SELECT
          *,

          CASE
            WHEN valor_pago_centavos >= valor_total_centavos
              THEN 'paga'

            WHEN data_vencimento < ?
              THEN 'atrasada'

            WHEN valor_pago_centavos > 0
              THEN 'parcial'

            ELSE 'pendente'
          END AS status

        FROM contas_mes
      )

      SELECT
        COALESCE(SUM(valor_total_centavos), 0)
          AS total_mes_centavos,

        COALESCE(SUM(valor_pago_centavos), 0)
          AS total_pago_contas_mes_centavos,

        COALESCE(SUM(
          CASE
            WHEN valor_total_centavos > valor_pago_centavos
              THEN valor_total_centavos - valor_pago_centavos
            ELSE 0
          END
        ), 0) AS saldo_aberto_mes_centavos,

        (
          SELECT COALESCE(SUM(p.valor_pago_centavos), 0)
          FROM pagamentos p
          WHERE
            p.data_pagamento >= ?
            AND p.data_pagamento < ?
        ) AS total_pago_mes_centavos,

        COALESCE(SUM(
          CASE WHEN status = 'pendente' THEN 1 ELSE 0 END
        ), 0) AS quantidade_pendentes,

        COALESCE(SUM(
          CASE WHEN status = 'atrasada' THEN 1 ELSE 0 END
        ), 0) AS quantidade_atrasadas,

        COALESCE(SUM(
          CASE WHEN status = 'parcial' THEN 1 ELSE 0 END
        ), 0) AS quantidade_parciais,

        COALESCE(SUM(
          CASE WHEN status = 'paga' THEN 1 ELSE 0 END
        ), 0) AS quantidade_pagas

      FROM contas_status
      ''',
      [
        formatarData(inicioMes),
        formatarData(inicioProximoMes),
        formatarData(hoje),
        formatarData(inicioMes),
        formatarData(inicioProximoMes),
      ],
    );

    return resultado.first;
  }

  // Busca uma conta específica pelo ID.
  Future<Map<String, Object?>?> buscarPorId(int id) async {
    final db = await DatabaseHelper.instance.database;

    final resultado = await db.rawQuery(
      '''
      $_consultaBase

      WHERE c.id = ?

      GROUP BY c.id

      LIMIT 1
      ''',
      [id],
    );

    if (resultado.isEmpty) {
      return null;
    }

    return resultado.first;
  }

  // Atualiza os dados de uma conta.
  Future<int> atualizar(int id, Map<String, Object?> dados) async {
    final db = await DatabaseHelper.instance.database;

    return await db.update('contas', dados, where: 'id = ?', whereArgs: [id]);
  }

  // Exclui uma conta respeitando as regras de pagamentos e recorrências.
  Future<int> excluir(int id) async {
    final db = await DatabaseHelper.instance.database;

    return await db.transaction<int>((txn) async {
      // Verifica se a conta existe e obtém sua recorrência.
      final contasEncontradas = await txn.query(
        'contas',
        columns: ['recorrencia_id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (contasEncontradas.isEmpty) {
        return 0;
      }

      // Impede excluir contas que possuem pagamentos registrados.
      final pagamentosEncontrados = await txn.query(
        'pagamentos',
        columns: ['id'],
        where: 'conta_id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (pagamentosEncontrados.isNotEmpty) {
        throw ContaComPagamentosException();
      }

      final recorrenciaId = contasEncontradas.first['recorrencia_id'] as int?;

      if (recorrenciaId != null) {
        // Verifica se a recorrência está ativa.
        final recorrenciasEncontradas = await txn.query(
          'recorrencias',
          columns: ['ativa'],
          where: 'id = ?',
          whereArgs: [recorrenciaId],
          limit: 1,
        );

        if (recorrenciasEncontradas.isNotEmpty) {
          final ativa =
              (recorrenciasEncontradas.first['ativa'] as num).toInt() == 1;

          if (ativa) {
            // Conta quantas contas ainda estão vinculadas.
            final resultado = await txn.rawQuery(
              '''
              SELECT COUNT(*) AS total
              FROM contas
              WHERE recorrencia_id = ?
              ''',
              [recorrenciaId],
            );

            final quantidade = (resultado.first['total'] as num).toInt();

            // Não permite excluir a última conta da recorrência ativa.
            if (quantidade <= 1) {
              throw UltimaContaRecorrenteException();
            }
          }
        }
      }

      return await txn.delete('contas', where: 'id = ?', whereArgs: [id]);
    });
  }
}
