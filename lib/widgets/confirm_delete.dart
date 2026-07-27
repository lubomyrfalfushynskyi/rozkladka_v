import 'package:flutter/material.dart';

/// Показує діалог підтвердження перед видаленням. Повертає true, якщо
/// користувач підтвердив.
Future<bool> confirmDelete(BuildContext context, String itemDescription) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Видалити?'),
      content: Text('Ви дійсно хочете видалити "$itemDescription"? Цю дію неможливо скасувати.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Видалити'),
        ),
      ],
    ),
  );
  return result ?? false;
}
