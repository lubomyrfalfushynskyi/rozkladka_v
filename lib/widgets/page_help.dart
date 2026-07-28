import 'package:flutter/material.dart';

/// Показує діалог-довідку по поточній сторінці: заголовок + список пунктів.
Future<void> showPageHelp(BuildContext context, String title, List<String> points) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final point in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $point'),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Гаразд')),
      ],
    ),
  );
}

/// Іконка-довідка для AppBar.actions — відкриває [showPageHelp] з тим самим
/// заголовком і пунктами. Додається на кожній сторінці (поруч з іншими
/// кнопками AppBar); текст веде себе поруч з кодом сторінки — коли
/// змінюється функціонал сторінки, ці пункти теж треба оновити.
class PageHelpAction extends StatelessWidget {
  final String title;
  final List<String> points;

  const PageHelpAction({super.key, required this.title, required this.points});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: 'Довідка',
      onPressed: () => showPageHelp(context, title, points),
    );
  }
}
