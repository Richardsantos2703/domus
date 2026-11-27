
import 'package:flutter/material.dart';

import 'database/contas_repository.dart';
import 'adicionar_conta.dart';
import 'detalhes_conta.dart';

class TelaContas extends StatefulWidget {
  const TelaContas({super.key});

  @override
  State<TelaContas> createState() => _TelaContasState();
}

class _TelaContasState extends State<TelaContas> {
  final ContasRepository _repository = ContasRepository();

  List<Map<String, Object?>> contas = [];

  bool carregando = true;
  String? erro;
  String filtroSelecionado = 'Todas';

  static const Color azulPrincipal = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    carregarContas();
  }

  Future<void> carregarContas() async {
    try {
      final resultado = await _repository.listar();

      if (!mounted) return;

      setState(() {
        contas = resultado;
        carregando = false;
        erro = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
        erro = 'Não foi possível carregar as contas: $e';
      });
    }
  }

  String formatarMoeda(Object? valor) {
    final centavos = (valor as num?)?.toInt() ?? 0;
    final reais = (centavos / 100).toStringAsFixed(2);

    return 'R\$ ${reais.replaceAll('.', ',')}';
  }

  String formatarData(String data) {
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

  Color corStatus(String? status, BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case 'paga':
        return escuro
            ? const Color(0xFF4ADE80)
            : const Color(0xFF16A34A);
      case 'atrasada':
        return escuro
            ? const Color(0xFFF87171)
            : const Color(0xFFDC2626);
      case 'parcial':
        return escuro
            ? const Color(0xFFFBBF24)
            : const Color(0xFFD97706);
      default:
        return escuro
            ? const Color(0xFF60A5FA)
            : azulPrincipal;
    }
  }

  Color fundoStatus(String? status, BuildContext context) {
    return corStatus(status, context).withValues(alpha: 0.14);
  }

  IconData iconeCategoria(String categoria) {
    final nome = categoria.toLowerCase();

    if (nome.contains('água') || nome.contains('agua')) {
      return Icons.water_drop_outlined;
    }
    if (nome.contains('energia') || nome.contains('luz')) {
      return Icons.bolt_outlined;
    }
    if (nome.contains('internet')) {
      return Icons.wifi_outlined;
    }
    if (nome.contains('telefone') || nome.contains('celular')) {
      return Icons.phone_android_outlined;
    }
    if (nome.contains('gás') || nome.contains('gas')) {
      return Icons.local_fire_department_outlined;
    }
    if (nome.contains('moradia') || nome.contains('aluguel')) {
      return Icons.home_outlined;
    }

    return Icons.receipt_long_outlined;
  }

  List<Map<String, Object?>> get contasFiltradas {
    if (filtroSelecionado == 'Todas') {
      return contas;
    }

    final statusFiltro = {
      'Pendentes': 'pendente',
      'Atrasadas': 'atrasada',
      'Parciais': 'parcial',
      'Pagas': 'paga',
    }[filtroSelecionado];

    return contas.where((conta) {
      return conta['status'] == statusFiltro;
    }).toList();
  }

  Future<void> abrirDetalhes(Map<String, Object?> conta) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaDetalhesConta(
          contaId: conta['id'] as int,
          nome: conta['nome'] as String,
          valor: formatarMoeda(conta['valor_total_centavos']),
          vencimento: formatarData(conta['data_vencimento'] as String),
          status: nomeStatus(conta['status'] as String?),
          recorrencia: conta['recorrencia_id'] == null
              ? 'Não se repete'
              : 'Recorrente',
        ),
      ),
    );

    await carregarContas();
  }

  Future<void> abrirCadastro() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TelaAdicionarConta(),
      ),
    );

    await carregarContas();
  }

  Widget construirFiltro(String nome) {
    final cores = Theme.of(context).colorScheme;
    final selecionado = filtroSelecionado == nome;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(nome),
        selected: selecionado,
        showCheckmark: false,
        onSelected: (_) {
          setState(() {
            filtroSelecionado = nome;
          });
        },
        backgroundColor: cores.surfaceContainer,
        selectedColor: azulPrincipal,
        side: BorderSide(
          color: selecionado ? azulPrincipal : cores.outlineVariant,
        ),
        labelStyle: TextStyle(
          color: selecionado ? Colors.white : cores.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget construirStatus(String? status) {
    final cor = corStatus(status, context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: fundoStatus(status, context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        nomeStatus(status),
        style: TextStyle(
          color: cor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget construirIndicadorRecorrente() {
    final cores = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: cores.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cores.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat,
            size: 13,
            color: cores.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            'Recorrente',
            style: TextStyle(
              color: cores.onPrimaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget construirConta(Map<String, Object?> conta) {
    final cores = Theme.of(context).colorScheme;

    final status = conta['status'] as String?;
    final categoria = conta['categoria_nome'] as String? ?? 'Outros';
    final vencimento = conta['data_vencimento'] as String;
    final descricao = (conta['descricao'] as String?)?.trim() ?? '';

    final recorrente = conta['recorrencia_id'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cores.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: status == 'atrasada'
              ? cores.error.withValues(alpha: 0.4)
              : cores.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => abrirDetalhes(conta),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: cores.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      iconeCategoria(categoria),
                      color: cores.onPrimaryContainer,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conta['nome'] as String? ?? 'Conta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cores.onSurface,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              categoria,
                              style: TextStyle(
                                fontSize: 13,
                                color: cores.onSurfaceVariant,
                              ),
                            ),
                            if (recorrente)
                              construirIndicadorRecorrente(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  construirStatus(status),
                ],
              ),
              if (descricao.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  descricao,
                  style: TextStyle(
                    fontSize: 13,
                    color: cores.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: cores.outlineVariant,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: cores.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Vencimento: ${formatarData(vencimento)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cores.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    formatarMoeda(conta['valor_total_centavos']),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cores.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget construirConteudoVazio() {
    final cores = Theme.of(context).colorScheme;

    final mensagem = filtroSelecionado == 'Todas'
        ? 'Você ainda não possui contas cadastradas.'
        : 'Nenhuma conta encontrada neste filtro.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: cores.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: cores.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Tudo organizado por aqui?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: cores.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cores.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cores.surface,
      appBar: AppBar(
        backgroundColor: cores.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Minhas Contas',
          style: TextStyle(
            color: cores.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: carregarContas,
            icon: Icon(
              Icons.refresh_rounded,
              color: cores.onSurfaceVariant,
            ),
            tooltip: 'Atualizar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: carregando
          ? Center(
              child: CircularProgressIndicator(
                color: cores.primary,
              ),
            )
          : erro != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 44,
                          color: cores.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          erro!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cores.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: carregarContas,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Organize suas despesas',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: cores.onSurface,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${contas.length} ${contas.length == 1 ? 'conta cadastrada' : 'contas cadastradas'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: cores.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Row(
                        children: [
                          construirFiltro('Todas'),
                          construirFiltro('Pendentes'),
                          construirFiltro('Atrasadas'),
                          construirFiltro('Parciais'),
                          construirFiltro('Pagas'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: contasFiltradas.isEmpty
                          ? RefreshIndicator(
                              color: cores.primary,
                              onRefresh: carregarContas,
                              child: ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: 350,
                                    child: construirConteudoVazio(),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: cores.primary,
                              onRefresh: carregarContas,
                              child: ListView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  100,
                                ),
                                itemCount: contasFiltradas.length,
                                itemBuilder: (context, index) {
                                  return construirConta(
                                    contasFiltradas[index],
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: abrirCadastro,
        backgroundColor: azulPrincipal,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nova conta',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}