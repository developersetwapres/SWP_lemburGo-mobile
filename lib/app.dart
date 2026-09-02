import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/calendar/presentation/calendar_controller.dart';
import 'features/calendar/presentation/calendar_page.dart';
import 'features/dashboard/presentation/home_page.dart';
import 'features/history/presentation/history_page.dart';
import 'features/overtime/data/models/draft_overtime.dart';
import 'features/overtime/data/overtime_repository.dart';
import 'features/overtime/data/services/photo_processing_service.dart';
import 'features/overtime/presentation/overtime_form_page.dart';
import 'shared/widgets/app_bottom_navigation.dart';

class LemburInApp extends StatefulWidget {
  const LemburInApp({super.key});
  @override
  State<LemburInApp> createState() => _LemburInAppState();
}

class _LemburInAppState extends State<LemburInApp> {
  late final AuthController _authController;
  late final OvertimeRepository _overtimeRepository;
  late final PhotoProcessingService _photoProcessingService;

  @override
  void initState() {
    super.initState();
    final storage = TokenStorage();
    final apiClient = ApiClient(storage);
    _authController = AuthController(
      AuthRepository(apiClient.dio, apiClient, storage),
    );
    _overtimeRepository = OvertimeRepository(apiClient.dio, apiClient);
    _photoProcessingService = PhotoProcessingService();
    _authController.restoreSession();
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LemburIN',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        if (_authController.isCheckingSession) return const _SessionSplash();
        if (_authController.user == null) {
          return LoginPage(controller: _authController);
        }
        return AppShell(
          authController: _authController,
          overtimeRepository: _overtimeRepository,
          photoProcessingService: _photoProcessingService,
        );
      },
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.authController,
    required this.overtimeRepository,
    required this.photoProcessingService,
    super.key,
  });
  final AuthController authController;
  final OvertimeRepository overtimeRepository;
  final PhotoProcessingService photoProcessingService;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late final CalendarController _calendarController;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController(widget.overtimeRepository);
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  Future<bool> _openOvertimeForm([DraftOvertime? draft]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OvertimeFormPage(
          repository: widget.overtimeRepository,
          photoService: widget.photoProcessingService,
          onSessionExpired: widget.authController.logout,
          draft: draft,
        ),
      ),
    );
    return saved ?? false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selectedIndex,
      children: [
        HomePage(
          user: widget.authController.user!,
          repository: widget.overtimeRepository,
          onStart: _openOvertimeForm,
          onContinue: _openOvertimeForm,
          onSessionExpired: widget.authController.logout,
        ),
        CalendarPage(
          controller: _calendarController,
          onSessionExpired: widget.authController.logout,
          isActive: _selectedIndex == 1,
        ),
        HistoryPage(
          repository: widget.overtimeRepository,
          onEdit: _openOvertimeForm,
          onSessionExpired: widget.authController.logout,
          isActive: _selectedIndex == 2,
        ),
      ],
    ),
    bottomNavigationBar: AppBottomNavigation(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
    ),
  );
}

class _SessionSplash extends StatelessWidget {
  const _SessionSplash();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppGlyph(),
          SizedBox(height: 20),
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Menyiapkan LemburIN', style: TextStyle(color: AppColors.muted)),
        ],
      ),
    ),
  );
}

class _AppGlyph extends StatelessWidget {
  const _AppGlyph();
  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.skyBlue, AppColors.skyBlueDark],
      ),
      borderRadius: BorderRadius.circular(21),
    ),
    child: const Icon(Icons.timelapse_rounded, color: Colors.white, size: 34),
  );
}
