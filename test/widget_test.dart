import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kmz_lemburgo_mobile/core/theme/app_theme.dart';
import 'package:kmz_lemburgo_mobile/features/auth/data/models/auth_user.dart';
import 'package:kmz_lemburgo_mobile/features/dashboard/presentation/home_page.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('shows the signed-in LemburIN dashboard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          user: const AuthUser(
            id: '1',
            name: 'Khaeril Maswal Zaid',
            email: 'khaeril@example.com',
            roles: ['evaluator'],
          ),
          onStart: () {},
        ),
      ),
    );

    expect(find.text('Khaeril Maswal Zaid'), findsOneWidget);
    expect(find.text('Belum ada lembur hari ini'), findsOneWidget);
    expect(find.text('Mulai Lembur'), findsOneWidget);
  });
}
