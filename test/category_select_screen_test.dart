import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:first/app_colors.dart';
import 'package:first/screens/category_select_screen.dart';

void main() {
  testWidgets('CategorySelectScreen exposes only payment category options', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(
          home: CategorySelectScreen(currentCategory: '기타'),
        ),
      ),
    );

    expect(find.text('카페'), findsOneWidget);
    expect(find.text('식비'), findsOneWidget);
    expect(find.text('쇼핑'), findsOneWidget);
    expect(find.text('교통'), findsOneWidget);
    expect(find.text('통신'), findsOneWidget);
    expect(find.text('기타'), findsOneWidget);

    expect(find.text('쇼핑, 여가'), findsNothing);
    expect(find.text('여행, 숙박'), findsNothing);
    expect(find.text('카테고리 추가'), findsNothing);
  });
}
