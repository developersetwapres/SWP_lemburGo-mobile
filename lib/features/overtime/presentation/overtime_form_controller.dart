import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../data/models/draft_overtime.dart';
import '../data/models/photo_stamp.dart';
import '../data/overtime_repository.dart';
import '../data/services/location_service.dart';
import '../data/services/photo_processing_service.dart';

class OvertimeFormController extends ChangeNotifier {
  OvertimeFormController(this._repository, this._photoService, {this.draft}) {
    if (draft != null) {
      activityDate = draft!.activityDate;
      activityName = draft!.activityName;
      location = draft!.location;
      _photoStates[PhotoSlot.activity] = draft!.hasActivityPhoto
          ? PhotoInputState.ready
          : PhotoInputState.empty;
      _photoStates[PhotoSlot.checkout] = draft!.hasCheckoutPhoto
          ? PhotoInputState.ready
          : PhotoInputState.empty;
    }
  }

  final OvertimeRepository _repository;
  final PhotoProcessingService _photoService;
  final DraftOvertime? draft;

  DateTime activityDate = DateTime.now();
  String activityName = '', location = '';
  StampedPhoto? activityPhoto, checkoutPhoto;
  final _photoStates = <PhotoSlot, PhotoInputState>{
    PhotoSlot.activity: PhotoInputState.empty,
    PhotoSlot.checkout: PhotoInputState.empty,
  };
  bool isSubmitting = false;
  String? generalError;
  String? successMessage;
  Map<String, String> errors = {};

  bool get canSubmit =>
      activityName.trim().isNotEmpty &&
      location.trim().isNotEmpty &&
      !isSubmitting &&
      !_photoStates.values.contains(PhotoInputState.timestampProcessing);

  StampedPhoto? photoFor(PhotoSlot slot) =>
      slot == PhotoSlot.activity ? activityPhoto : checkoutPhoto;

  String? existingPhotoUrlFor(PhotoSlot slot) => switch (slot) {
    PhotoSlot.activity => draft?.activityPhotoUrl,
    PhotoSlot.checkout => draft?.checkoutPhotoUrl,
  };

  String? existingPhotoLocalPathFor(PhotoSlot slot) => switch (slot) {
    PhotoSlot.activity => draft?.activityPhotoLocalPath,
    PhotoSlot.checkout => draft?.checkoutPhotoLocalPath,
  };

  DateTime? existingPhotoTimestampFor(PhotoSlot slot) => switch (slot) {
    PhotoSlot.activity => draft?.activityPhotoAt,
    PhotoSlot.checkout => draft?.checkoutPhotoAt,
  };

  bool hasPhotoFor(PhotoSlot slot) =>
      photoFor(slot) != null ||
      existingPhotoUrlFor(slot) != null ||
      existingPhotoLocalPathFor(slot) != null;

  PhotoInputState stateFor(PhotoSlot slot) =>
      _photoStates[slot] ?? PhotoInputState.empty;

  bool isProcessing(PhotoSlot slot) =>
      stateFor(slot) == PhotoInputState.timestampProcessing;

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

  Future<XFile?> pickPhoto({
    required PhotoSlot slot,
    required ImageSource source,
  }) async {
    _photoStates[slot] = PhotoInputState.sourceSelected;
    notifyListeners();
    try {
      final picked = await _photoService.pickImage(source: source);
      _photoStates[slot] = picked == null
          ? (hasPhotoFor(slot) ? PhotoInputState.ready : PhotoInputState.empty)
          : PhotoInputState.photoSelected;
      return picked;
    } catch (_) {
      _photoStates[slot] = PhotoInputState.error;
      return null;
    } finally {
      notifyListeners();
    }
  }

  /// The timestamp camera returns a JPEG that already has its visible preview
  /// stamp permanently embedded. It should not enter the normal post-picker
  /// automatic processing path a second time.
  void setAutomaticCameraPhoto({
    required PhotoSlot slot,
    required StampedPhoto photo,
  }) {
    if (slot == PhotoSlot.activity) {
      activityPhoto = photo;
    } else {
      checkoutPhoto = photo;
    }
    _photoStates[slot] = PhotoInputState.ready;
    _clearError(slot == PhotoSlot.activity ? 'foto_kegiatan' : 'foto_pulang');
    notifyListeners();
  }

  void removePhoto(PhotoSlot slot) {
    if (slot == PhotoSlot.activity) {
      activityPhoto = null;
    } else {
      checkoutPhoto = null;
    }
    _photoStates[slot] = PhotoInputState.empty;
    _clearError(slot == PhotoSlot.activity ? 'foto_kegiatan' : 'foto_pulang');
    notifyListeners();
  }

  Future<String?> processPickedPhoto({
    required PhotoSlot slot,
    required XFile picked,
    required PhotoStampMode mode,
    ManualTimestampData? manualData,
    DateTime? existingTimestamp,
  }) async {
    _photoStates[slot] = PhotoInputState.timestampProcessing;
    generalError = null;
    notifyListeners();
    try {
      final photo = switch (mode) {
        PhotoStampMode.automatic => await _photoService.createAutomaticStamp(
          picked,
        ),
        PhotoStampMode.manual => await _photoService.createManualStamp(
          source: picked,
          data: manualData!,
        ),
        PhotoStampMode.existingTimestamp =>
          await _photoService.keepExistingTimestamp(
            source: picked,
            timestamp: existingTimestamp!,
          ),
      };
      if (slot == PhotoSlot.activity) {
        activityPhoto = photo;
      } else {
        checkoutPhoto = photo;
      }
      _photoStates[slot] = PhotoInputState.ready;
      _clearError(slot == PhotoSlot.activity ? 'foto_kegiatan' : 'foto_pulang');
      return null;
    } on LocationException catch (error) {
      _photoStates[slot] = PhotoInputState.error;
      return error.message;
    } on PhotoProcessingException catch (error) {
      _photoStates[slot] = PhotoInputState.error;
      return error.message;
    } catch (_) {
      _photoStates[slot] = PhotoInputState.error;
      return 'Foto belum dapat diproses. Silakan coba lagi.';
    } finally {
      notifyListeners();
    }
  }

  Future<SubmitOutcome> submit() async {
    errors = _localErrors();
    notifyListeners();
    if (errors.isNotEmpty) return SubmitOutcome.validation;

    isSubmitting = true;
    generalError = null;
    successMessage = null;
    notifyListeners();
    try {
      if (draft != null) {
        successMessage = await _repository.update(
          draft: draft!,
          date: activityDate,
          activityName: activityName.trim(),
          location: location.trim(),
          newActivityPhoto: activityPhoto,
          newCheckoutPhoto: checkoutPhoto,
        );
      } else {
        successMessage = await _repository.submit(
          date: activityDate,
          activityName: activityName.trim(),
          location: location.trim(),
          activityPhoto: activityPhoto,
          checkoutPhoto: checkoutPhoto,
        );
      }
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
