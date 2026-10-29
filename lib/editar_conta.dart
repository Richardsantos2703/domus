import 'package:flutter/material.dart';

class TelaEditarConta extends StatefulWidget {
  final String nome;
  final String valor;
  final String vencimento;
  final String status;
  final String recorrencia;

  const TelaEditarConta({
    super.key,
    required this.nome,
    required this.valor,
    required this.vencimento,
    required this.status,
    required this.recorrencia,
  });

  @override
  State<TelaEditarConta> createState() => _TelaEditarContaState();
}

class _TelaEditarContaState extends State<TelaEditarConta> {
  late TextEditingController nomeController;
  late TextEditingController valorController;
  late TextEditingController vencimentoController;

  late String statusSelecionado;
  late String recorrenciaSelecionada;

  @override
  void initState() {
    super.initState();

    nomeController = TextEditingController(text: widget.nome);
    valorController = TextEditingController(text: widget.valor);
    vencimentoController = TextEditingController(text: widget.vencimento);

    statusSelecionado = widget.status;
    recorrenciaSelecionada = widget.recorrencia;
  }

  @override
  void dispose() {
    nomeController.dispose();
    valorController.dispose();
    vencimentoController.dispose();

    super.dispose();
  }

  void salvarAlteracoes() {
    final nome = nomeController.text.trim();
    final valor = valorController.text.trim();
    final vencimento = vencimentoController.text.trim();

    if (nome.isEmpty || valor.isEmpty || vencimento.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha todos os campos antes de salvar.',
          ),
        ),
      );

      return;
    }

    Color cor;

    if (statusSelecionado == 'Paga') {
      cor = Colors.green;
    } else if (statusSelecionado == 'Atrasada') {
      cor = Colors.red;
    } else {
      cor = Colors.amber;
    }

    final contaAtualizada = {
      'nome': nome,
      'valor': valor,
      'vencimento': vencimento,
      'status': statusSelecionado,
      'cor': cor,
      'recorrencia': recorrenciaSelecionada,
    };

    Navigator.pop(context, contaAtualizada);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Editar conta',
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
              'Editar conta',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Altere os dados da conta.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: nomeController,
              decoration: InputDecoration(
                labelText: 'Nome da conta',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: valorController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Valor',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: vencimentoController,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: 'Data de vencimento',
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              initialValue: statusSelecionado,
              items: const [
                DropdownMenuItem(
                  value: 'Pendente',
                  child: Text('Pendente'),
                ),
                DropdownMenuItem(
                  value: 'Paga',
                  child: Text('Paga'),
                ),
                DropdownMenuItem(
                  value: 'Atrasada',
                  child: Text('Atrasada'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    statusSelecionado = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Recorrência',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              initialValue: recorrenciaSelecionada,
              items: const [
                DropdownMenuItem(
                  value: 'Não se repete',
                  child: Text('Não se repete'),
                ),
                DropdownMenuItem(
                  value: 'Mensal',
                  child: Text('Mensal'),
                ),
                DropdownMenuItem(
                  value: 'Anual',
                  child: Text('Anual'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    recorrenciaSelecionada = value;
                  });
                }
              },
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: salvarAlteracoes,
                child: const Text(
                  'Salvar alterações',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}