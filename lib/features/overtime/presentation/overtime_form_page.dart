import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/photo_upload_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';

class OvertimeFormPage extends StatefulWidget {
  const OvertimeFormPage({super.key});
  @override
  State<OvertimeFormPage> createState() => _OvertimeFormPageState();
}

class _OvertimeFormPageState extends State<OvertimeFormPage> {
  final _activityController = TextEditingController();
  final _locationController = TextEditingController();
  bool _showErrors = false,
      _isSaving = false,
      _hasActivityPhoto = false,
      _hasCheckoutPhoto = false;
  bool get _canSubmit =>
      _activityController.text.trim().isNotEmpty &&
      _locationController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _activityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    if (!_canSubmit) return;
    setState(() => _isSaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengajuan tersimpan sebagai draft (dummy UI).'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectPhoto(bool isActivity) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih sumber foto',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Simulasi UI — foto belum disimpan ke perangkat.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _SourceTile(
              icon: Icons.camera_alt_rounded,
              title: 'Kamera',
              subtitle: 'Ambil foto sekarang',
              onTap: () => _mockPhoto(isActivity),
            ),
            _SourceTile(
              icon: Icons.photo_library_outlined,
              title: 'Galeri',
              subtitle: 'Pilih foto dari perangkat',
              onTap: () => _mockPhoto(isActivity),
            ),
          ],
        ),
      ),
    ),
  );

  void _mockPhoto(bool isActivity) {
    Navigator.pop(context);
    setState(() {
      if (isActivity) {
        _hasActivityPhoto = true;
      } else {
        _hasCheckoutPhoto = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
            const _DateCard(),
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
              errorText: _showErrors && _activityController.text.trim().isEmpty
                  ? 'Nama kegiatan wajib diisi'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _locationController,
              label: 'Lokasi Kegiatan',
              hint: 'Contoh: Ruang Server Setwapres',
              icon: Icons.location_on_outlined,
              textInputAction: TextInputAction.done,
              errorText: _showErrors && _locationController.text.trim().isEmpty
                  ? 'Lokasi kegiatan wajib diisi'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 30),
            const SectionHeader(
              title: 'Foto Kegiatan',
              subtitle: 'Tambahkan foto saat kegiatan berlangsung',
            ),
            const SizedBox(height: 14),
            PhotoUploadCard(
              label: 'Ambil Foto Kegiatan',
              hasPhoto: _hasActivityPhoto,
              timestamp: '1 Sep 2026, 18.24 WIB',
              onTap: () => _selectPhoto(true),
            ),
            const SizedBox(height: 30),
            const SectionHeader(
              title: 'Foto Presensi Pulang',
              subtitle: 'Waktu pulang akan tercatat dari foto',
            ),
            const SizedBox(height: 14),
            PhotoUploadCard(
              label: 'Ambil Foto Pulang',
              hasPhoto: _hasCheckoutPhoto,
              timestamp: '1 Sep 2026, 21.08 WIB',
              onTap: () => _selectPhoto(false),
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
                      'Data dapat disimpan terlebih dahulu dan dilengkapi kembali nanti.',
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
          label: _isSaving ? 'Menyimpan...' : 'Simpan Pengajuan',
          icon: _isSaving ? null : Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _canSubmit ? _submit : null,
        ),
      ),
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
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
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.skyBlueLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppColors.skyBlue),
    ),
    title: Text(title),
    subtitle: Text(subtitle),
    onTap: onTap,
  );
}

class _DateCard extends StatelessWidget {
  const _DateCard();
  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.skyBlueLight,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: const Row(
      children: [
        _CalendarBadge(),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tanggal Kegiatan',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              SizedBox(height: 3),
              Text(
                'Selasa, 1 September 2026',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.lock_outline_rounded, color: AppColors.muted, size: 19),
      ],
    ),
  );
}

class _CalendarBadge extends StatelessWidget {
  const _CalendarBadge();
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(13),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'SEP',
          style: TextStyle(
            color: AppColors.skyBlue,
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
        Text(
          '01',
          style: TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            height: 1,
          ),
        ),
      ],
    ),
  );
}
