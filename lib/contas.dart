import 'package:flutter/material.dart';
import 'detalhes_conta.dart';
import 'adicionar_conta.dart';

class TelaContas extends StatefulWidget {
  const TelaContas({super.key});

  @override
  State<TelaContas> createState() => _TelaContasState();
}

class _TelaContasState extends State<TelaContas> {
  final List<Map<String, dynamic>> contas = [
    {
      'nome': 'Água',
      'valor': 'R\$ 85,00',
      'vencimento': '10/10/2026',
      'status': 'Pendente',
      'cor': Colors.amber,
      'recorrencia': 'Mensal',
    },
    {
      'nome': 'Internet',
      'valor': 'R\$ 99,90',
      'vencimento': '15/10/2026',
      'status': 'Paga',
      'cor': Colors.green,
      'recorrencia': 'Mensal',
    },
    {
      'nome': 'Energia',
      'valor': 'R\$ 142,50',
      'vencimento': '05/10/2026',
      'status': 'Atrasada',
      'cor': Colors.red,
      'recorrencia': 'Mensal',
    },
    {
      'nome': 'Telefone',
      'valor': 'R\$ 49,90',
      'vencimento': '20/10/2026',
      'status': 'Pendente',
      'cor': Colors.amber,
      'recorrencia': 'Não se repete',
    },
  ];

  String ordemSelecionada = 'Mais recentes';

  bool mostrarPendentes = true;
  bool mostrarAtrasadas = true;
  bool mostrarPagas = true;

  DateTime converterData(String data) {
    final partes = data.split('/');

    return DateTime(
      int.parse(partes[2]),
      int.parse(partes[1]),
      int.parse(partes[0]),
    );
  }

  List<Map<String, dynamic>> get contasFiltradas {
    final lista = contas.where((conta) {
      final status = conta['status'];

      if (status == 'Pendente') {
        return mostrarPendentes;
      }

      if (status == 'Atrasada') {
        return mostrarAtrasadas;
      }

      if (status == 'Paga') {
        return mostrarPagas;
      }

      return false;
    }).toList();

    lista.sort((a, b) {
      final dataA = converterData(a['vencimento']);
      final dataB = converterData(b['vencimento']);

      if (ordemSelecionada == 'Mais antigas') {
        return dataA.compareTo(dataB);
      }

      return dataB.compareTo(dataA);
    });

    return lista;
  }

  void abrirOrdenacao() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ordenar contas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              RadioListTile<String>(
                title: const Text('Mais recentes'),
                value: 'Mais recentes',
                groupValue: ordemSelecionada,
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() {
                      ordemSelecionada = valor;
                    });

                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('Mais antigas'),
                value: 'Mais antigas',
                groupValue: ordemSelecionada,
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() {
                      ordemSelecionada = valor;
                    });

                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void abrirFiltro() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final todas =
                mostrarPendentes && mostrarAtrasadas && mostrarPagas;

            void atualizarTodas(bool valor) {
              setModalState(() {
                mostrarPendentes = valor;
                mostrarAtrasadas = valor;
                mostrarPagas = valor;
              });

              setState(() {});
            }

            void atualizarStatus(
              String status,
              bool valor,
            ) {
              setModalState(() {
                if (status == 'Pendente') {
                  mostrarPendentes = valor;
                } else if (status == 'Atrasada') {
                  mostrarAtrasadas = valor;
                } else if (status == 'Paga') {
                  mostrarPagas = valor;
                }
              });

              setState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Filtrar por status',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      title: const Text('Todas'),
                      value: todas,
                      onChanged: (valor) {
                        atualizarTodas(valor ?? false);
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Pendentes'),
                      value: mostrarPendentes,
                      onChanged: (valor) {
                        atualizarStatus(
                          'Pendente',
                          valor ?? false,
                        );
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Atrasadas'),
                      value: mostrarAtrasadas,
                      onChanged: (valor) {
                        atualizarStatus(
                          'Atrasada',
                          valor ?? false,
                        );
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Pagas'),
                      value: mostrarPagas,
                      onChanged: (valor) {
                        atualizarStatus(
                          'Paga',
                          valor ?? false,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Aplicar filtros',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> abrirDetalhes(
    Map<String, dynamic> conta,
  ) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaDetalhesConta(
          nome: conta['nome'],
          valor: conta['valor'],
          vencimento: conta['vencimento'],
          status: conta['status'],
          recorrencia: conta['recorrencia'],
        ),
      ),
    );

    if (resultado == 'paga') {
      setState(() {
        conta['status'] = 'Paga';
        conta['cor'] = Colors.green;
      });
    } else if (resultado == 'excluir') {
      setState(() {
        contas.remove(conta);
      });
    } else if (resultado is Map<String, dynamic>) {
      setState(() {
        final index = contas.indexOf(conta);

        if (index != -1) {
          contas[index] = resultado;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = contasFiltradas;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minhas contas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 2,
        shadowColor: Colors.black26,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contas do mês',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: abrirOrdenacao,
                    icon: const Icon(Icons.sort),
                    label: const Text('Ordenar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: abrirFiltro,
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Filtrar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (lista.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 48,
                      color: Colors.black38,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Nenhuma conta encontrada.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ...lista.map(
              (conta) => _Conta(
                nome: conta['nome'],
                valor: conta['valor'],
                vencimento: conta['vencimento'],
                status: conta['status'],
                cor: conta['cor'],
                onTap: () => abrirDetalhes(conta),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final novaConta = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TelaAdicionarConta(),
            ),
          );

          if (novaConta != null) {
            setState(() {
              contas.add(novaConta);
            });
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _Conta extends StatelessWidget {
  final String nome;
  final String valor;
  final String vencimento;
  final String status;
  final Color cor;
  final VoidCallback onTap;

  const _Conta({
    required this.nome,
    required this.valor,
    required this.vencimento,
    required this.status,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cor.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    valor,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vencimento: $vencimento',
                    style: const TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cor == Colors.amber
                    ? Colors.orange.shade800
                    : cor == Colors.green
                        ? Colors.green.shade700
                        : Colors.red.shade700,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Colors.black45,
            ),
          ],
        ),
      ),
    );
  }
}