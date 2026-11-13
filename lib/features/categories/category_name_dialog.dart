import 'package:flutter/material.dart';

import 'category_service.dart';

/// Pede um nome ao usuário; valida como o servidor (não vazio, até 60).
Future<String?> askName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  String? error;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('campo-nome'),
          controller: controller,
          autofocus: true,
          maxLength: CategoryService.maxNameLength,
          decoration: InputDecoration(labelText: 'Nome', errorText: error),
          onSubmitted: (_) => _submit(context, controller, (e) {
            setState(() => error = e);
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => _submit(context, controller, (e) {
              setState(() => error = e);
            }),
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

void _submit(
  BuildContext context,
  TextEditingController controller,
  void Function(String?) onError,
) {
  final problem = CategoryService.validateName(controller.text);
  if (problem != null) {
    onError(problem);
    return;
  }
  Navigator.pop(context, controller.text.trim());
}
