import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/photo_upload_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../data/models/photo_stamp.dart';
import '../data/overtime_repository.dart';
import '../data/services/photo_processing_service.dart';
import 'overtime_form_controller.dart';

class OvertimeFormPage extends StatefulWidget {
  const OvertimeFormPage({
    required this.repository,
    required this.photoService,
    required this.onSessionExpired,
    super.key,
  });

  final OvertimeRepository repository;
  final PhotoProcessingService photoService;
  final Future<void> Function() onSessionExpired;

  @override
  State<OvertimeFormPage> createState() => _OvertimeFormPageState();
}

class _OvertimeFormPageState extends State<OvertimeFormPage> {
  late final OvertimeFormController _controller;
  late final TextEditingController _activityController;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _controller = OvertimeFormController(
      widget.repository,
      widget.photoService,
    );
    _activityController = TextEditingController();
    _locationController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _activityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto(PhotoSlot slot) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _PhotoSourceSheet(),
    );
    if (!mounted || source == null) return;

    final picked = await _controller.pickPhoto(slot: slot, source: source);
    if (!mounted || picked == null) return;

    // Camera intentionally defaults to automatic: one tap after capture gives
    // the most useful result, while its preview still permits a later change.
    final mode = source == ImageSource.camera
        ? PhotoStampMode.automatic
        : await _chooseTimestampMode();
    if (!mounted || mode == null) return;
    await _applyTimestamp(slot: slot, photo: picked, mode: mode);
  }

  Future<void> _changeTimestamp(PhotoSlot slot) async {
    final photo = _controller.photoFor(slot);
    if (photo == null || photo.mode == PhotoStampMode.existingTimestamp) return;
    final mode = await _chooseTimestampMode();
    if (!mounted || mode == null) return;
    await _applyTimestamp(
      slot: slot,
      photo: XFile(photo.sourceFile.path),
      mode: mode,
    );
  }

  Future<PhotoStampMode?> _chooseTimestampMode() =>
      showModalBottomSheet<PhotoStampMode>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (_) => const _TimestampModeSheet(),
      );

  Future<void> _applyTimestamp({
    required PhotoSlot slot,
    required XFile photo,
    required PhotoStampMode mode,
  }) async {
    ManualTimestampData? manualData;
    DateTime? existingTimestamp;
    if (mode == PhotoStampMode.manual) {
      manualData = await showModalBottomSheet<ManualTimestampData>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (_) => const _ManualTimestampSheet(),
      );
      if (!mounted || manualData == null) return;
    }
    if (mode == PhotoStampMode.existingTimestamp) {
      existingTimestamp = await showModalBottomSheet<DateTime>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (_) => const _ExistingTimestampSheet(),
      );
      if (!mounted || existingTimestamp == null) return;
    }
    final message = await _controller.processPickedPhoto(
      slot: slot,
      picked: photo,
      mode: mode,
      manualData: manualData,
      existingTimestamp: existingTimestamp,
    );
    if (mounted && message != null) {
      _showPhotoError(message, slot, photo);
    }
  }

  void _showPhotoError(String message, PhotoSlot slot, XFile photo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Atur Manual',
          onPressed: () => _applyTimestamp(
            slot: slot,
            photo: photo,
            mode: PhotoStampMode.manual,
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final outcome = await _controller.submit();
    if (!mounted) return;
    if (outcome == SubmitOutcome.unauthenticated) {
      await widget.onSessionExpired();
      return;
    }
    if (outcome == SubmitOutcome.success) {
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: AppColors.surface,
        builder: (context) =>
            _SuccessSheet(onClose: () => Navigator.pop(context)),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (outcome == SubmitOutcome.failure && _controller.generalError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.generalError!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Mulai Lembur'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 124),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catat kegiatan lembur Anda',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              _DateCard(
                date: _controller.activityDate,
                error: _controller.errors['tanggal_kegiatan'],
                onTap: _pickDate,
              ),
              const SizedBox(height: 28),
              const SectionHeader(
                title: 'Detail kegiatan',
                subtitle: 'Isi informasi dasar lembur Anda',
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _activityController,
                label: 'Nama Kegiatan / Acara',
                hint: 'Contoh: Monitoring jaringan',
                icon: Icons.event_note_outlined,
                textInputAction: TextInputAction.next,
                errorText: _controller.errors['nama_kegiatan'],
                onChanged: _controller.setActivityName,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _locationController,
                label: 'Lokasi Kegiatan',
                hint: 'Contoh: Ruang Server Setwapres',
                icon: Icons.location_on_outlined,
                textInputAction: TextInputAction.done,
                errorText: _controller.errors['lokasi_kegiatan'],
                onChanged: _controller.setLocation,
              ),
              const SizedBox(height: 30),
              const SectionHeader(
                title: 'Foto Kegiatan',
                subtitle: 'Opsional • dapat dilengkapi kemudian',
              ),
              const SizedBox(height: 14),
              _photoSection(PhotoSlot.activity, 'Tambah Foto Kegiatan'),
              const SizedBox(height: 30),
              const SectionHeader(
                title: 'Foto Presensi Pulang',
                subtitle: 'Opsional • waktu pulang dari timestamp foto',
              ),
              const SizedBox(height: 14),
              _photoSection(PhotoSlot.checkout, 'Tambah Foto Presensi Pulang'),
              const SizedBox(height: 30),
              AppCard(
                color: AppColors.warningLight,
                padding: const EdgeInsets.all(16),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.warning),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Simpan detail kegiatan terlebih dahulu. Foto dapat ditambahkan saat melanjutkan laporan.',
                        style: TextStyle(color: AppColors.navy, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: PrimaryButton(
            label: _controller.isSubmitting
                ? 'Menyimpan lembur...'
                : 'Simpan Lembur',
            icon: _controller.isSubmitting ? null : Icons.save_outlined,
            isLoading: _controller.isSubmitting,
            onPressed: _controller.canSubmit ? _submit : null,
          ),
        ),
      ),
    ),
  );

  Widget _photoSection(PhotoSlot slot, String label) {
    final photo = _controller.photoFor(slot);
    return PhotoUploadCard(
      label: label,
      photoFile: photo?.file,
      timestampLabel: photo == null
          ? null
          : DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(photo.timestamp),
      modeLabel: switch (photo?.mode) {
        PhotoStampMode.manual => 'MANUAL TIMESTAMP',
        PhotoStampMode.existingTimestamp => 'TIMESTAMP DARI FOTO',
        _ => 'AUTO TIMESTAMP',
      },
      isProcessing: _controller.isProcessing(slot),
      onTap: () => _choosePhoto(slot),
      onRemove: () => _controller.removePhoto(slot),
      onChangeTimestamp: photo?.mode == PhotoStampMode.existingTimestamp
          ? null
          : () => _changeTimestamp(slot),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _controller.activityDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) _controller.setActivityDate(picked);
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.date,
    required this.error,
    required this.onTap,
  });
  final DateTime date;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AppCard(
          color: AppColors.skyBlueLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  DateFormat('dd\nMMM', 'id_ID').format(date).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.skyBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tanggal Kegiatan',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('EEEE, d MMMM y', 'id_ID').format(date),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.edit_calendar_outlined,
                color: AppColors.skyBlue,
                size: 21,
              ),
            ],
          ),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 7),
          child: Text(
            error!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ),
    ],
  );
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();
  @override
  Widget build(BuildContext context) => _SheetScaffold(
    title: 'Tambah Foto',
    subtitle: 'Pilih sumber foto terlebih dahulu.',
    children: [
      _OptionTile(
        icon: Icons.camera_alt_rounded,
        title: 'Ambil dari Kamera',
        subtitle: 'Gunakan kamera belakang perangkat',
        onTap: () => Navigator.pop(context, ImageSource.camera),
      ),
      _OptionTile(
        icon: Icons.photo_library_outlined,
        title: 'Pilih dari Galeri',
        subtitle: 'Gunakan foto yang sudah ada',
        onTap: () => Navigator.pop(context, ImageSource.gallery),
      ),
    ],
  );
}

class _TimestampModeSheet extends StatelessWidget {
  const _TimestampModeSheet();
  @override
  Widget build(BuildContext context) => _SheetScaffold(
    title: 'Timestamp Foto',
    subtitle: 'Tentukan informasi yang digunakan pada foto ini.',
    children: [
      _OptionTile(
        icon: Icons.my_location_rounded,
        title: 'Otomatis',
        subtitle: 'Gunakan waktu dan lokasi perangkat saat ini',
        onTap: () => Navigator.pop(context, PhotoStampMode.automatic),
      ),
      _OptionTile(
        icon: Icons.edit_calendar_outlined,
        title: 'Atur Manual',
        subtitle: 'Tentukan tanggal, waktu, dan alamat sendiri',
        onTap: () => Navigator.pop(context, PhotoStampMode.manual),
      ),
      _OptionTile(
        icon: Icons.verified_outlined,
        title: 'Foto sudah memiliki timestamp',
        subtitle: 'Gunakan foto apa adanya tanpa menambahkan timestamp baru',
        onTap: () => Navigator.pop(context, PhotoStampMode.existingTimestamp),
      ),
    ],
  );
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.skyBlueLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppColors.skyBlue),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    onTap: onTap,
  );
}

class _ManualTimestampSheet extends StatefulWidget {
  const _ManualTimestampSheet();
  @override
  State<_ManualTimestampSheet> createState() => _ManualTimestampSheetState();
}

class _ManualTimestampSheetState extends State<_ManualTimestampSheet> {
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  final _road = TextEditingController();
  final _districtCity = TextEditingController();
  final _province = TextEditingController();

  @override
  void dispose() {
    _road.dispose();
    _districtCity.dispose();
    _province.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _TimestampFormShell(
    title: 'Atur Timestamp Manual',
    subtitle: 'Informasi ini akan dibakar permanen ke foto.',
    date: _date,
    time: _time,
    onDate: _selectDate,
    onTime: _selectTime,
    fields: [
      _locationField(_road, 'Nama jalan', 'Jl. Kebon Sirih No. 14'),
      _locationField(
        _districtCity,
        'Kecamatan, Kota/Kabupaten',
        'Menteng, Jakarta Pusat',
      ),
      _locationField(_province, 'Provinsi', 'DKI Jakarta'),
    ],
    buttonLabel: 'Gunakan Timestamp Ini',
    onSave: _save,
  );

  Widget _locationField(
    TextEditingController controller,
    String label,
    String hint,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
  Future<void> _selectDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _selectTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null) setState(() => _time = value);
  }

  void _save() {
    if ([
      _road,
      _districtCity,
      _province,
    ].any((controller) => controller.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi alamat untuk timestamp manual.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      ManualTimestampData(
        dateTime: DateTime(
          _date.year,
          _date.month,
          _date.day,
          _time.hour,
          _time.minute,
        ),
        address: DeviceAddress(
          road: _road.text.trim(),
          districtCity: _districtCity.text.trim(),
          province: _province.text.trim(),
        ),
      ),
    );
  }
}

class _ExistingTimestampSheet extends StatefulWidget {
  const _ExistingTimestampSheet();
  @override
  State<_ExistingTimestampSheet> createState() =>
      _ExistingTimestampSheetState();
}

class _ExistingTimestampSheetState extends State<_ExistingTimestampSheet> {
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  @override
  Widget build(BuildContext context) => _TimestampFormShell(
    title: 'Waktu Foto',
    subtitle: 'Waktu ini dikirim ke laporan tanpa mengubah tampilan foto.',
    date: _date,
    time: _time,
    onDate: _selectDate,
    onTime: _selectTime,
    fields: const [],
    buttonLabel: 'Gunakan Waktu Ini',
    onSave: () => Navigator.pop(
      context,
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
    ),
  );
  Future<void> _selectDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _selectTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null) setState(() => _time = value);
  }
}

class _TimestampFormShell extends StatelessWidget {
  const _TimestampFormShell({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.time,
    required this.onDate,
    required this.onTime,
    required this.fields,
    required this.buttonLabel,
    required this.onSave,
  });
  final String title, subtitle, buttonLabel;
  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onDate, onTime, onSave;
  final List<Widget> fields;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),

            const SizedBox(height: 6),

            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(DateFormat('dd MMM y', 'id_ID').format(date)),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTime,
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text(time.format(context)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            ...fields,

            const SizedBox(height: 8),

            PrimaryButton(
              label: buttonLabel,
              icon: Icons.check_rounded,
              onPressed: onSave,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({required this.onClose});
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Lembur berhasil disimpan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Anda dapat melengkapi foto kegiatan dan presensi pada tahap berikutnya.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          PrimaryButton(label: 'Kembali ke Home', onPressed: onClose),
        ],
      ),
    ),
  );
}
