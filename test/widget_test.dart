import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wwqy_app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const WwqyApp());
    expect(find.text('游戏点位助手'), findsOneWidget);
  });
}
