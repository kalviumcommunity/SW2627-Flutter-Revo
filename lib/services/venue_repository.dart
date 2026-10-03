import '../models/venue.dart';

abstract class VenueRepository {
  Stream<List<Venue>> watchVenues({bool activeOnly = true});
  Future<Venue> getVenue(String venueId);
  Future<Venue> createVenue(VenueInput input); // Admin
  Future<void> updateVenue(String venueId, VenueInput input); // Admin
  Future<List<TimeRange>> getBookings(String venueId, DateTime day); // confirmed rehearsals that day
}
