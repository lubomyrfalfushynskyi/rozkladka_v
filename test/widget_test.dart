import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:vohnegasnyky_oblik/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('Home screen shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(const VohnegasnykyApp());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('Облік вогнегасників'), findsOneWidget);
  });
}
