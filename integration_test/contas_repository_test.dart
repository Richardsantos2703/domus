import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:domus/database/contas_repository.dart';
import 'package:domus/database/database_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Testar cadastro, consulta, atualização e exclusão', (
    tester,
  ) async {
    final repository = ContasRepository();
    final db = await DatabaseHelper.instance.database;

    final categorias = await db.query(
      'categorias',
      where: 'nome = ?',
      whereArgs: ['Moradia'],
    );

    expect(categorias, isNotEmpty);

    final categoriaId = categorias.first['id'] as int;

    final contaId = await repository.adicionar({
      'nome': 'Conta de teste do repositório',
      'valor_total_centavos': 15000,
      'categoria_id': categoriaId,
      'recorrencia_id': null,
      'data_vencimento': '2099-12-31',
      'descricao': 'Teste automatizado',
      'criada_em': DateTime.now().toIso8601String(),
    });

    try {
      var conta = await repository.buscarPorId(contaId);

      expect(conta, isNotNull);
      expect(conta!['nome'], 'Conta de teste do repositório');
      expect(conta['valor_total_centavos'], 15000);
      expect(conta['valor_pago_centavos'], 0);
      expect(conta['saldo_centavos'], 15000);
      expect(conta['status'], 'pendente');

      final contas = await repository.listar();

      expect(contas.any((item) => item['id'] == contaId), isTrue);

      await repository.atualizar(contaId, {'nome': 'Conta atualizada'});

      conta = await repository.buscarPorId(contaId);

      expect(conta!['nome'], 'Conta atualizada');
    } finally {
      await repository.excluir(contaId);
    }

    final contaExcluida = await repository.buscarPorId(contaId);

    expect(contaExcluida, isNull);
  });

  testWidgets('Testar resumo mensal das contas', (tester) async {
    final repository = ContasRepository();
    final db = await DatabaseHelper.instance.database;

    final categorias = await db.query(
      'categorias',
      where: 'nome = ?',
      whereArgs: ['Moradia'],
    );

    expect(categorias, isNotEmpty);

    final categoriaId = categorias.first['id'] as int;

    // Utiliza um mês futuro para manter os testes independentes
    // da data em que forem executados.
    final referencia = DateTime(2099, 5, 15);

    final contasCriadas = <int>[];

    Future<int> criarConta({
      required String nome,
      required int valor,
      required String vencimento,
    }) async {
      final id = await repository.adicionar({
        'nome': nome,
        'valor_total_centavos': valor,
        'categoria_id': categoriaId,
        'recorrencia_id': null,
        'data_vencimento': vencimento,
        'descricao': 'Teste do resumo mensal',
        'criada_em': DateTime.now().toIso8601String(),
      });

      contasCriadas.add(id);
      return id;
    }

    try {
      await criarConta(
        nome: 'Teste pendente',
        valor: 10000,
        vencimento: '2099-05-20',
      );

      await criarConta(
        nome: 'Teste segunda conta pendente',
        valor: 20000,
        vencimento: '2099-05-10',
      );

      final contaParcial = await criarConta(
        nome: 'Teste parcial',
        valor: 30000,
        vencimento: '2099-05-25',
      );

      await db.insert('pagamentos', {
        'conta_id': contaParcial,
        'valor_pago_centavos': 5000,
        'data_pagamento': '2099-05-12',
        'observacao': 'Pagamento parcial de teste',
      });

      final contaPaga = await criarConta(
        nome: 'Teste paga',
        valor: 40000,
        vencimento: '2099-05-05',
      );

      await db.insert('pagamentos', {
        'conta_id': contaPaga,
        'valor_pago_centavos': 40000,
        'data_pagamento': '2099-05-06',
        'observacao': 'Pagamento total de teste',
      });

      final contaAbril = await criarConta(
        nome: 'Teste conta de abril',
        valor: 7000,
        vencimento: '2099-04-20',
      );

      await db.insert('pagamentos', {
        'conta_id': contaAbril,
        'valor_pago_centavos': 7000,
        'data_pagamento': '2099-05-08',
        'observacao': 'Pagamento em maio de conta de abril',
      });

      // Verifica os indicadores financeiros do resumo.
      final resumo = await repository.resumoMes(referencia: referencia);

      expect(resumo['total_mes_centavos'], 100000);

      // Pagamentos das contas com vencimento em maio.
      expect(resumo['total_pago_contas_mes_centavos'], 45000);

      // Saldo restante das contas com vencimento em maio.
      expect(resumo['saldo_aberto_mes_centavos'], 55000);

      // Movimento financeiro de maio, incluindo a conta de abril.
      expect(resumo['total_pago_mes_centavos'], 52000);

      // Verifica as quantidades por situação atual.
      // As duas contas sem pagamento ainda têm vencimento futuro.
      expect(resumo['quantidade_pendentes'], 2);
      expect(resumo['quantidade_atrasadas'], 0);
      expect(resumo['quantidade_parciais'], 1);
      expect(resumo['quantidade_pagas'], 1);

      // Verifica se a listagem contém somente contas
      // com vencimento no mês selecionado.
      final contasDoMes = await repository.listarPorMes(referencia: referencia);

      expect(contasDoMes.length, 4);

      expect(contasDoMes.any((conta) => conta['id'] == contaAbril), isFalse);

      expect(contasDoMes.any((conta) => conta['id'] == contaParcial), isTrue);

      expect(contasDoMes.any((conta) => conta['id'] == contaPaga), isTrue);

      // Confirma os valores calculados na listagem.
      final contaParcialListada = contasDoMes.firstWhere(
        (conta) => conta['id'] == contaParcial,
      );

      expect(contaParcialListada['valor_pago_centavos'], 5000);
      expect(contaParcialListada['saldo_centavos'], 25000);
      expect(contaParcialListada['status'], 'parcial');
    } finally {
      for (final id in contasCriadas) {
        await db.delete('pagamentos', where: 'conta_id = ?', whereArgs: [id]);
      }

      for (final id in contasCriadas) {
        await repository.excluir(id);
      }
    }
  });

  testWidgets('Proteger a última conta de uma recorrência ativa', (
    tester,
  ) async {
    final repository = ContasRepository();
    final db = await DatabaseHelper.instance.database;

    final categorias = await db.query(
      'categorias',
      where: 'nome = ?',
      whereArgs: ['Moradia'],
    );

    expect(categorias, isNotEmpty);

    final categoriaId = categorias.first['id'] as int;

    final recorrenciasCriadas = <int>[];
    final contasCriadas = <int>[];

    Future<int> criarRecorrencia({required bool ativa}) async {
      final id = await db.insert('recorrencias', {
        'nome': 'Recorrência de teste',
        'valor_previsto_centavos': 15000,
        'categoria_id': categoriaId,
        'frequencia': 'mensal',
        'dia_vencimento': 10,
        'mes_vencimento': null,
        'descricao': 'Teste automatizado',
        'ativa': ativa ? 1 : 0,
        'criada_em': DateTime.now().toIso8601String(),
      });

      recorrenciasCriadas.add(id);
      return id;
    }

    Future<int> criarContaRecorrente({
      required int recorrenciaId,
      required String vencimento,
    }) async {
      final id = await repository.adicionar({
        'nome': 'Conta recorrente de teste',
        'valor_total_centavos': 15000,
        'categoria_id': categoriaId,
        'recorrencia_id': recorrenciaId,
        'data_vencimento': vencimento,
        'descricao': 'Teste automatizado',
        'criada_em': DateTime.now().toIso8601String(),
      });

      contasCriadas.add(id);
      return id;
    }

    try {
      // Caso 1: a última conta de uma recorrência ativa não pode ser excluída.
      final recorrenciaUnica = await criarRecorrencia(ativa: true);

      final contaUnica = await criarContaRecorrente(
        recorrenciaId: recorrenciaUnica,
        vencimento: '2099-01-10',
      );

      await expectLater(
        repository.excluir(contaUnica),
        throwsA(isA<UltimaContaRecorrenteException>()),
      );

      expect(await repository.buscarPorId(contaUnica), isNotNull);

      // Caso 2: pode excluir uma conta se ainda houver outra vinculada.
      final recorrenciaDupla = await criarRecorrencia(ativa: true);

      final primeiraConta = await criarContaRecorrente(
        recorrenciaId: recorrenciaDupla,
        vencimento: '2099-02-10',
      );

      final segundaConta = await criarContaRecorrente(
        recorrenciaId: recorrenciaDupla,
        vencimento: '2099-03-10',
      );

      expect(await repository.excluir(primeiraConta), 1);

      contasCriadas.remove(primeiraConta);

      expect(await repository.buscarPorId(primeiraConta), isNull);

      // Depois da exclusão, a segunda passa a ser a última.
      await expectLater(
        repository.excluir(segundaConta),
        throwsA(isA<UltimaContaRecorrenteException>()),
      );

      expect(await repository.buscarPorId(segundaConta), isNotNull);

      // Caso 3: recorrência inativa permite excluir sua última conta.
      final recorrenciaInativa = await criarRecorrencia(ativa: false);

      final contaInativa = await criarContaRecorrente(
        recorrenciaId: recorrenciaInativa,
        vencimento: '2099-04-10',
      );

      expect(await repository.excluir(contaInativa), 1);

      contasCriadas.remove(contaInativa);

      expect(await repository.buscarPorId(contaInativa), isNull);
    } finally {
      // Limpa as contas restantes.
      for (final id in contasCriadas) {
        await db.delete('contas', where: 'id = ?', whereArgs: [id]);
      }

      // Limpa as recorrências criadas pelo teste.
      for (final id in recorrenciasCriadas) {
        await db.delete('recorrencias', where: 'id = ?', whereArgs: [id]);
      }
    }
  });
}