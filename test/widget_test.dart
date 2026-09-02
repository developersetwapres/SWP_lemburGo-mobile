import 'package:flutter_test/flutter_test.dart';
import 'package:kmz_lemburgo_mobile/app.dart';

void main() {
  testWidgets('shows the LemburIN dashboard', (tester) async {
    await tester.pumpWidget(const LemburInApp());

    expect(find.text('Khaeril'), findsOneWidget);
    expect(find.text('Belum ada lembur hari ini'), findsOneWidget);
    expect(find.text('Mulai Lembur'), findsOneWidget);
  });
}
