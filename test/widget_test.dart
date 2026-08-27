import 'package:flutter_test/flutter_test.dart';
import 'package:tetrapong/main.dart';

void main() {
  testWidgets('exibe o menu principal TetraPong', (tester) async {
    await tester.pumpWidget(const TetraPongApp());
    expect(find.text('TETRAPONG'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('HOW TO PLAY'), findsOneWidget);
  });

  testWidgets('abre instruções pelo menu', (tester) async {
    await tester.pumpWidget(const TetraPongApp());
    await tester.tap(find.text('HOW TO PLAY'));
    await tester.pump();
    expect(find.text('HOW TO PLAY'), findsOneWidget);
    expect(find.textContaining('Um MISS cria uma penalidade'), findsOneWidget);
  });
}
