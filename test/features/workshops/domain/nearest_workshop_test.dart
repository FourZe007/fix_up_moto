import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/geo.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/domain/nearest_workshop.dart';

WorkshopEntity workshop(
  String name,
  double lat,
  double lng, {
  bool active = true,
}) => WorkshopEntity(
  branch: '31',
  shop: name,
  bsName: 'FIXUP MOTO - $name',
  bsAddress: 'JL. CONTOH',
  operationalHours: 'Senin - Jumat 08.00 - 16.00',
  phoneNo: '0312345678',
  active: active,
  lat: lat,
  lng: lng,
);

void main() {
  // Roughly where the branches are.
  final kutisari = workshop('KUTISARI', -7.3166, 112.7527);
  final darmo = workshop('DARMO', -7.2950, 112.6850);
  final gedangan = workshop('GEDANGAN', -7.3773, 112.7292);
  final malang = workshop('MALANG', -7.9700, 112.6600);

  // Where a member might be.
  const nearGedangan = GeoPoint(-7.3800, 112.7300);
  const inMalang = GeoPoint(-7.9500, 112.6300);
  const nearDarmo = GeoPoint(-7.2900, 112.6800);

  group('nearestWorkshop', () {
    final all = [kutisari, darmo, gedangan, malang];

    test('is the workshop closest to the member', () {
      expect(nearestWorkshop(all, nearGedangan), gedangan);
      expect(nearestWorkshop(all, nearDarmo), darmo);
      expect(nearestWorkshop(all, inMalang), malang);
    });

    test('does not depend on the order of the list', () {
      expect(nearestWorkshop(all.reversed.toList(), nearGedangan), gedangan);
      expect(nearestWorkshop([malang, gedangan, darmo], nearDarmo), darmo);
    });

    test('is the only workshop, if there is only one', () {
      expect(nearestWorkshop([malang], nearGedangan), malang);
    });

    test('is null for an empty list', () {
      expect(nearestWorkshop(const [], nearGedangan), isNull);
    });

    test('skips an inactive workshop, even the closest', () {
      final closedGedangan = workshop(
        'GEDANGAN',
        -7.3773,
        112.7292,
        active: false,
      );

      expect(
        nearestWorkshop([kutisari, closedGedangan, darmo], nearGedangan),
        kutisari,
      );
    });

    test('is null when none is active', () {
      final shut = [
        workshop('A', -7.3, 112.7, active: false),
        workshop('B', -7.9, 112.6, active: false),
      ];

      expect(nearestWorkshop(shut, nearGedangan), isNull);
    });

    test('skips a workshop with no real coordinates (0,0)', () {
      final unknown = workshop('KOSONG', 0, 0);

      // 0,0 would be "closest" to a member abroad; it must not count at all.
      expect(nearestWorkshop([unknown, malang], const GeoPoint(-1, 1)), malang);
      expect(nearestWorkshop([unknown], nearGedangan), isNull);
    });

    test('skips coordinates that are out of range or not numbers', () {
      final broken = [
        workshop('SATU', 200, 10),
        workshop('DUA', double.nan, 10),
      ];

      expect(nearestWorkshop([...broken, kutisari], nearGedangan), kutisari);
    });

    test('keeps the list order on a tie', () {
      final first = workshop('PERTAMA', -7.3, 112.7);
      final second = workshop('KEDUA', -7.3, 112.7);

      expect(nearestWorkshop([first, second], nearGedangan), first);
      expect(nearestWorkshop([second, first], nearGedangan), second);
    });

    test('is null when the member position is not a real one', () {
      expect(nearestWorkshop(all, const GeoPoint(0, 0)), isNull);
      expect(nearestWorkshop(all, const GeoPoint(double.nan, 1)), isNull);
    });
  });

  group('workshopDistanceKm', () {
    test('is the straight line between the member and the workshop', () {
      expect(
        workshopDistanceKm(darmo, nearDarmo),
        distanceKm(nearDarmo, GeoPoint(darmo.lat, darmo.lng)),
      );
    });

    test('is null when either end is unknown', () {
      expect(workshopDistanceKm(darmo, null), isNull);
      expect(workshopDistanceKm(darmo, const GeoPoint(0, 0)), isNull);
      expect(workshopDistanceKm(workshop('KOSONG', 0, 0), nearDarmo), isNull);
      expect(workshopDistanceKm(workshop('RUSAK', 200, 10), nearDarmo), isNull);
    });
  });

  group('sortByDistance', () {
    // As the server might send them: in no useful order.
    final all = [kutisari, darmo, gedangan, malang];

    List<String> names(List<WorkshopEntity> workshops) => [
      for (final w in workshops) w.shop,
    ];

    test('puts the nearest first and the furthest last', () {
      expect(sortByDistance(all, nearGedangan), [
        gedangan,
        kutisari,
        darmo,
        malang,
      ]);
      expect(sortByDistance(all, inMalang).first, malang);
      expect(sortByDistance(all.reversed.toList(), nearGedangan), [
        gedangan,
        kutisari,
        darmo,
        malang,
      ]);
    });

    test('puts closed workshops at the bottom, nearest of them first', () {
      final shutNear = workshop('TUTUP-DEKAT', -7.38, 112.73, active: false);
      final shutFar = workshop('TUTUP-JAUH', -7.97, 112.63, active: false);

      expect(
        names(sortByDistance([shutFar, malang, shutNear, darmo], nearGedangan)),
        ['DARMO', 'MALANG', 'TUTUP-DEKAT', 'TUTUP-JAUH'],
      );
    });

    test('puts one it cannot place after the others of its kind', () {
      final unknown = workshop('KOSONG', 0, 0);
      final shut = workshop('TUTUP', -7.38, 112.73, active: false);
      final shutUnknown = workshop('TUTUP-KOSONG', 0, 0, active: false);

      expect(
        names(
          sortByDistance([shutUnknown, unknown, shut, malang], nearGedangan),
        ),
        ['MALANG', 'KOSONG', 'TUTUP', 'TUTUP-KOSONG'],
      );
    });

    test('keeps the list order for equal places, in a long list too', () {
      // Long enough that the sort is no longer the kind that happens to keep
      // equal items in order.
      final same = [for (var i = 0; i < 50; i++) workshop('$i', -7.3, 112.7)];
      final unknown = [for (var i = 50; i < 100; i++) workshop('$i', 0, 0)];

      expect(sortByDistance([...same, ...unknown], nearGedangan), [
        ...same,
        ...unknown,
      ]);
    });

    test('leaves the list as it came without a real position', () {
      final mixed = [
        workshop('TUTUP', -7.3, 112.7, active: false),
        malang,
        darmo,
      ];

      for (final from in [
        null,
        const GeoPoint(0, 0),
        const GeoPoint(double.nan, 1),
      ]) {
        expect(sortByDistance(mixed, from), mixed);
      }
    });

    test('does not change the list it is given', () {
      final given = List.of(all);

      sortByDistance(given, nearGedangan);

      expect(given, all);
    });

    test('is empty for an empty list', () {
      expect(sortByDistance(const [], nearGedangan), isEmpty);
    });

    test('starts with the workshop a booking defaults to', () {
      final mixed = [
        workshop('TUTUP', -7.38, 112.73, active: false),
        workshop('KOSONG', 0, 0),
        ...all,
      ];

      for (final here in [nearGedangan, nearDarmo, inMalang]) {
        expect(sortByDistance(mixed, here).first, nearestWorkshop(mixed, here));
      }
    });
  });

  group('firstActiveWorkshop', () {
    test('is the first one that can be picked', () {
      final closed = workshop('TUTUP', -7.3, 112.7, active: false);

      expect(firstActiveWorkshop([closed, darmo, kutisari]), darmo);
    });

    test('ignores where anything is', () {
      expect(firstActiveWorkshop([malang, kutisari]), malang);
      expect(firstActiveWorkshop([workshop('KOSONG', 0, 0)])?.shop, 'KOSONG');
    });

    test('is null for an empty list or when none is active', () {
      expect(firstActiveWorkshop(const []), isNull);
      expect(firstActiveWorkshop([workshop('A', 1, 1, active: false)]), isNull);
    });
  });
}
