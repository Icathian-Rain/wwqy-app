import 'package:flutter_test/flutter_test.dart';
import 'package:wwqy_app/app.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const WwqyApp());
    expect(find.text('游戏点位助手'), findsOneWidget);
  });
}
