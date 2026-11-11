import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Porquinho - Demo Web',
        theme: ThemeData(colorSchemeSeed: Colors.pink, useMaterial3: true),
        home: const DemoPage(),
      );
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _controller = TextEditingController(text: '9007199254740993');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _brl(BigInt cents) {
    final s = cents.abs().toString().padLeft(3, '0');
    final int_ = s.substring(0, s.length - 2).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '${cents.isNegative ? '-' : ''}R\$ $int_,${s.substring(s.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final cents = BigInt.tryParse(_controller.text.trim());
    final asDouble = cents?.toDouble();
    final doubleBack = asDouble == null ? null : BigInt.from(asDouble);
    final instant = DateTime.utc(2028, 2, 29, 23, 59, 59, 999, 999);

    return Scaffold(
      appBar: AppBar(title: const Text('Porquinho - Demo Web')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Valor em centavos (texto decimal):'),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (cents == null)
            const Text('Valor inválido')
          else ...[
            _row('BigInt (exato)', cents.toString()),
            _row('Formatado BRL', _brl(cents)),
            _row('Via double (errado)', doubleBack.toString()),
            _row(
              'Double perdeu precisão?',
              doubleBack == cents ? 'Não' : 'SIM - por isso usamos BigInt',
            ),
            _row('Soma BigInt (valor + 1)', (cents + BigInt.one).toString()),
          ],
          const Divider(height: 32),
          _row('Instante UTC (bissexto)', instant.toIso8601String()),
          _row('Data ISO', '2028-02-29'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            SelectableText(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
          ],
        ),
      );
}
