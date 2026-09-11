import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kmz_lemburgo_mobile/app.dart';
import 'package:kmz_lemburgo_mobile/core/offline/sync_status.dart';
import 'package:kmz_lemburgo_mobile/core/theme/app_theme.dart';
import 'package:kmz_lemburgo_mobile/features/auth/data/models/auth_user.dart';
import 'package:kmz_lemburgo_mobile/features/auth/presentation/auth_controller.dart';
import 'package:kmz_lemburgo_mobile/features/calendar/data/models/calendar_overtime.dart';
import 'package:kmz_lemburgo_mobile/features/history/data/models/overtime_history.dart';
import 'package:kmz_lemburgo_mobile/features/overtime/data/models/draft_overtime.dart';
import 'package:kmz_lemburgo_mobile/features/overtime/data/models/year_overtime_summary.dart';
import 'package:kmz_lemburgo_mobile/features/overtime/data/overtime_repository.dart';
import 'package:kmz_lemburgo_mobile/features/overtime/data/services/photo_processing_service.dart';
import 'package:kmz_lemburgo_mobile/features/overtime/presentation/overtime_form_page.dart';
import 'package:kmz_lemburgo_mobile/shared/widgets/app_bottom_navigation.dart';
import 'package:kmz_lemburgo_mobile/shared/widgets/app_viewport.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    // Ahem's square glyphs overflow the existing mobile date header. Use the
    // app's real font for layout checks; these assets are only served by tests.
    final font = FontLoader('Roboto');
    font.addFont(
      kIsWeb
          ? rootBundle.load('fonts/roboto-regular.ttf')
          : File('test/assets/fonts/roboto-regular.ttf')
                .readAsBytes()
                .then(ByteData.sublistView),
    );
    await font.load();
  });

  for (final width in <double>[378, 520, 768, 839, 840, 1440]) {
    testWidgets('shell navigation and resizing at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 759);
      addTearDown(tester.view.reset);
      final repository = _LayoutRepository();
      addTearDown(repository.dispose);
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      final expectedWidth = kIsWeb && width > 520 ? 520.0 : width;
      final shell = find.byType(Scaffold);
      expect(tester.getSize(shell), Size(expectedWidth, 759));
      expect(tester.getTopLeft(shell).dx, (width - expectedWidth) / 2);
      expect(
        MediaQuery.sizeOf(tester.element(shell)),
        Size(expectedWidth, 759),
      );
      final nativeDesktop = !kIsWeb && width >= 840;
      expect(
        find.byType(NavigationRail),
        nativeDesktop ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(AppBottomNavigation),
        nativeDesktop ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Kalender'));
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 2);
      expect(tester.takeException(), isNull);

      // Resize across the old breakpoint without recreating the app or tab state.
      tester.view.physicalSize = const Size(378, 759);
      await tester.pumpAndSettle();
      expect(tester.getSize(shell), const Size(378, 759));
      expect(find.byType(NavigationRail), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('pushed form, modal and dialog stay inside the app viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final repository = _LayoutRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mulai Lembur'));
    await tester.pumpAndSettle();
    final form = find.byType(OvertimeFormPage);
    final expectedWidth = kIsWeb ? 520.0 : 1440.0;
    expect(tester.getSize(form).width, expectedWidth);
    expect(tester.getTopLeft(form).dx, (1440 - expectedWidth) / 2);
    expect(MediaQuery.sizeOf(tester.element(form)).width, expectedWidth);
    expect(find.text('Simpan Lembur'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final context = tester.element(form);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SizedBox(
        key: ValueKey('sheet'),
        width: double.infinity,
        height: 200,
      ),
    );
    await tester.pumpAndSettle();
    final sheetRect = tester.getRect(find.byKey(const ValueKey('sheet')));
    final appRect = tester.getRect(form);
    expect(sheetRect.left, greaterThanOrEqualTo(appRect.left));
    expect(sheetRect.right, lessThanOrEqualTo(appRect.right));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('Dialog')),
    );
    await tester.pumpAndSettle();
    final dialogRect = tester.getRect(find.byType(AlertDialog));
    expect(dialogRect.left, greaterThanOrEqualTo(appRect.left));
    expect(dialogRect.right, lessThanOrEqualTo(appRect.right));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('viewport preserves safe areas, keyboard and text scaling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    const original = MediaQueryData(
      size: Size(1440, 900),
      padding: EdgeInsets.only(top: 24),
      viewPadding: EdgeInsets.only(top: 24, bottom: 16),
      viewInsets: EdgeInsets.only(bottom: 300),
      textScaler: TextScaler.linear(1.3),
    );
    late MediaQueryData actual;
    await tester.pumpWidget(
      MediaQuery(
        data: original,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppViewport(
            child: Builder(
              builder: (context) {
                actual = MediaQuery.of(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    expect(actual, original.copyWith(size: Size(kIsWeb ? 520 : 1440, 900)));
    expect(tester.takeException(), isNull);
  });
}

Widget _app(_LayoutRepository repository) => MaterialApp(
  theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
  builder: AppViewport.builder,
  home: AppShell(
    authController: _LayoutAuthController(),
    overtimeRepository: repository,
    photoProcessingService: PhotoProcessingService(),
  ),
);

class _LayoutAuthController extends Fake implements AuthController {
  @override
  AuthUser get user => const AuthUser(
    id: 'layout-test',
    name: 'Pegawai',
    email: 'layout@example.test',
    roles: [],
  );
}

// Exercise the actual pages without network, authentication or database writes.
class _LayoutRepository extends ChangeNotifier implements OvertimeRepository {
  @override
  final SyncStatus syncStatus = SyncStatus()..apiReachable = true;

  @override
  Future<void> activateUser(String ownerId) async {}

  @override
  Future<void> retryBlockedSync() async {}

  @override
  Future<void> syncNow({
    int? historyMonth,
    bool refreshSnapshots = true,
  }) async {}

  @override
  Future<List<DraftOvertime>> fetchDrafts() async => [];

  @override
  Future<YearOvertimeSummary> fetchYearOvertimeSummary() async =>
      const YearOvertimeSummary.empty();

  @override
  Future<List<CalendarOvertime>> fetchCalendarEntries() async => [];

  @override
  Future<OvertimeHistory> fetchHistory({int? month}) async => OvertimeHistory(
    records: [],
    month: month ?? DateTime.now().month,
    totalUpah: 0,
    totalOvertime: 0,
    workdayOvertime: 0,
    holidayOvertime: 0,
  );

  @override
  void dispose() {
    syncStatus.dispose();
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
