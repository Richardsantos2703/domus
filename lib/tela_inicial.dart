import 'package:flutter/material.dart';

import 'database/contas_repository.dart';
import 'contas.dart';
import 'adicionar_conta.dart';
import 'resumo_mensal.dart';

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  final ContasRepository _repository = ContasRepository();

  late Future<_DadosTelaInicial> _dadosFuture;

  @override
  void initState() {
    super.initState();
    _dadosFuture = _carregarDados();
  }

  Future<_DadosTelaInicial> _carregarDados() async {
    final resumo = await _repository.resumoMes();
    final contas = await _repository.listar();

    final proximasContas = contas.where((conta) {
      return conta['status'] != 'paga';
    }).toList();

    proximasContas.sort((a, b) {
      final statusA = a['status'] as String;
      final statusB = b['status'] as String;

      if (statusA == 'atrasada' && statusB != 'atrasada') {
        return -1;
      }

      if (statusB == 'atrasada' && statusA != 'atrasada') {
        return 1;
      }

      final dataA = a['data_vencimento'] as String;
      final dataB = b['data_vencimento'] as String;

      return dataA.compareTo(dataB);
    });

    final quantidadeAtrasadas = contas.where((conta) {
      return conta['status'] == 'atrasada';
    }).length;

    return _DadosTelaInicial(
      resumo: resumo,
      proximasContas: proximasContas.take(5).toList(),
      quantidadeAtrasadas: quantidadeAtrasadas,
    );
  }

  String _formatarMoeda(int centavos) {
    final reais = centavos ~/ 100;
    final centavosFormatados = (centavos % 100).toString().padLeft(2, '0');

    final reaisFormatados = reais.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );

    return 'R\$ $reaisFormatados,$centavosFormatados';
  }

  String _formatarDataExibicao(String data) {
    final partes = data.split('-');

    if (partes.length != 3) {
      return data;
    }

    return '${partes[2]}/${partes[1]}';
  }

  Future<void> _abrirTela(Widget tela) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => tela),
    );

    if (!mounted) return;

    setState(() {
      _dadosFuture = _carregarDados();
    });
  }

  Future<void> _atualizarDados() async {
    setState(() {
      _dadosFuture = _carregarDados();
    });

    await _dadosFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            const Text(
              'Domus',
              style: TextStyle(
                color: Color(0xFF172033),
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<_DadosTelaInicial>(
        future: _dadosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando suas contas...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Não foi possível carregar suas contas.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _atualizarDados,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final dados = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _atualizarDados,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Olá!',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Controle suas contas',
                    style: TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 22),

                  _CardTotalMes(
                    total: _formatarMoeda(
                      dados.resumo['total_mes_centavos'] as int? ?? 0,
                    ),
                    pago: _formatarMoeda(
                      dados.resumo['total_pago_mes_centavos'] as int? ?? 0,
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _abrirTela(const TelaResumoMensal());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFD7E3F8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: const Text(
                        'Ver resumo mensal completo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  const _TituloSecao(
                    titulo: 'Situação das contas',
                    subtitulo: 'Acompanhe seus pagamentos',
                  ),

                  const SizedBox(height: 14),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final largura = (constraints.maxWidth - 12) / 2;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: largura,
                            child: _CardResumo(
                              titulo: 'Pendentes',
                              valor:
                                  dados.resumo['quantidade_pendentes']
                                      as int? ??
                                  0,
                              cor: const Color(0xFFD97706),
                              icone: Icons.schedule_rounded,
                            ),
                          ),
                          SizedBox(
                            width: largura,
                            child: _CardResumo(
                              titulo: 'Atrasadas',
                              valor:
                                  dados.resumo['quantidade_atrasadas']
                                      as int? ??
                                  0,
                              cor: const Color(0xFFDC2626),
                              icone: Icons.warning_amber_rounded,
                            ),
                          ),
                          SizedBox(
                            width: largura,
                            child: _CardResumo(
                              titulo: 'Parciais',
                              valor:
                                  dados.resumo['quantidade_parciais'] as int? ??
                                  0,
                              cor: const Color(0xFFEA580C),
                              icone: Icons.pie_chart_outline_rounded,
                            ),
                          ),
                          SizedBox(
                            width: largura,
                            child: _CardResumo(
                              titulo: 'Pagas',
                              valor:
                                  dados.resumo['quantidade_pagas'] as int? ?? 0,
                              cor: const Color(0xFF16A34A),
                              icone: Icons.check_circle_outline_rounded,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  _TituloSecao(
                    titulo: 'Próximas contas',
                    subtitulo: dados.proximasContas.isEmpty
                        ? 'Tudo em dia por enquanto'
                        : 'Contas que precisam da sua atenção',
                  ),

                  const SizedBox(height: 14),

                  if (dados.quantidadeAtrasadas > 0) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        border: Border.all(color: const Color(0xFFFECACA)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFDC2626),
                            size: 27,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dados.quantidadeAtrasadas == 1
                                  ? 'Atenção! Você tem 1 conta atrasada.'
                                  : 'Atenção! Você tem ${dados.quantidadeAtrasadas} contas atrasadas.',
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (dados.proximasContas.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 28,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE8EDF5)),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 42,
                            color: Color(0xFF16A34A),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Nenhuma conta próxima do vencimento.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...dados.proximasContas.map((conta) {
                      return _Conta(
                        nome: conta['nome'] as String,
                        descricao:
                            (conta['descricao'] as String?)?.trim() ?? '',
                        valor: _formatarMoeda(
                          (conta['saldo_centavos'] as num).toInt(),
                        ),
                        vencimento: _formatarDataExibicao(
                          conta['data_vencimento'] as String,
                        ),
                        parcial: conta['status'] == 'parcial',
                        atrasada: conta['status'] == 'atrasada',
                        recorrente: conta['recorrencia_id'] != null,
                      );
                    }),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        _abrirTela(const TelaContas());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFD7E3F8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Ver todas as contas',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _abrirTela(const TelaAdicionarConta());
        },
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nova conta',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _DadosTelaInicial {
  final Map<String, Object?> resumo;
  final List<Map<String, Object?>> proximasContas;
  final int quantidadeAtrasadas;

  _DadosTelaInicial({
    required this.resumo,
    required this.proximasContas,
    required this.quantidadeAtrasadas,
  });
}

class _TituloSecao extends StatelessWidget {
  final String titulo;
  final String subtitulo;

  const _TituloSecao({required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Color(0xFF172033),
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitulo,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      ],
    );
  }
}

class _CardTotalMes extends StatelessWidget {
  final String total;
  final String pago;

  const _CardTotalMes({required this.total, required this.pago});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            color: const Color(0xFF2563EB).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total das contas do mês',
                  style: TextStyle(
                    color: Color(0xFFE8F0FF),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            total,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.22)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFFBBF7D0),
                size: 19,
              ),
              const SizedBox(width: 8),
              const Text(
                'Pago neste mês',
                style: TextStyle(color: Color(0xFFE8F0FF), fontSize: 13),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  pago,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardResumo extends StatelessWidget {
  final String titulo;
  final int valor;
  final Color cor;
  final IconData icone;

  const _CardResumo({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icone, color: cor, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor.toString(),
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Conta extends StatelessWidget {
  final String nome;
  final String descricao;
  final String valor;
  final String vencimento;
  final bool parcial;
  final bool atrasada;
  final bool recorrente;

  const _Conta({
    required this.nome,
    required this.descricao,
    required this.valor,
    required this.vencimento,
    required this.parcial,
    required this.atrasada,
    required this.recorrente,
  });

  @override
  Widget build(BuildContext context) {
    final corStatus = atrasada
        ? const Color(0xFFDC2626)
        : parcial
        ? const Color(0xFFEA580C)
        : const Color(0xFFD97706);

    final textoStatus = atrasada
        ? 'Atrasada'
        : parcial
        ? 'Pagamento parcial'
        : 'Pendente';

    final iconeStatus = atrasada
        ? Icons.warning_amber_rounded
        : parcial
        ? Icons.pie_chart_outline_rounded
        : Icons.schedule_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: atrasada ? const Color(0xFFFECACA) : const Color(0xFFE8EDF5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: corStatus.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(iconeStatus, color: corStatus, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (recorrente) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      border: Border.all(color: const Color(0xFFD7E3F8)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          color: Color(0xFF2563EB),
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Recorrente',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (descricao.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    descricao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  textoStatus,
                  style: TextStyle(
                    color: corStatus,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Saldo: $valor',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Vencimento',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
              ),
              const SizedBox(height: 4),
              Text(
                vencimento,
                style: TextStyle(
                  color: atrasada
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF334155),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
