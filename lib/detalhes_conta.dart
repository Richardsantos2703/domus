import 'package:flutter/material.dart';

import 'database/contas_repository.dart';
import 'database/pagamentos_repository.dart';
import 'editar_conta.dart';

class TelaDetalhesConta extends StatefulWidget {
  final int contaId;
  final String nome;
  final String valor;
  final String vencimento;
  final String status;
  final String recorrencia;

  const TelaDetalhesConta({
    super.key,
    required this.contaId,
    required this.nome,
    required this.valor,
    required this.vencimento,
    required this.status,
    required this.recorrencia,
  });

  @override
  State<TelaDetalhesConta> createState() => _TelaDetalhesContaState();
}

class _TelaDetalhesContaState extends State<TelaDetalhesConta> {
  final ContasRepository _contasRepository = ContasRepository();
  final PagamentosRepository _pagamentosRepository = PagamentosRepository();
  final TextEditingController _pagamentoController = TextEditingController();

  Map<String, Object?>? conta;
  List<Map<String, Object?>> pagamentos = [];

  bool carregando = true;
  String? erro;

  static const Color azul = Color(0xFF2563EB);
  static const Color fundo = Color(0xFFF5F7FB);
  static const Color textoPrincipal = Color(0xFF1E293B);
  static const Color textoSecundario = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  @override
  void dispose() {
    _pagamentoController.dispose();
    super.dispose();
  }

  Future<void> carregarDados() async {
    try {
      final resultadoConta = await _contasRepository.buscarPorId(
        widget.contaId,
      );

      final resultadoPagamentos = await _pagamentosRepository.listarPorConta(
        widget.contaId,
      );

      if (!mounted) return;

      setState(() {
        conta = resultadoConta;
        pagamentos = resultadoPagamentos;
        carregando = false;
        erro = resultadoConta == null ? 'Conta não encontrada.' : null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
        erro = 'Erro ao carregar os dados: $e';
      });
    }
  }

  Future<void> _editarConta() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TelaEditarConta(contaId: widget.contaId),
      ),
    );

    if (!mounted) return;

    if (resultado == true) {
      setState(() {
        carregando = true;
      });

      await carregarDados();
    }
  }

  Future<void> _excluirConta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir conta'),
          content: const Text(
            'Tem certeza de que deseja excluir esta conta? '
            'Essa ação não poderá ser desfeita. '
            'Contas com pagamentos registrados não podem ser excluídas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmar != true) return;

    try {
      final resultado = await _contasRepository.excluir(widget.contaId);

      if (!mounted) return;

      if (resultado > 0) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A conta não foi encontrada.')),
        );
      }
    } on ContaComPagamentosException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esta conta possui pagamentos registrados. '
            'Exclua os pagamentos antes de excluir a conta.',
          ),
        ),
      );
    } on UltimaContaRecorrenteException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esta é a última conta vinculada a uma recorrência ativa. '
            'Desative a recorrência antes de excluir esta conta.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao excluir a conta: $e')));
    }
  }

  String formatarMoeda(Object? valor) {
    final centavos = (valor as num?)?.toInt() ?? 0;
    final reais = (centavos / 100).toStringAsFixed(2);

    return 'R\$ ${reais.replaceAll('.', ',')}';
  }

  String formatarData(String? data) {
    if (data == null || data.isEmpty) return '-';

    final partes = data.split('-');

    if (partes.length != 3) return data;

    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  String nomeStatus(String? status) {
    switch (status) {
      case 'paga':
        return 'Paga';
      case 'atrasada':
        return 'Atrasada';
      case 'parcial':
        return 'Parcial';
      default:
        return 'Pendente';
    }
  }

  Color corStatus(String? status) {
    switch (status) {
      case 'paga':
        return const Color(0xFF16A34A);
      case 'atrasada':
        return const Color(0xFFDC2626);
      case 'parcial':
        return const Color(0xFFD97706);
      default:
        return azul;
    }
  }

  Color fundoStatus(String? status) {
    switch (status) {
      case 'paga':
        return const Color(0xFFDCFCE7);
      case 'atrasada':
        return const Color(0xFFFEE2E2);
      case 'parcial':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFDBEAFE);
    }
  }

  int converterParaCentavos(String valor) {
    String limpo = valor.replaceAll('R\$', '').replaceAll(' ', '').trim();

    if (limpo.isEmpty) {
      throw FormatException('Informe um valor.');
    }

    final temPonto = limpo.contains('.');
    final temVirgula = limpo.contains(',');

    String parteInteira;
    String parteDecimal = '';

    if (temPonto && temVirgula) {
      final ultimoPonto = limpo.lastIndexOf('.');
      final ultimaVirgula = limpo.lastIndexOf(',');

      final separadorDecimal = ultimoPonto > ultimaVirgula ? '.' : ',';
      final posicaoDecimal = limpo.lastIndexOf(separadorDecimal);

      parteInteira = limpo
          .substring(0, posicaoDecimal)
          .replaceAll('.', '')
          .replaceAll(',', '');

      parteDecimal = limpo.substring(posicaoDecimal + 1);
    } else if (temPonto || temVirgula) {
      final separador = temPonto ? '.' : ',';
      final partes = limpo.split(separador);

      if (partes.length == 2 && partes[1].isNotEmpty && partes[1].length <= 2) {
        parteInteira = partes[0];
        parteDecimal = partes[1];
      } else {
        parteInteira = limpo.replaceAll(separador, '');
      }
    } else {
      parteInteira = limpo;
    }

    if (parteInteira.isEmpty) {
      parteInteira = '0';
    }

    if (!RegExp(r'^\d+$').hasMatch(parteInteira) ||
        (parteDecimal.isNotEmpty &&
            !RegExp(r'^\d{1,2}$').hasMatch(parteDecimal))) {
      throw FormatException('Valor inválido.');
    }

    final reais = int.parse(parteInteira);
    final centavos = int.parse(parteDecimal.padRight(2, '0'));

    return reais * 100 + centavos;
  }

  Future<void> abrirDialogPagamento() async {
    _pagamentoController.clear();

    final valorInformado = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Registrar pagamento'),
          content: TextField(
            controller: _pagamentoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor pago',
              prefixText: 'R\$ ',
              hintText: '0,00',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, _pagamentoController.text);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (valorInformado == null || valorInformado.trim().isEmpty) {
      return;
    }

    try {
      final valorCentavos = converterParaCentavos(valorInformado);

      if (valorCentavos <= 0) {
        throw Exception('Informe um valor maior que zero.');
      }

      await _pagamentosRepository.registrarPagamento(
        contaId: widget.contaId,
        valorCentavos: valorCentavos,
        dataPagamento: DateTime.now(),
      );

      await carregarDados();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pagamento registrado com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível registrar: $e')));
    }
  }

  Future<void> excluirPagamento(int pagamentoId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir pagamento'),
          content: const Text('Deseja realmente excluir este pagamento?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmar != true) return;

    try {
      await _pagamentosRepository.excluirPagamento(pagamentoId);

      await carregarDados();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pagamento excluído.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao excluir pagamento: $e')));
    }
  }

  Widget construirIndicadorRecorrente() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        border: Border.all(color: const Color(0xFFD7E3F8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, color: azul, size: 14),
          SizedBox(width: 5),
          Text(
            'Recorrente',
            style: TextStyle(
              color: azul,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget construirEtiquetaStatus(String? status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: fundoStatus(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        nomeStatus(status),
        style: TextStyle(
          color: corStatus(status),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget construirCardPrincipal({
    required String nome,
    required String? status,
    required Object? valorTotal,
    required Object? valorPago,
    required Object? saldo,
    required bool recorrente,
    required bool pagamentoParcialAtrasado,
  }) {
    final totalCentavos = (valorTotal as num?)?.toInt() ?? 0;
    final pagoCentavos = (valorPago as num?)?.toInt() ?? 0;

    final progresso = totalCentavos > 0
        ? (pagoCentavos / totalCentavos).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: azul.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nome,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              construirEtiquetaStatus(status),
              if (recorrente) construirIndicadorRecorrente(),
            ],
          ),
          if (pagamentoParcialAtrasado) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Pagamento parcial: ${formatarMoeda(valorPago)} já pago.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'VALOR TOTAL',
            style: TextStyle(
              color: Color(0xFFDCEAFE),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            formatarMoeda(valorTotal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progresso do pagamento',
                style: TextStyle(color: Color(0xFFDCEAFE), fontSize: 12),
              ),
              Text(
                '${(progresso * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InformacaoValor(
                  titulo: 'Já pago',
                  valor: formatarMoeda(valorPago),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InformacaoValor(
                  titulo: 'Saldo restante',
                  valor: formatarMoeda(saldo),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget construirSecaoTitulo(String titulo, String subtitulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: textoPrincipal,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitulo,
            style: const TextStyle(color: textoSecundario, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget construirInformacao({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icone, color: azul, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(color: textoSecundario, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  valor,
                  style: const TextStyle(
                    color: textoPrincipal,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget construirHistorico() {
    if (pagamentos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: textoSecundario,
                  size: 25,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nenhum pagamento registrado',
                style: TextStyle(
                  color: textoPrincipal,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Os pagamentos realizados aparecerão aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textoSecundario, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: pagamentos.map((pagamento) {
        final id = pagamento['id'] as int;
        final valor = pagamento['valor_pago_centavos'];
        final data = pagamento['data_pagamento'] as String?;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF16A34A),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatarMoeda(valor),
                      style: const TextStyle(
                        color: textoPrincipal,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatarData(data),
                      style: const TextStyle(
                        color: textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Excluir pagamento',
                onPressed: () => excluirPagamento(id),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFDC2626),
                  size: 21,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget construirBotaoAcao({
    required String texto,
    required IconData icone,
    required VoidCallback aoPressionar,
    bool principal = false,
    bool perigo = false,
  }) {
    if (principal) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: aoPressionar,
          icon: Icon(icone),
          label: Text(texto),
          style: ElevatedButton.styleFrom(
            backgroundColor: azul,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: aoPressionar,
        icon: Icon(icone, size: 19),
        label: Text(texto),
        style: OutlinedButton.styleFrom(
          foregroundColor: perigo ? const Color(0xFFDC2626) : textoPrincipal,
          side: BorderSide(
            color: perigo ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget construirCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return Scaffold(
        backgroundColor: fundo,
        appBar: AppBar(
          title: const Text('Detalhes da conta'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (erro != null || conta == null) {
      return Scaffold(
        backgroundColor: fundo,
        appBar: AppBar(
          title: const Text('Detalhes da conta'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFDC2626),
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  erro ?? 'Conta não encontrada.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textoSecundario),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      carregando = true;
                      erro = null;
                    });
                    carregarDados();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final status = conta!['status'] as String?;
    final valorTotal = conta!['valor_total_centavos'];
    final valorPago = conta!['valor_pago_centavos'];
    final saldo = conta!['saldo_centavos'];

    final categoria = conta!['categoria_nome'] as String? ?? 'Outros';
    final descricao = conta!['descricao'] as String? ?? '';
    final nomeConta = conta!['nome'] as String? ?? 'Conta';
    final dataVencimento = conta!['data_vencimento'] as String?;
    final recorrente = conta!['recorrencia_id'] != null;

    final valorPagoCentavos = (valorPago as num?)?.toInt() ?? 0;
    final saldoCentavos = (saldo as num?)?.toInt() ?? 0;

    final pagamentoParcialAtrasado =
        status == 'atrasada' && valorPagoCentavos > 0 && saldoCentavos > 0;

    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        title: const Text(
          'Detalhes da conta',
          style: TextStyle(
            color: textoPrincipal,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: carregarDados,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            construirCardPrincipal(
              nome: nomeConta,
              status: status,
              valorTotal: valorTotal,
              valorPago: valorPago,
              saldo: saldo,
              recorrente: recorrente,
              pagamentoParcialAtrasado: pagamentoParcialAtrasado,
            ),
            const SizedBox(height: 24),

            construirSecaoTitulo(
              'Informações da conta',
              'Confira os dados cadastrados.',
            ),
            construirCard(
              child: Column(
                children: [
                  construirInformacao(
                    icone: Icons.category_outlined,
                    titulo: 'Categoria',
                    valor: categoria,
                  ),
                  const Divider(height: 1, color: Color(0xFFEDF0F5)),
                  construirInformacao(
                    icone: Icons.calendar_today_outlined,
                    titulo: 'Vencimento',
                    valor: formatarData(dataVencimento),
                  ),
                  const Divider(height: 1, color: Color(0xFFEDF0F5)),
                  construirInformacao(
                    icone: Icons.repeat_rounded,
                    titulo: 'Recorrência',
                    valor: widget.recorrencia,
                  ),
                  if (descricao.isNotEmpty) ...[
                    const Divider(height: 1, color: Color(0xFFEDF0F5)),
                    construirInformacao(
                      icone: Icons.notes_rounded,
                      titulo: 'Descrição',
                      valor: descricao,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            construirSecaoTitulo(
              'Ações da conta',
              'Gerencie esta conta ou registre um pagamento.',
            ),
            construirCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  if (saldoCentavos > 0) ...[
                    construirBotaoAcao(
                      texto: 'Registrar pagamento',
                      icone: Icons.add_card_rounded,
                      aoPressionar: abrirDialogPagamento,
                      principal: true,
                    ),
                    const SizedBox(height: 10),
                  ],
                  construirBotaoAcao(
                    texto: 'Editar conta',
                    icone: Icons.edit_outlined,
                    aoPressionar: _editarConta,
                  ),
                  const SizedBox(height: 10),
                  construirBotaoAcao(
                    texto: 'Excluir conta',
                    icone: Icons.delete_outline,
                    aoPressionar: _excluirConta,
                    perigo: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            construirSecaoTitulo(
              'Histórico de pagamentos',
              'Acompanhe os pagamentos registrados nesta conta.',
            ),
            construirCard(child: construirHistorico()),
          ],
        ),
      ),
    );
  }
}

class _InformacaoValor extends StatelessWidget {
  final String titulo;
  final String valor;

  const _InformacaoValor({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(color: Color(0xFFDCEAFE), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
