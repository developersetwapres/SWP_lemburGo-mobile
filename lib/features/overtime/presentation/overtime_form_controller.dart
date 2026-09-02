import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../data/models/photo_stamp.dart';
import '../data/overtime_repository.dart';
import '../data/services/location_service.dart';
import '../data/services/photo_processing_service.dart';

class OvertimeFormController extends ChangeNotifier {
  OvertimeFormController(this._repository, this._photoService);
  final OvertimeRepository _repository;
  final PhotoProcessingService _photoService;
  DateTime activityDate = DateTime.now();
  String activityName = '', location = '';
  StampedPhoto? activityPhoto, checkoutPhoto;
  PhotoSlot? processingSlot;
  bool isSubmitting = false, showValidation = false;
  String? generalError;
  Map<String, String> errors = {};

  bool get canSubmit =>
      activityName.trim().isNotEmpty &&
      location.trim().isNotEmpty &&
      activityPhoto != null &&
      checkoutPhoto != null &&
      !isSubmitting &&
      processingSlot == null;
  StampedPhoto? photoFor(PhotoSlot slot) =>
      slot == PhotoSlot.activity ? activityPhoto : checkoutPhoto;
  bool isProcessing(PhotoSlot slot) => processingSlot == slot;

  void setActivityName(String value) {
    activityName = value;
    _clearError('nama_kegiatan');
    notifyListeners();
  }

  void setLocation(String value) {
    location = value;
    _clearError('lokasi_kegiatan');
    notifyListeners();
  }

  void setActivityDate(DateTime value) {
    activityDate = value;
    _clearError('tanggal_kegiatan');
    notifyListeners();
  }

  void removePhoto(PhotoSlot slot) {
    if (slot == PhotoSlot.activity) {
      activityPhoto = null;
    } else {
      checkoutPhoto = null;
    }
    _clearError(slot == PhotoSlot.activity ? 'foto_kegiatan' : 'foto_pulang');
    notifyListeners();
  }

  Future<String?> addPhoto({
    required PhotoSlot slot,
    required ImageSource source,
    required PhotoStampMode mode,
    ManualTimestampData? manualData,
  }) async {
    final picked = await _photoService.pickImage(source: source);
    if (picked == null) {
      return null;
    }
    return processPickedPhoto(
      slot: slot,
      picked: picked,
      mode: mode,
      manualData: manualData,
    );
  }

  Future<String?> processPickedPhoto({
    required PhotoSlot slot,
    required XFile picked,
    required PhotoStampMode mode,
    ManualTimestampData? manualData,
  }) async {
    processingSlot = slot;
    generalError = null;
    notifyListeners();
    try {
      final photo = mode == PhotoStampMode.manual
          ? await _photoService.createManualStamp(
              source: picked,
              data: manualData!,
            )
          : await _photoService.createAutomaticStamp(picked);
      if (slot == PhotoSlot.activity) {
        activityPhoto = photo;
      } else {
        checkoutPhoto = photo;
      }
      _clearError(slot == PhotoSlot.activity ? 'foto_kegiatan' : 'foto_pulang');
      return null;
    } on LocationException catch (error) {
      return error.message;
    } on PhotoProcessingException catch (error) {
      return error.message;
    } catch (_) {
      return 'Foto belum dapat diproses. Silakan coba lagi.';
    } finally {
      processingSlot = null;
      notifyListeners();
    }
  }

  Future<SubmitOutcome> submit() async {
    showValidation = true;
    errors = _localErrors();
    notifyListeners();
    if (errors.isNotEmpty) return SubmitOutcome.validation;
    isSubmitting = true;
    generalError = null;
    notifyListeners();
    try {
      await _repository.submit(
        date: activityDate,
        activityName: activityName.trim(),
        location: location.trim(),
        activityPhoto: activityPhoto!,
        checkoutPhoto: checkoutPhoto!,
      );
      return SubmitOutcome.success;
    } on ApiException catch (error) {
      generalError = error.message;
      if (error.fieldErrors.isNotEmpty) {
        errors = _mapServerErrors(error.fieldErrors);
      }
      notifyListeners();
      return error.isUnauthenticated
          ? SubmitOutcome.unauthenticated
          : SubmitOutcome.failure;
    } catch (_) {
      generalError = 'Laporan belum dapat dikirim. Silakan coba lagi.';
      notifyListeners();
      return SubmitOutcome.failure;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Map<String, String> _localErrors() {
    final result = <String, String>{};
    if (activityName.trim().isEmpty) {
      result['nama_kegiatan'] = 'Nama kegiatan wajib diisi';
    }
    if (location.trim().isEmpty) {
      result['lokasi_kegiatan'] = 'Lokasi kegiatan wajib diisi';
    }
    if (activityPhoto == null) {
      result['foto_kegiatan'] = 'Foto kegiatan wajib ditambahkan';
    }
    if (checkoutPhoto == null) {
      result['foto_pulang'] = 'Foto presensi pulang wajib ditambahkan';
    }
    return result;
  }

  Map<String, String> _mapServerErrors(Map<String, List<String>> fieldErrors) {
    const aliases = {
      'foto_kegiatan_at': 'foto_kegiatan',
      'foto_pulang_at': 'foto_pulang',
    };
    final mapped = <String, String>{};
    fieldErrors.forEach((field, messages) {
      final target = aliases[field] ?? field;
      if (messages.isNotEmpty && !mapped.containsKey(target)) {
        mapped[target] = messages.first;
      }
    });
    return mapped;
  }

  void _clearError(String field) {
    if (errors.containsKey(field)) errors = Map.of(errors)..remove(field);
  }
}

enum SubmitOutcome { success, validation, unauthenticated, failure }
