import 'package:flutter/material.dart';

import 'database/contas_repository.dart';

class TelaResumoMensal extends StatefulWidget {
  const TelaResumoMensal({super.key});

  @override
  State<TelaResumoMensal> createState() => _TelaResumoMensalState();
}

class _TelaResumoMensalState extends State<TelaResumoMensal> {
  final ContasRepository _repository = ContasRepository();

  late DateTime _mesSelecionado;
  late Future<_DadosResumoMensal> _dadosFuture;

  bool _mostrarTodas = false;

  static const List<String> _meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _mesSelecionado = DateTime(hoje.year, hoje.month);
    _dadosFuture = _carregarDados();
  }

  Future<_DadosResumoMensal> _carregarDados() async {
    final resumo = await _repository.resumoMes(referencia: _mesSelecionado);
    final contas = await _repository.listarPorMes(referencia: _mesSelecionado);
    return _DadosResumoMensal(resumo: resumo, contas: contas);
  }

  void _alterarMes(int quantidade) {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month + quantidade,
      );
      _mostrarTodas = false;
      _dadosFuture = _carregarDados();
    });
  }

  Future<void> _selecionarMes() async {
    final selecionado = await showDialog<DateTime>(
      context: context,
      builder: (context) => _DialogoSelecionarMes(
        mesInicial: _mesSelecionado.month,
        anoInicial: _mesSelecionado.year,
      ),
    );

    if (!mounted || selecionado == null) return;

    setState(() {
      _mesSelecionado = selecionado;
      _mostrarTodas = false;
      _dadosFuture = _carregarDados();
    });
  }

  Future<void> _atualizarDados() async {
    setState(() {
      _dadosFuture = _carregarDados();
    });
    await _dadosFuture;
  }

  int _valor(Map<String, Object?> dados, String chave) {
    return (dados[chave] as num?)?.toInt() ?? 0;
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

  String _formatarData(String data) {
    final partes = data.split('-');
    if (partes.length != 3) return data;
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  String get _nomeMes =>
      '${_meses[_mesSelecionado.month - 1]} de ${_mesSelecionado.year}';

  Color _corStatus(String status) {
    switch (status) {
      case 'paga':
        return const Color(0xFF16A34A);
      case 'atrasada':
        return const Color(0xFFDC2626);
      case 'parcial':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFFD97706);
    }
  }

  String _nomeStatus(String status) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Resumo mensal',
          style: TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: FutureBuilder<_DadosResumoMensal>(
        future: _dadosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
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
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Não foi possível carregar o resumo mensal.',
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
          final total = _valor(dados.resumo, 'total_mes_centavos');
          final pago = _valor(dados.resumo, 'total_pago_contas_mes_centavos');
          final saldo = _valor(dados.resumo, 'saldo_aberto_mes_centavos');
          final pagamentosMes = _valor(dados.resumo, 'total_pago_mes_centavos');

          final pendentes = _valor(dados.resumo, 'quantidade_pendentes');
          final atrasadas = _valor(dados.resumo, 'quantidade_atrasadas');
          final parciais = _valor(dados.resumo, 'quantidade_parciais');
          final pagas = _valor(dados.resumo, 'quantidade_pagas');
          final quantidadeTotal = pendentes + atrasadas + parciais + pagas;

          final contasExibidas = _mostrarTodas
              ? dados.contas
              : dados.contas.take(3).toList();

          return RefreshIndicator(
            color: const Color(0xFF2563EB),
            onRefresh: _atualizarDados,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SeletorMes(
                    nomeMes: _nomeMes,
                    voltar: () => _alterarMes(-1),
                    avancar: () => _alterarMes(1),
                    selecionar: _selecionarMes,
                  ),
                  const SizedBox(height: 20),
                  _CardTotalMensal(
                    total: _formatarMoeda(total),
                    pago: _formatarMoeda(pago),
                    saldo: _formatarMoeda(saldo),
                  ),
                  const SizedBox(height: 14),
                  _CardMovimentacao(valor: _formatarMoeda(pagamentosMes)),
                  const SizedBox(height: 28),
                  const _TituloSecao(
                    titulo: 'Situação das contas',
                    subtitulo: 'Distribuição das contas por status atual',
                  ),
                  const SizedBox(height: 14),
                  _CardGraficoRosca(
                    pendentes: pendentes,
                    atrasadas: atrasadas,
                    parciais: parciais,
                    pagas: pagas,
                    total: quantidadeTotal,
                  ),
                  const SizedBox(height: 28),
                  const _TituloSecao(
                    titulo: 'Comparativo financeiro',
                    subtitulo: 'Veja quanto foi pago e quanto ainda falta',
                  ),
                  const SizedBox(height: 14),
                  _CardGraficoBarras(
                    total: total,
                    pago: pago,
                    saldo: saldo,
                    formatarMoeda: _formatarMoeda,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: _TituloSecao(
                          titulo: 'Contas do mês',
                          subtitulo: 'Contas com vencimento neste período',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${dados.contas.length}',
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (dados.contas.isEmpty)
                    const _EstadoVazioContas()
                  else ...[
                    ...contasExibidas.map((conta) {
                      final status = conta['status'] as String? ?? 'pendente';

                      return _ItemContaMensal(
                        nome: conta['nome'] as String? ?? 'Conta',
                        vencimento: _formatarData(
                          conta['data_vencimento'] as String? ?? '',
                        ),
                        total: _formatarMoeda(
                          (conta['valor_total_centavos'] as num?)?.toInt() ?? 0,
                        ),
                        pago: _formatarMoeda(
                          (conta['valor_pago_centavos'] as num?)?.toInt() ?? 0,
                        ),
                        saldo: _formatarMoeda(
                          (conta['saldo_centavos'] as num?)?.toInt() ?? 0,
                        ),
                        status: _nomeStatus(status),
                        corStatus: _corStatus(status),
                        recorrente: conta['recorrencia_id'] != null,
                      );
                    }),
                    if (dados.contas.length > 3) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _mostrarTodas = !_mostrarTodas;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            _mostrarTodas
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          label: Text(
                            _mostrarTodas
                                ? 'Mostrar menos'
                                : 'Ver todas as contas',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DialogoSelecionarMes extends StatefulWidget {
  final int mesInicial;
  final int anoInicial;

  const _DialogoSelecionarMes({
    required this.mesInicial,
    required this.anoInicial,
  });

  @override
  State<_DialogoSelecionarMes> createState() => _DialogoSelecionarMesState();
}

class _DialogoSelecionarMesState extends State<_DialogoSelecionarMes> {
  late int _mes;
  late int _ano;

  static const List<String> _meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _mes = widget.mesInicial;
    _ano = widget.anoInicial;
  }

  @override
  Widget build(BuildContext context) {
    final anoAtual = DateTime.now().year;
    final anos = List.generate(anoAtual + 11 - 2000, (index) => 2000 + index);

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Escolher período',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF172033)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecione o mês e o ano que deseja consultar.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            initialValue: _mes,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Mês',
              prefixIcon: const Icon(Icons.calendar_month),
              filled: true,
              fillColor: const Color(0xFFF5F7FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            items: List.generate(
              _meses.length,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text(_meses[index]),
              ),
            ),
            onChanged: (valor) {
              if (valor != null) setState(() => _mes = valor);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _ano,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Ano',
              prefixIcon: const Icon(Icons.date_range),
              filled: true,
              fillColor: const Color(0xFFF5F7FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            items: anos.map((ano) {
              return DropdownMenuItem(value: ano, child: Text(ano.toString()));
            }).toList(),
            onChanged: (valor) {
              if (valor != null) setState(() => _ano = valor);
            },
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.pop(context, DateTime(_ano, _mes)),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _DadosResumoMensal {
  final Map<String, Object?> resumo;
  final List<Map<String, Object?>> contas;

  const _DadosResumoMensal({required this.resumo, required this.contas});
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
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitulo,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _SeletorMes extends StatelessWidget {
  final String nomeMes;
  final VoidCallback voltar;
  final VoidCallback avancar;
  final VoidCallback selecionar;

  const _SeletorMes({
    required this.nomeMes,
    required this.voltar,
    required this.avancar,
    required this.selecionar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: voltar,
            tooltip: 'Mês anterior',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              foregroundColor: const Color(0xFF334155),
            ),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: InkWell(
              onTap: selecionar,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            nomeMes,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF172033),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF2563EB),
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Escolher mês e ano',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: avancar,
            tooltip: 'Próximo mês',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              foregroundColor: const Color(0xFF334155),
            ),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _CardTotalMensal extends StatelessWidget {
  final String total;
  final String pago;
  final String saldo;

  const _CardTotalMensal({
    required this.total,
    required this.pago,
    required this.saldo,
  });

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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.18),
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
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Total das contas do mês',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            total,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(color: Colors.white30, height: 1),
          ),
          _LinhaValor(titulo: 'Pago nessas contas', valor: pago),
          const SizedBox(height: 12),
          _LinhaValor(titulo: 'Saldo em aberto', valor: saldo),
        ],
      ),
    );
  }
}

class _LinhaValor extends StatelessWidget {
  final String titulo;
  final String valor;

  const _LinhaValor({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
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

class _CardMovimentacao extends StatelessWidget {
  final String valor;

  const _CardMovimentacao({required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Color(0xFF16A34A),
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pagamentos realizados no mês',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  valor,
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                    fontSize: 21,
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

class _CardGraficoRosca extends StatelessWidget {
  final int pendentes;
  final int atrasadas;
  final int parciais;
  final int pagas;
  final int total;

  const _CardGraficoRosca({
    required this.pendentes,
    required this.atrasadas,
    required this.parciais,
    required this.pagas,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final itens = [
      _ItemLegenda(
        titulo: 'Pendentes',
        quantidade: pendentes,
        cor: const Color(0xFFD97706),
      ),
      _ItemLegenda(
        titulo: 'Atrasadas',
        quantidade: atrasadas,
        cor: const Color(0xFFDC2626),
      ),
      _ItemLegenda(
        titulo: 'Parciais',
        quantidade: parciais,
        cor: const Color(0xFFEA580C),
      ),
      _ItemLegenda(
        titulo: 'Pagas',
        quantidade: pagas,
        cor: const Color(0xFF16A34A),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _RoscaPainter(
                    valores: [pendentes, atrasadas, parciais, pagas],
                    cores: [
                      const Color(0xFFD97706),
                      const Color(0xFFDC2626),
                      const Color(0xFFEA580C),
                      const Color(0xFF16A34A),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total.toString(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172033),
                      ),
                    ),
                    Text(
                      total == 1 ? 'conta' : 'contas',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200),
          ...itens.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: item.cor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      item.titulo,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    item.quantidade.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172033),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ItemLegenda {
  final String titulo;
  final int quantidade;
  final Color cor;

  const _ItemLegenda({
    required this.titulo,
    required this.quantidade,
    required this.cor,
  });
}

class _RoscaPainter extends CustomPainter {
  final List<int> valores;
  final List<Color> cores;

  const _RoscaPainter({required this.valores, required this.cores});

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final retangulo = Rect.fromCircle(
      center: centro,
      radius: size.width / 2 - 12,
    );
    final total = valores.fold<int>(0, (soma, valor) => soma + valor);

    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.butt;

    if (total == 0) {
      pincel.color = const Color(0xFFE2E8F0);
      canvas.drawArc(retangulo, 0, 6.283185307179586, false, pincel);
      return;
    }

    var inicio = -1.5707963267948966;

    for (var i = 0; i < valores.length; i++) {
      if (valores[i] == 0) continue;
      final angulo = valores[i] / total * 6.283185307179586;
      pincel.color = cores[i];
      canvas.drawArc(retangulo, inicio, angulo, false, pincel);
      inicio += angulo;
    }
  }

  @override
  bool shouldRepaint(covariant _RoscaPainter oldDelegate) {
    return valores.toString() != oldDelegate.valores.toString() ||
        cores.toString() != oldDelegate.cores.toString();
  }
}

class _CardGraficoBarras extends StatelessWidget {
  final int total;
  final int pago;
  final int saldo;
  final String Function(int) formatarMoeda;

  const _CardGraficoBarras({
    required this.total,
    required this.pago,
    required this.saldo,
    required this.formatarMoeda,
  });

  @override
  Widget build(BuildContext context) {
    final maiorValor = total > 0 ? total : 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Column(
        children: [
          _BarraComparativa(
            titulo: 'Total',
            valor: total,
            maiorValor: maiorValor,
            cor: const Color(0xFF2563EB),
            formatarMoeda: formatarMoeda,
          ),
          const SizedBox(height: 24),
          _BarraComparativa(
            titulo: 'Pago nas contas',
            valor: pago,
            maiorValor: maiorValor,
            cor: const Color(0xFF16A34A),
            formatarMoeda: formatarMoeda,
          ),
          const SizedBox(height: 24),
          _BarraComparativa(
            titulo: 'Saldo em aberto',
            valor: saldo,
            maiorValor: maiorValor,
            cor: const Color(0xFFEA580C),
            formatarMoeda: formatarMoeda,
          ),
        ],
      ),
    );
  }
}

class _BarraComparativa extends StatelessWidget {
  final String titulo;
  final int valor;
  final int maiorValor;
  final Color cor;
  final String Function(int) formatarMoeda;

  const _BarraComparativa({
    required this.titulo,
    required this.valor,
    required this.maiorValor,
    required this.cor,
    required this.formatarMoeda,
  });

  @override
  Widget build(BuildContext context) {
    final proporcao = (valor / maiorValor).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatarMoeda(valor),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF172033),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 11,
            width: double.infinity,
            color: const Color(0xFFF1F5F9),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: proporcao,
              child: Container(
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EstadoVazioContas extends StatelessWidget {
  const _EstadoVazioContas();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 30,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Nenhuma conta neste mês',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Não existem contas com vencimento neste período.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ItemContaMensal extends StatelessWidget {
  final String nome;
  final String vencimento;
  final String total;
  final String pago;
  final String saldo;
  final String status;
  final Color corStatus;
  final bool recorrente;

  const _ItemContaMensal({
    required this.nome,
    required this.vencimento,
    required this.total,
    required this.pago,
    required this.saldo,
    required this.status,
    required this.corStatus,
    required this.recorrente,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172033),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: corStatus.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: corStatus,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Identificação visual de conta recorrente.
          if (recorrente) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD7E3F8)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    size: 13,
                    color: Color(0xFF2563EB),
                  ),
                  SizedBox(width: 5),
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

          const SizedBox(height: 9),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Vencimento: $vencimento',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
          _LinhaConta(titulo: 'Valor total', valor: total),
          const SizedBox(height: 9),
          _LinhaConta(titulo: 'Valor pago', valor: pago),
          const SizedBox(height: 9),
          _LinhaConta(titulo: 'Saldo restante', valor: saldo, destaque: true),
        ],
      ),
    );
  }
}

class _LinhaConta extends StatelessWidget {
  final String titulo;
  final String valor;
  final bool destaque;

  const _LinhaConta({
    required this.titulo,
    required this.valor,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: destaque ? const Color(0xFF334155) : Colors.grey.shade600,
            fontSize: 13,
            fontWeight: destaque ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: destaque ? const Color(0xFF2563EB) : const Color(0xFF172033),
          ),
        ),
      ],
    );
  }
}
