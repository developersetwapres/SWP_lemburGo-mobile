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
    final source = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _PhotoSourceSheet(),
    );
    if (!mounted || source == null) return;
    if (source.source == ImageSource.gallery &&
        source.mode == PhotoStampMode.manual) {
      final picked = await widget.photoService.pickImage(
        source: ImageSource.gallery,
      );
      if (!mounted || picked == null) return;
      final manual = await showModalBottomSheet<ManualTimestampData>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (_) => const _ManualTimestampSheet(),
      );
      if (!mounted || manual == null) return;
      final message = await _controller.processPickedPhoto(
        slot: slot,
        picked: picked,
        mode: source.mode,
        manualData: manual,
      );
      if (mounted && message != null) _showPhotoError(message, slot);
      return;
    }
    await _processPhoto(slot, source.source, source.mode, null);
  }

  Future<void> _processPhoto(
    PhotoSlot slot,
    ImageSource source,
    PhotoStampMode mode,
    ManualTimestampData? manual,
  ) async {
    final message = await _controller.addPhoto(
      slot: slot,
      source: source,
      mode: mode,
      manualData: manual,
    );
    if (!mounted || message == null) return;
    _showPhotoError(message, slot);
  }

  void _showPhotoError(String message, PhotoSlot slot) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Manual',
          onPressed: () => _choosePhoto(slot),
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
        centerTitle: false,
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
                subtitle: 'Wajib • timestamp dibakar permanen',
              ),
              const SizedBox(height: 14),
              _photoSection(
                PhotoSlot.activity,
                'Tambah Foto Kegiatan',
                _controller.errors['foto_kegiatan'],
              ),
              const SizedBox(height: 30),
              const SectionHeader(
                title: 'Foto Presensi Pulang',
                subtitle: 'Wajib • waktu pulang berasal dari timestamp',
              ),
              const SizedBox(height: 14),
              _photoSection(
                PhotoSlot.checkout,
                'Tambah Foto Pulang',
                _controller.errors['foto_pulang'],
              ),
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
                        'Pastikan foto memperlihatkan kegiatan dan presensi pulang dengan jelas.',
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
                ? 'Mengirim laporan...'
                : 'Kirim Laporan Lembur',
            icon: _controller.isSubmitting ? null : Icons.send_rounded,
            isLoading: _controller.isSubmitting,
            onPressed: _controller.isSubmitting ? null : _submit,
          ),
        ),
      ),
    ),
  );

  Widget _photoSection(PhotoSlot slot, String label, String? error) {
    final photo = _controller.photoFor(slot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhotoUploadCard(
          label: label,
          photoFile: photo?.file,
          timestampLabel: photo == null
              ? null
              : DateFormat(
                  'dd MMM yyyy • HH:mm',
                  'id_ID',
                ).format(photo.timestamp),
          modeLabel: photo?.mode == PhotoStampMode.manual
              ? 'TIMESTAMP MANUAL'
              : 'AUTO TIMESTAMP',
          isProcessing: _controller.isProcessing(slot),
          onTap: () => _choosePhoto(slot),
          onRemove: () => _controller.removePhoto(slot),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 7),
            child: Text(
              error,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
      ],
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

class _PhotoChoice {
  const _PhotoChoice(this.source, this.mode);
  final ImageSource source;
  final PhotoStampMode mode;
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tambah Foto', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Setiap foto akan memiliki timestamp permanen.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _OptionTile(
            icon: Icons.camera_alt_rounded,
            title: 'Ambil Foto',
            subtitle: 'Kamera belakang dengan timestamp otomatis',
            onTap: () => Navigator.pop(
              context,
              const _PhotoChoice(ImageSource.camera, PhotoStampMode.automatic),
            ),
          ),
          _OptionTile(
            icon: Icons.photo_library_outlined,
            title: 'Galeri • waktu & lokasi sekarang',
            subtitle: 'Gunakan foto yang sudah ada dengan timestamp otomatis',
            onTap: () => Navigator.pop(
              context,
              const _PhotoChoice(ImageSource.gallery, PhotoStampMode.automatic),
            ),
          ),
          _OptionTile(
            icon: Icons.edit_location_alt_outlined,
            title: 'Galeri • atur timestamp manual',
            subtitle: 'Tentukan tanggal, waktu, dan alamat sendiri',
            onTap: () => Navigator.pop(
              context,
              const _PhotoChoice(ImageSource.gallery, PhotoStampMode.manual),
            ),
          ),
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
  final String title, subtitle;
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
  Widget build(BuildContext context) => Padding(
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
          Text(
            'Atur Timestamp Manual',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Informasi ini akan dibakar ke foto.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(DateFormat('dd MMM y', 'id_ID').format(_date)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectTime,
                  icon: const Icon(Icons.access_time_rounded),
                  label: Text(_time.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _road,
            decoration: const InputDecoration(
              labelText: 'Nama jalan',
              hintText: 'Jl. Kebon Sirih No. 14',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _districtCity,
            decoration: const InputDecoration(
              labelText: 'Kecamatan, Kota/Kabupaten',
              hintText: 'Menteng, Jakarta Pusat',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _province,
            decoration: const InputDecoration(
              labelText: 'Provinsi',
              hintText: 'DKI Jakarta',
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Gunakan Timestamp Ini',
            icon: Icons.check_rounded,
            onPressed: _save,
          ),
        ],
      ),
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
    if (_road.text.trim().isEmpty ||
        _districtCity.text.trim().isEmpty ||
        _province.text.trim().isEmpty) {
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
            'Laporan berhasil disimpan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Laporan lembur Anda telah dikirim.',
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
