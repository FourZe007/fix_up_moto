import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/geo.dart';

void main() {
  // City centres, near enough for a distance check.
  const surabaya = GeoPoint(-7.2575, 112.7521);
  const sidoarjo = GeoPoint(-7.4478, 112.7183);
  const malang = GeoPoint(-7.9666, 112.6326);

  group('distanceKm', () {
    test('is zero from a point to itself', () {
      expect(distanceKm(surabaya, surabaya), 0);
    });

    test('is the same both ways', () {
      expect(
        distanceKm(surabaya, malang),
        closeTo(distanceKm(malang, surabaya), 1e-9),
      );
    });

    test('knows Surabaya to Sidoarjo, about 21 km', () {
      expect(distanceKm(surabaya, sidoarjo), closeTo(21.5, 1));
    });

    test('knows Surabaya to Malang, about 80 km in a straight line', () {
      expect(distanceKm(surabaya, malang), closeTo(80, 2));
    });

    test('is one degree of longitude at the equator: 111.2 km', () {
      expect(
        distanceKm(const GeoPoint(0.5, 100), const GeoPoint(0.5, 101)),
        closeTo(111.2 * math.cos(0.5 * math.pi / 180), 0.2),
      );
    });

    test('knows London to Paris, about 343 km', () {
      expect(
        distanceKm(
          const GeoPoint(51.5074, -0.1278),
          const GeoPoint(48.8566, 2.3522),
        ),
        closeTo(343.5, 2),
      );
    });

    test('goes the short way across the date line', () {
      expect(
        distanceKm(const GeoPoint(0.5, 179.5), const GeoPoint(0.5, -179.5)),
        lessThan(120),
      );
    });

    test('does not blow up for opposite points on the earth', () {
      final km = distanceKm(
        const GeoPoint(0.5, 0.5),
        const GeoPoint(-0.5, -179.5),
      );
      expect(km.isFinite, isTrue);
      expect(km, closeTo(20015, 20));
    });
  });

  group('GeoPoint.isValid', () {
    test('accepts a real place', () {
      expect(surabaya.isValid, isTrue);
    });

    test(
      'rejects 0,0, which is what a record with no coordinates can become',
      () {
        expect(const GeoPoint(0, 0).isValid, isFalse);
      },
    );

    test('accepts a place on the equator or the meridian alone', () {
      expect(const GeoPoint(0, 112.7).isValid, isTrue);
      expect(const GeoPoint(-7.2, 0).isValid, isTrue);
    });

    test('rejects what is out of range', () {
      expect(const GeoPoint(91, 10).isValid, isFalse);
      expect(const GeoPoint(-91, 10).isValid, isFalse);
      expect(const GeoPoint(10, 181).isValid, isFalse);
      expect(const GeoPoint(10, -181).isValid, isFalse);
    });

    test('rejects NaN and infinity', () {
      expect(const GeoPoint(double.nan, 10).isValid, isFalse);
      expect(const GeoPoint(10, double.nan).isValid, isFalse);
      expect(const GeoPoint(double.infinity, 10).isValid, isFalse);
    });
  });

  group('GeoPoint equality', () {
    test('is by value', () {
      expect(const GeoPoint(1, 2), const GeoPoint(1, 2));
      expect(const GeoPoint(1, 2), isNot(const GeoPoint(1, 3)));
      expect(const GeoPoint(1, 2).hashCode, const GeoPoint(1, 2).hashCode);
    });

    test('prints nothing about where it is, so a log cannot leak it', () {
      expect(
        const GeoPoint(-7.2575, 112.7521).toString(),
        isNot(contains('7.25')),
      );
      expect(
        const GeoPoint(-7.2575, 112.7521).toString(),
        isNot(contains('112')),
      );
    });
  });
}
