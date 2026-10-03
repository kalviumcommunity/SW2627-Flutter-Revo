import '../core/enums/revo_enums.dart';

class Venue {
  final String venueId;
  final String name;
  final String location;
  final int capacity;
  final Map<String, dynamic> availability;
  final VenueStatus status;

  Venue({
    required this.venueId,
    required this.name,
    required this.location,
    required this.capacity,
    required this.availability,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'venueId': venueId,
      'name': name,
      'location': location,
      'capacity': capacity,
      'availability': availability,
      'status': status.name,
    };
  }

  factory Venue.fromMap(Map<String, dynamic> map, String id) {
    return Venue(
      venueId: id,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      capacity: map['capacity'] ?? 0,
      availability: Map<String, dynamic>.from(map['availability'] ?? {}),
      status: VenueStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => VenueStatus.active,
      ),
    );
  }
}

class VenueInput {
  final String name;
  final String location;
  final int capacity;
  final Map<String, dynamic> availability;

  VenueInput({
    required this.name,
    required this.location,
    required this.capacity,
    required this.availability,
  });
}

class TimeRange {
  final DateTime startAt;
  final DateTime endAt;

  TimeRange({required this.startAt, required this.endAt});
}
