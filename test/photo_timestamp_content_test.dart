import 'package:flutter_test/flutter_test.dart';
import 'package:kmz_lemburgo_mobile/features/overtime/data/models/photo_stamp.dart';

void main() {
  test('formats the same camera timestamp content for preview and image', () {
    final content = PhotoTimestampContent(
      timestamp: DateTime(2026, 9, 5, 8, 4, 9),
      address: const DeviceAddress(
        road: 'Jalan Merdeka Selatan No. 5',
        districtCity: 'Gambir, Jakarta Pusat',
        province: 'DKI Jakarta',
      ),
    );

    expect(content.dateLabel, '05 SEPTEMBER 2026');
    expect(content.timeLabel, '08:04:09 WIB');
    expect(content.addressLines, [
      'Jalan Merdeka Selatan No. 5',
      'Gambir, Jakarta Pusat',
      'DKI Jakarta',
    ]);
  });
}
