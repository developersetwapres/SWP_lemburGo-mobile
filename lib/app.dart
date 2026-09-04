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
import 'shared/widgets/app_logo.dart';

class LemburNakITApp extends StatefulWidget {
  const LemburNakITApp({super.key});

  @override
  State<LemburNakITApp> createState() => _LemburNakITAppState();
}

class _LemburNakITAppState extends State<LemburNakITApp> {
  AuthController? _authController;
  OvertimeRepository? _overtimeRepository;
  PhotoProcessingService? _photoProcessingService;

  bool _initialized = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final storage = TokenStorage();
      final apiClient = await ApiClient.create(storage);

      final authController = AuthController(
        AuthRepository(apiClient.dio, apiClient, storage),
      );

      final overtimeRepository = OvertimeRepository(apiClient.dio, apiClient);

      final photoProcessingService = PhotoProcessingService();

      if (!mounted) {
        authController.dispose();
        return;
      }

      setState(() {
        _authController = authController;
        _overtimeRepository = overtimeRepository;
        _photoProcessingService = photoProcessingService;
        _initialized = true;
      });

      _authController!.restoreSession();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _initializationError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _authController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      if (_initializationError != null) {
        return MaterialApp(
          title: 'LemburNakIT',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: _InitializationError(
            message: _initializationError!,
            onRetry: () {
              setState(() {
                _initializationError = null;
              });
              _initializeApp();
            },
          ),
        );
      }

      return const MaterialApp(
        title: 'LemburNakIT',
        debugShowCheckedModeBanner: false,
        home: _SessionSplash(),
      );
    }

    return MaterialApp(
      title: 'LemburNakIT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AnimatedBuilder(
        animation: _authController!,
        builder: (context, _) {
          if (_authController!.isCheckingSession) {
            return const _SessionSplash();
          }

          if (_authController!.user == null) {
            return LoginPage(controller: _authController!);
          }

          return AppShell(
            authController: _authController!,
            overtimeRepository: _overtimeRepository!,
            photoProcessingService: _photoProcessingService!,
          );
        },
      ),
    );
  }
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
          onSessionExpired: widget.authController.expireSession,
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
          onLogout: widget.authController.logout,
          onSessionExpired: widget.authController.expireSession,
        ),
        HistoryPage(
          repository: widget.overtimeRepository,
          onEdit: _openOvertimeForm,
          onSessionExpired: widget.authController.expireSession,
          isActive: _selectedIndex == 1,
        ),
        CalendarPage(
          controller: _calendarController,
          onSessionExpired: widget.authController.expireSession,
          isActive: _selectedIndex == 2,
        ),
      ],
    ),
    bottomNavigationBar: AppBottomNavigation(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
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
          AppLogo(size: 104),
          SizedBox(height: 20),
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Menyiapkan LemburNakIT',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _InitializationError extends StatelessWidget {
  const _InitializationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Gagal menyiapkan aplikasi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    ),
  );
}
