import 'dart:async';
import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/rehearsal.dart';
import '../models/venue.dart';
import 'mock_data_service.dart';
import 'venue_repository.dart';

/// In-memory mock implementation of [VenueRepository] (FR-06, Issue #13).
/// Backed by the shared [MockDataService] singleton to guarantee cross-screen
/// data consistency without exposing concrete mock dependencies to presentation components.
class MockVenueRepository implements VenueRepository {
  static final MockVenueRepository _instance =
      MockVenueRepository._internal();

  factory MockVenueRepository({MockDataService? dataService}) {
    if (dataService != null) {
      return MockVenueRepository._custom(dataService);
    }
    return _instance;
  }

  final MockDataService _dataService;

  MockVenueRepository._internal() : _dataService = MockDataService();
  MockVenueRepository._custom(this._dataService);

  @override
  Stream<List<Venue>> watchVenues({bool activeOnly = false}) async* {
    yield await getVenues(activeOnly: activeOnly);
    yield* _dataService.watchVenues().map((list) {
      if (activeOnly) {
        return list.where((v) => v.status == VenueStatus.active).toList();
      }
      return list;
    });
  }

  @override
  Future<List<Venue>> getVenues({bool activeOnly = false}) async {
    final all = _dataService.getVenuesSync();
    if (activeOnly) {
      return all.where((v) => v.status == VenueStatus.active).toList();
    }
    return all;
  }

  @override
  Future<Venue?> getVenue(String venueId) async {
    return _dataService.getVenueById(venueId);
  }

  @override
  Future<Venue> createVenue(VenueInput input) async {
    if (input.name.trim().isEmpty) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Venue name cannot be empty.',
      );
    }
    return _dataService.createVenue(input);
  }

  @override
  Future<void> updateVenue(String venueId, VenueInput input) async {
    final existing = _dataService.getVenueById(venueId);
    if (existing == null) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Venue $venueId not found.',
      );
    }

    await _dataService.updateVenue(
      venueId: venueId,
      input: input,
    );
  }

  @override
  Future<void> deleteVenue(String venueId) async {
    final existing = _dataService.getVenueById(venueId);
    if (existing == null) {
      throw RevoException(RevoErrorCode.notFound, 'Venue $venueId not found.');
    }
    await _dataService.deleteVenue(venueId);
  }

  @override
  Future<void> toggleStatus(String venueId) async {
    final existing = _dataService.getVenueById(venueId);
    if (existing == null) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Venue $venueId not found.',
      );
    }
    await _dataService.toggleVenueStatus(venueId);
  }

  @override
  Future<List<Rehearsal>> getRehearsalsForVenue(String venueId) async {
    return _dataService.getRehearsalsForVenue(venueId);
  }

  @override
  Future<String> getProductionName(String productionId) async {
    return _dataService.getProductionById(productionId)?.name ?? 'Unknown Production';
  }

  @override
  Future<List<TimeRange>> getBookings(String venueId, DateTime day) async {
    final rehearsals = _dataService.getRehearsalsForVenue(venueId);
    return rehearsals
        .where((r) =>
            r.startAt.year == day.year &&
            r.startAt.month == day.month &&
            r.startAt.day == day.day &&
            r.status == RehearsalStatus.confirmed)
        .map((r) => TimeRange(startAt: r.startAt, endAt: r.endAt))
        .toList();
  }
}
