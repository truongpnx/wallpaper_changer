import 'package:flutter_test/flutter_test.dart';

import 'package:wallpaper_app/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const WallpaperApp());
    expect(find.text('Albums'), findsOneWidget);
  });
}
