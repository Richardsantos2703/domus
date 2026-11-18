import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:domus/database/contas_repository.dart';
import 'package:domus/database/database_helper.dart';
import 'package:domus/database/pagamentos_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Testar registro, consulta e exclusão de pagamentos', (
    tester,
  ) async {
    final contasRepository = ContasRepository();
    final pagamentosRepository = PagamentosRepository();
    final db = await DatabaseHelper.instance.database;

    // Localiza a categoria Moradia.
    final categorias = await db.query(
      'categorias',
      where: 'nome = ?',
      whereArgs: ['Moradia'],
    );

    expect(categorias, isNotEmpty);

    final categoriaId = categorias.first['id'] as int;

    // Cria uma conta temporária de R$ 150,00.
    final contaId = await contasRepository.adicionar({
      'nome': 'Conta de teste de pagamentos',
      'valor_total_centavos': 15000,
      'categoria_id': categoriaId,
      'recorrencia_id': null,
      'data_vencimento': '2099-12-31',
      'descricao': 'Teste automatizado',
      'criada_em': DateTime.now().toIso8601String(),
    });

    try {
      final hoje = DateTime.now();

      // Registra o primeiro pagamento de R$ 40,00.
      await pagamentosRepository.registrarPagamento(
        contaId: contaId,
        valorCentavos: 4000,
        dataPagamento: hoje,
        observacao: 'Primeiro pagamento',
      );

      expect(await pagamentosRepository.totalPago(contaId), 4000);
      expect(await pagamentosRepository.saldoRestante(contaId), 11000);

      // Registra o segundo pagamento de R$ 60,00.
      await pagamentosRepository.registrarPagamento(
        contaId: contaId,
        valorCentavos: 6000,
        dataPagamento: hoje,
        observacao: 'Segundo pagamento',
      );

      expect(await pagamentosRepository.totalPago(contaId), 10000);
      expect(await pagamentosRepository.saldoRestante(contaId), 5000);

      // Confere o histórico de pagamentos.
      var historico = await pagamentosRepository.listarPorConta(contaId);

      expect(historico.length, 2);

      // Confere a consulta por período.
      final pagamentosDoPeriodo = await pagamentosRepository.listarPorPeriodo(
        inicio: hoje,
        fim: hoje,
      );

      expect(
        pagamentosDoPeriodo.any(
          (pagamento) => pagamento['conta_id'] == contaId,
        ),
        isTrue,
      );

      // Tenta pagar R$ 60,00, mas restam apenas R$ 50,00.
      // O banco deve impedir o pagamento acima do saldo.
      await expectLater(
        pagamentosRepository.registrarPagamento(
          contaId: contaId,
          valorCentavos: 6000,
          dataPagamento: hoje,
        ),
        throwsA(isA<DatabaseException>()),
      );

      // Confirma que o pagamento recusado não foi registrado.
      expect(await pagamentosRepository.totalPago(contaId), 10000);
      expect(await pagamentosRepository.saldoRestante(contaId), 5000);

      // Registra o pagamento final de R$ 50,00.
      await pagamentosRepository.registrarPagamento(
        contaId: contaId,
        valorCentavos: 5000,
        dataPagamento: hoje,
        observacao: 'Quitação da conta',
      );

      expect(await pagamentosRepository.totalPago(contaId), 15000);
      expect(await pagamentosRepository.saldoRestante(contaId), 0);

      // Confirma que a conta está totalmente paga.
      final conta = await contasRepository.buscarPorId(contaId);

      expect(conta, isNotNull);
      expect(conta!['status'], 'paga');
      expect(conta['saldo_centavos'], 0);

      // Não permite excluir uma conta com pagamentos vinculados.
      // Agora o repositório utiliza uma exceção específica.
      await expectLater(
        contasRepository.excluir(contaId),
        throwsA(isA<ContaComPagamentosException>()),
      );

      // Exclui um pagamento e verifica o recálculo do saldo.
      historico = await pagamentosRepository.listarPorConta(contaId);

      await pagamentosRepository.excluirPagamento(historico.first['id'] as int);

      expect(await pagamentosRepository.totalPago(contaId), 10000);
      expect(await pagamentosRepository.saldoRestante(contaId), 5000);
    } finally {
      // Remove os pagamentos temporários antes de excluir a conta.
      final historico = await pagamentosRepository.listarPorConta(contaId);

      for (final pagamento in historico) {
        await pagamentosRepository.excluirPagamento(pagamento['id'] as int);
      }

      await contasRepository.excluir(contaId);
    }

    // Confirma que a conta temporária foi removida.
    final contaExcluida = await contasRepository.buscarPorId(contaId);

    expect(contaExcluida, isNull);
  });
}
