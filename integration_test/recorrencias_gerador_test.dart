
import 'package:domus/database/database_helper.dart';
import 'package:domus/database/recorrencias_gerador.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUp(() async {
    db = await DatabaseHelper.instance.database;
  });

  test('gera uma conta mensal dentro dos próximos 7 dias', () async {
    final id = await criarRecorrencia(
      db,
      nome: 'Teste mensal',
      frequencia: 'mensal',
      dia: 10,
      criadaEm: DateTime(2026, 3, 1),
      primeiroVencimento: DateTime(2026, 3, 10),
    );

    try {
      final quantidade = await RecorrenciasGerador().gerarContas(
        hoje: DateTime(2026, 4, 3),
      );

      final contas = await buscarContas(db, id);

      expect(quantidade, 1);
      expect(
        contas.map((c) => c['data_vencimento']).toList(),
        ['2026-03-10', '2026-04-10'],
      );
    } finally {
      await limparRecorrencia(db, id);
    }
  });

  test('gera uma conta anual na data correta', () async {
    final id = await criarRecorrencia(
      db,
      nome: 'Teste anual',
      frequencia: 'anual',
      dia: 15,
      mes: 11,
      criadaEm: DateTime(2025, 11, 1),
      primeiroVencimento: DateTime(2025, 11, 15),
    );

    try {
      final quantidade = await RecorrenciasGerador().gerarContas(
        hoje: DateTime(2026, 11, 8),
      );

      final contas = await buscarContas(db, id);

      expect(quantidade, 1);
      expect(
        contas.map((c) => c['data_vencimento']).toList(),
        ['2025-11-15', '2026-11-15'],
      );
    } finally {
      await limparRecorrencia(db, id);
    }
  });

  test('ajusta o dia 31 para 29 de fevereiro em ano bissexto', () async {
    final id = await criarRecorrencia(
      db,
      nome: 'Teste fevereiro bissexto',
      frequencia: 'mensal',
      dia: 31,
      criadaEm: DateTime(2024, 1, 1),
      primeiroVencimento: DateTime(2024, 1, 31),
    );

    try {
      final quantidade = await RecorrenciasGerador().gerarContas(
        hoje: DateTime(2024, 2, 22),
      );

      final contas = await buscarContas(db, id);

      expect(quantidade, 1);
      expect(
        contas.map((c) => c['data_vencimento']).toList(),
        ['2024-01-31', '2024-02-29'],
      );
    } finally {
      await limparRecorrencia(db, id);
    }
  });

  test('ajusta o dia 31 para 28 de fevereiro em ano comum', () async {
    final id = await criarRecorrencia(
      db,
      nome: 'Teste fevereiro comum',
      frequencia: 'mensal',
      dia: 31,
      criadaEm: DateTime(2025, 1, 1),
      primeiroVencimento: DateTime(2025, 1, 31),
    );

    try {
      final quantidade = await RecorrenciasGerador().gerarContas(
        hoje: DateTime(2025, 2, 21),
      );

      final contas = await buscarContas(db, id);

      expect(quantidade, 1);
      expect(
        contas.map((c) => c['data_vencimento']).toList(),
        ['2025-01-31', '2025-02-28'],
      );
    } finally {
      await limparRecorrencia(db, id);
    }
  });

  test('recupera vencimentos anteriores quando o app ficou fechado',
      () async {
    final id = await criarRecorrencia(
      db,
      nome: 'Teste recuperação',
      frequencia: 'mensal',
      dia: 15,
      criadaEm: DateTime(2026, 1, 1),
      primeiroVencimento: DateTime(2026, 1, 15),
    );

    try {
      final quantidade = await RecorrenciasGerador().gerarContas(
        hoje: DateTime(2026, 3, 20),
      );

      final contas = await buscarContas(db, id);

      expect(quantidade, 2);
      expect(
        contas.map((c) => c['data_vencimento']).toList(),
        ['2026-01-15', '2026-02-15', '2026-03-15'],
      );
    } finally {
      await limparRecorrencia(db, id);
    }
  });

  test('não cria contas duplicadas', () async {
    final id = await criarRecorrencia(
      db,
      nome: 'Teste duplicidade',
      frequencia: 'mensal',
      dia: 10,
      criadaEm: DateTime(2026, 3, 1),
      primeiroVencimento: DateTime(2026, 3, 10),
    );

    try {
      final primeiraExecucao =
          await RecorrenciasGerador().gerarContas(
        hoje: DateTime(2026, 4, 3),
      );

      final segundaExecucao =
          await RecorrenciasGerador().gerarContas(
        hoje: DateTime(2026, 4, 3),
      );

      final contas = await buscarContas(db, id);

      expect(primeiraExecucao, 1);
      expect(segundaExecucao, 0);
      expect(contas.length, 2);
    } finally {
      await limparRecorrencia(db, id);
    }
  });

  test('não gera contas para recorrências desativadas', () async {
    final id = await criarRecorrencia(
      db,
      nome: 'Teste desativada',
      frequencia: 'mensal',
      dia: 10,
      criadaEm: DateTime(2026, 3, 1),
      primeiroVencimento: DateTime(2026, 3, 10),
      ativa: false,
    );

    try {
      final quantidade = await RecorrenciasGerador().gerarContas(
        hoje: DateTime(2026, 4, 3),
      );

      final contas = await buscarContas(db, id);

      expect(quantidade, 0);
      expect(contas.length, 1);
    } finally {
      await limparRecorrencia(db, id);
    }
  });

  test('respeita o primeiro vencimento mesmo quando ele é futuro',
      () async {
    final id = await criarRecorrencia(
      db,
      nome: 'Teste primeiro vencimento futuro',
      frequencia: 'mensal',
      dia: 5,
      criadaEm: DateTime(2026, 11, 16),
      primeiroVencimento: DateTime(2027, 1, 5),
    );

    try {
      final quantidade = await RecorrenciasGerador().gerarContas(
        hoje: DateTime(2026, 11, 16),
      );

      final contas = await buscarContas(db, id);

      expect(quantidade, 0);
      expect(contas.length, 1);
      expect(contas.first['data_vencimento'], '2027-01-05');
    } finally {
      await limparRecorrencia(db, id);
    }
  });
}

Future<int> criarRecorrencia(
  Database db, {
  required String nome,
  required String frequencia,
  required int dia,
  required DateTime criadaEm,
  required DateTime primeiroVencimento,
  int? mes,
  bool ativa = true,
}) async {
  final categorias = await db.query(
    'categorias',
    columns: ['id'],
    limit: 1,
  );

  if (categorias.isEmpty) {
    throw StateError('Nenhuma categoria encontrada no banco.');
  }

  return db.transaction((txn) async {
    final categoriaId = categorias.first['id'] as int;

    final recorrenciaId = await txn.insert('recorrencias', {
      'nome': nome,
      'valor_previsto_centavos': 10000,
      'categoria_id': categoriaId,
      'frequencia': frequencia,
      'dia_vencimento': dia,
      'mes_vencimento': mes,
      'descricao': 'Conta criada pelo teste',
      'ativa': ativa ? 1 : 0,
      'criada_em': criadaEm.toIso8601String(),
    });

    await txn.insert('contas', {
      'nome': nome,
      'valor_total_centavos': 10000,
      'categoria_id': categoriaId,
      'recorrencia_id': recorrenciaId,
      'data_vencimento': formatarData(primeiroVencimento),
      'descricao': 'Primeira conta do teste',
      'criada_em': criadaEm.toIso8601String(),
    });

    return recorrenciaId;
  });
}

Future<List<Map<String, Object?>>> buscarContas(
  Database db,
  int recorrenciaId,
) {
  return db.query(
    'contas',
    where: 'recorrencia_id = ?',
    whereArgs: [recorrenciaId],
    orderBy: 'data_vencimento ASC',
  );
}

Future<void> limparRecorrencia(
  Database db,
  int id,
) async {
  await db.delete(
    'contas',
    where: 'recorrencia_id = ?',
    whereArgs: [id],
  );

  await db.delete(
    'recorrencias',
    where: 'id = ?',
    whereArgs: [id],
  );
}

String formatarData(DateTime data) {
  final ano = data.year.toString().padLeft(4, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');

  return '$ano-$mes-$dia';
}