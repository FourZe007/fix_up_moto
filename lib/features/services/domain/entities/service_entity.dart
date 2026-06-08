import 'package:equatable/equatable.dart';

/// A repair or maintenance service offered by the shop.
class ServiceEntity extends Equatable {
  final String id;
  final String name;
  final String description;

  /// Category identifier — links to [ServiceCategoryEntity].
  final String categoryId;

  /// Display price in the local currency (e.g. 450.00).
  final double price;

  /// Estimated service duration in minutes.
  final int durationMinutes;

  /// URL for the service's thumbnail image shown on the card.
  final String? imageUrl;

  /// Whether this service is currently accepting new bookings.
  final bool isAvailable;

  const ServiceEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.price,
    required this.durationMinutes,
    this.imageUrl,
    this.isAvailable = true,
  });

  @override
  List<Object?> get props => [
        id, name, description, categoryId,
        price, durationMinutes, imageUrl, isAvailable,
      ];
}
