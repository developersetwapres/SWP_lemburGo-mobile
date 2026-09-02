import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kmz_lemburgo_mobile/core/api/api_client.dart';
import 'package:kmz_lemburgo_mobile/core/storage/token_storage.dart';
import 'package:kmz_lemburgo_mobile/core/theme/app_theme.dart';
import 'package:kmz_lemburgo_mobile/features/auth/data/models/auth_user.dart';
import 'package:kmz_lemburgo_mobile/features/calendar/data/models/calendar_overtime.dart';
import 'package:kmz_lemburgo_mobile/features/dashboard/presentation/home_page.dart';
import 'package:kmz_lemburgo_mobile/features/overtime/data/models/draft_overtime.dart';
import 'package:kmz_lemburgo_mobile/features/overtime/data/overtime_repository.dart';

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
          repository: _FakeOvertimeRepository(),
          onStart: () async => false,
          onContinue: (_) async => false,
          onSessionExpired: () async {},
        ),
      ),
    );

    expect(find.text('Khaeril Maswal Zaid'), findsOneWidget);
    expect(find.text('Belum ada lembur hari ini'), findsOneWidget);
    expect(find.text('Mulai Lembur'), findsOneWidget);
  });

  test('returns backend success message when updating overtime', () async {
    final dio = Dio();
    dio.httpClientAdapter = _SuccessMessageAdapter();

    final repository = OvertimeRepository(dio, ApiClient(TokenStorage()));
    final draft = DraftOvertime(
      id: '1',
      uuid: 'uuid-123',
      activityDate: DateTime(2026, 9, 2),
      activityName: 'Draft lama',
      location: 'Lokasi lama',
      status: 'draft',
    );

    final message = await repository.update(
      draft: draft,
      date: DateTime(2026, 9, 2),
      activityName: 'Nama kegiatan baru',
      location: 'Lokasi baru',
    );

    expect(message, 'Lembur berhasil diperbarui.');
  });

  test('keeps calendar API dates as local date-only values', () {
    final entry = CalendarOvertime.fromJson({
      'tanggal': '2026-09-03',
      'lembur_id': 3,
    });

    expect(entry.date, DateTime(2026, 9, 3));
    expect(entry.dateKey, '2026-09-03');
    expect(entry.overtimeId, 3);
  });
}

class _FakeOvertimeRepository extends OvertimeRepository {
  _FakeOvertimeRepository() : super(Dio(), ApiClient(TokenStorage()));

  @override
  Future<List<DraftOvertime>> fetchDrafts() async => const [];
}

class _SuccessMessageAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final payload = jsonEncode({
      'message': 'Lembur berhasil diperbarui.',
      'data': null,
      'status_code': 200,
    });

    return ResponseBody.fromString(
      payload,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
