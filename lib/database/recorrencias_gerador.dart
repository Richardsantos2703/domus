import 'package:domus/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class RecorrenciasGerador {
  // Gera as contas que já deveriam existir e as que vencem
  // nos próximos 7 dias.
  Future<int> gerarContas({DateTime? hoje}) async {
    final db = await DatabaseHelper.instance.database;

    final dataAtual = _normalizarData(hoje ?? DateTime.now());
    final limite = dataAtual.add(const Duration(days: 7));

    return await db.transaction((txn) async {
      final recorrencias = await txn.query(
        'recorrencias',
        where: 'ativa = ?',
        whereArgs: [1],
      );

      var quantidadeGerada = 0;

      for (final recorrencia in recorrencias) {
        final recorrenciaId = recorrencia['id'] as int;

        // Busca a primeira conta vinculada à recorrência.
        final contasExistentes = await txn.query(
          'contas',
          columns: ['data_vencimento'],
          where: 'recorrencia_id = ?',
          whereArgs: [recorrenciaId],
          orderBy: 'data_vencimento ASC',
          limit: 1,
        );

        // Sem uma conta inicial, não há referência para gerar.
        if (contasExistentes.isEmpty) {
          continue;
        }

        // Usa o primeiro vencimento como referência.
        final primeiraData = _normalizarData(
          DateTime.parse(contasExistentes.first['data_vencimento'] as String),
        );

        final datas = _datasGeracao(
          recorrencia: recorrencia,
          primeiraData: primeiraData,
          limite: limite,
        );

        for (final dataVencimento in datas) {
          final id = await txn.insert('contas', {
            'nome': recorrencia['nome'],
            'valor_total_centavos': recorrencia['valor_previsto_centavos'],
            'categoria_id': recorrencia['categoria_id'],
            'recorrencia_id': recorrenciaId,
            'data_vencimento': _formatarData(dataVencimento),
            'descricao': recorrencia['descricao'],
            'criada_em': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);

          if (id != -1) {
            quantidadeGerada++;
          }
        }
      }

      return quantidadeGerada;
    });
  }

  // Calcula as datas posteriores ao primeiro vencimento.
  List<DateTime> _datasGeracao({
    required Map<String, Object?> recorrencia,
    required DateTime primeiraData,
    required DateTime limite,
  }) {
    final frequencia = recorrencia['frequencia'] as String;
    final dia = (recorrencia['dia_vencimento'] as num).toInt();

    final datas = <DateTime>[];

    if (frequencia == 'mensal') {
      var ano = primeiraData.year;
      var mes = primeiraData.month + 1;

      if (mes > 12) {
        mes = 1;
        ano++;
      }

      while (true) {
        final vencimento = _ultimoDiaDoMes(ano, mes, dia);

        if (vencimento.isAfter(limite)) {
          break;
        }

        datas.add(vencimento);

        mes++;

        if (mes > 12) {
          mes = 1;
          ano++;
        }
      }
    } else if (frequencia == 'anual') {
      final mes = (recorrencia['mes_vencimento'] as num).toInt();

      var ano = primeiraData.year + 1;

      while (true) {
        final vencimento = _ultimoDiaDoMes(ano, mes, dia);

        if (vencimento.isAfter(limite)) {
          break;
        }

        datas.add(vencimento);
        ano++;
      }
    }

    return datas;
  }

  // Ajusta dias inválidos para o último dia do mês.
  // Exemplo: 31 de fevereiro vira 28 ou 29.
  DateTime _ultimoDiaDoMes(int ano, int mes, int dia) {
    final ultimoDia = DateTime(ano, mes + 1, 0).day;

    return DateTime(ano, mes, dia > ultimoDia ? ultimoDia : dia);
  }

  DateTime _normalizarData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  String _formatarData(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');

    return '$ano-$mes-$dia';
  }
}
