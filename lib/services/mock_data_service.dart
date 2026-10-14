import 'dart:async';
import '../core/enums/revo_enums.dart';
import '../models/app_user.dart';
import '../models/cast_assignment.dart';
import '../models/director_interview_record.dart';
import '../models/production.dart';
import '../models/production_role.dart';
import '../models/rehearsal.dart';
import '../models/venue.dart';

/// Centralized Mock Data Service for Revo Theatre Production Management System.
/// Maintains realistic fictional entities with cross-referential integrity,
/// dynamic metric computations, and role-scoped queries (Issue #13).
class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;

  final List<Production> _productions = [];
  final List<Venue> _venues = [];
  final List<Rehearsal> _rehearsals = [];
  final List<ProductionRole> _roles = [];
  final List<CastAssignment> _castAssignments = [];
  DirectorInterviewRecord _interviewRecord =
      DirectorInterviewRecord.emptyTemplate();

  final _productionsStreamController =
      StreamController<List<Production>>.broadcast();
  final _venuesStreamController = StreamController<List<Venue>>.broadcast();
  final _rehearsalsStreamController =
      StreamController<List<Rehearsal>>.broadcast();

  MockDataService._internal() {
    _seedInitialData();
  }

  void _seedInitialData() {
    final now = DateTime.now();

    // ── 1. Seed Productions ──────────────────────────────────────────────────
    _productions.addAll([
      Production(
        productionId: 'prod_101',
        name: 'The Crucible',
        description:
            'Arthur Miller’s historical dramatization of the Salem witch trials and community hysteria.',
        directorId: 'usr_dir_101', // Sarah Jenkins
        startDate: now.subtract(const Duration(days: 20)),
        endDate: now.add(const Duration(days: 40)),
        status: ProductionStatus.rehearsing,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      Production(
        productionId: 'prod_102',
        name: 'A Midsummer Night’s Dream',
        description:
            'Shakespearean comedy featuring four young Athenian lovers and a troupe of amateur actors controlled by forest fairies.',
        directorId: 'usr_dir_101', // Sarah Jenkins
        startDate: now.add(const Duration(days: 15)),
        endDate: now.add(const Duration(days: 75)),
        status: ProductionStatus.planning,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Production(
        productionId: 'prod_103',
        name: 'Hamlet',
        description:
            'Shakespearean tragedy depicting the grief and moral dilemma of Prince Hamlet seeking revenge for his father’s murder.',
        directorId: 'usr_dir_102', // Marcus Vance
        startDate: now.add(const Duration(days: 30)),
        endDate: now.add(const Duration(days: 90)),
        status: ProductionStatus.casting,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Production(
        productionId: 'prod_104',
        name: 'The Glass Menagerie',
        description:
            'Tennessee Williams’ delicate memory play examining family vulnerability and shattered illusions.',
        directorId: 'usr_dir_103', // Clara Oswald
        startDate: now.subtract(const Duration(days: 60)),
        endDate: now.subtract(const Duration(days: 10)),
        status: ProductionStatus.completed,
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
    ]);

    // ── 2. Seed Venues ───────────────────────────────────────────────────────
    _venues.addAll([
      Venue(
        venueId: 'ven_101',
        name: 'Main Stage Auditorium',
        location: 'Main Complex — Level 1',
        capacity: 350,
        availability: {'status': 'active', 'audioSystem': 'Line-array 48ch'},
        status: VenueStatus.active,
      ),
      Venue(
        venueId: 'ven_102',
        name: 'Studio A Rehearsal Hall',
        location: 'Arts Wing — Room 204',
        capacity: 45,
        availability: {'status': 'active', 'sprungFloor': true, 'mirrors': true},
        status: VenueStatus.active,
      ),
      Venue(
        venueId: 'ven_103',
        name: 'Studio B Black Box',
        location: 'Arts Wing — Room 102',
        capacity: 30,
        availability: {'status': 'active', 'flexibleSeating': true},
        status: VenueStatus.active,
      ),
      Venue(
        venueId: 'ven_104',
        name: 'Green Room Lab',
        location: 'Basement Facility B-12',
        capacity: 15,
        availability: {'status': 'maintenance', 'notes': 'A/C repair until Friday'},
        status: VenueStatus.inactive,
      ),
    ]);

    // ── 3. Seed Roles & Cast Assignments ─────────────────────────────────────
    _roles.addAll([
      ProductionRole(
        roleId: 'role_101',
        productionId: 'prod_101',
        name: 'John Proctor',
        description: 'Protagonist farmer upright in character and conscience.',
        status: RoleStatus.assigned,
      ),
      ProductionRole(
        roleId: 'role_102',
        productionId: 'prod_101',
        name: 'Abigail Williams',
        description: 'Antagonist leader of the accusers.',
        status: RoleStatus.assigned,
      ),
      ProductionRole(
        roleId: 'role_103',
        productionId: 'prod_101',
        name: 'Elizabeth Proctor',
        description: 'Wife of John Proctor, steadfast and solemn.',
        status: RoleStatus.open,
      ),
      ProductionRole(
        roleId: 'role_104',
        productionId: 'prod_102',
        name: 'Puck (Robin Goodfellow)',
        description: 'Mischievous fairy serving King Oberon.',
        status: RoleStatus.assigned,
      ),
      ProductionRole(
        roleId: 'role_105',
        productionId: 'prod_103',
        name: 'Hamlet',
        description: 'Prince of Denmark.',
        status: RoleStatus.open,
      ),
    ]);

    _castAssignments.addAll([
      CastAssignment(
        assignmentId: 'asgn_101',
        productionId: 'prod_101',
        roleId: 'role_101',
        castMemberId: 'usr_cast_201', // Alex Rivera
        assignedAt: now.subtract(const Duration(days: 12)),
        status: AssignmentStatus.active,
      ),
      CastAssignment(
        assignmentId: 'asgn_102',
        productionId: 'prod_101',
        roleId: 'role_102',
        castMemberId: 'usr_cast_202', // Maya Lin
        assignedAt: now.subtract(const Duration(days: 10)),
        status: AssignmentStatus.active,
      ),
      CastAssignment(
        assignmentId: 'asgn_103',
        productionId: 'prod_102',
        roleId: 'role_104',
        castMemberId: 'usr_cast_202', // Maya Lin
        assignedAt: now.subtract(const Duration(days: 4)),
        status: AssignmentStatus.active,
      ),
    ]);

    // ── 4. Seed Rehearsals ───────────────────────────────────────────────────
    _rehearsals.addAll([
      Rehearsal(
        rehearsalId: 'reh_101',
        productionId: 'prod_101',
        venueId: 'ven_102', // Studio A
        startAt: now.add(const Duration(days: 1, hours: 2)),
        endAt: now.add(const Duration(days: 1, hours: 5)),
        participantIds: ['usr_cast_201', 'usr_cast_202'],
        status: RehearsalStatus.confirmed,
        clientPending: false,
        createdBy: 'usr_dir_101',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Rehearsal(
        rehearsalId: 'reh_102',
        productionId: 'prod_101',
        venueId: 'ven_101', // Main Stage
        startAt: now.add(const Duration(days: 3, hours: 4)),
        endAt: now.add(const Duration(days: 3, hours: 7)),
        participantIds: ['usr_cast_201'],
        status: RehearsalStatus.confirmed,
        clientPending: false,
        createdBy: 'usr_dir_101',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Rehearsal(
        rehearsalId: 'reh_103',
        productionId: 'prod_102',
        venueId: 'ven_103', // Studio B
        startAt: now.add(const Duration(days: 5, hours: 1)),
        endAt: now.add(const Duration(days: 5, hours: 4)),
        participantIds: ['usr_cast_202'],
        status: RehearsalStatus.proposed,
        clientPending: false,
        createdBy: 'usr_dir_101',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Rehearsal(
        rehearsalId: 'reh_104',
        productionId: 'prod_103',
        venueId: 'ven_101', // Main Stage
        startAt: now.add(const Duration(days: 6, hours: 3)),
        endAt: now.add(const Duration(days: 6, hours: 6)),
        participantIds: [],
        status: RehearsalStatus.proposed,
        clientPending: false,
        createdBy: 'usr_dir_102',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ]);

    _notifyAll();
  }

  void _notifyAll() {
    _productionsStreamController.add(List.unmodifiable(_productions));
    _venuesStreamController.add(List.unmodifiable(_venues));
    _rehearsalsStreamController.add(List.unmodifiable(_rehearsals));
  }

  // ── Production Operations ──────────────────────────────────────────────────

  /// Returns reactive stream of productions scoped to the user role:
  /// - Director: sees only productions where `directorId == user.userId`
  /// - Admin: sees all theatre productions
  Stream<List<Production>> watchProductionsForUser(AppUser user) {
    if (user.role == UserRole.director) {
      return _productionsStreamController.stream.map(
        (list) => list.where((p) => p.directorId == user.userId).toList(),
      );
    }
    return _productionsStreamController.stream;
  }

  List<Production> getProductionsForUserSync(AppUser user) {
    if (user.role == UserRole.director) {
      return _productions.where((p) => p.directorId == user.userId).toList();
    }
    return List.unmodifiable(_productions);
  }

  Production? getProductionById(String id) {
    try {
      return _productions.firstWhere((p) => p.productionId == id);
    } catch (_) {
      return null;
    }
  }

  Future<Production> createProduction({
    required ProductionInput input,
    required String directorId,
  }) async {
    final now = DateTime.now();
    final newId = 'prod_${now.millisecondsSinceEpoch}';
    final prod = Production(
      productionId: newId,
      name: input.name,
      description: input.description,
      directorId: directorId,
      startDate: input.startDate,
      endDate: input.endDate,
      status: input.status,
      createdAt: now,
      updatedAt: now,
    );
    _productions.insert(0, prod);
    _notifyAll();
    return prod;
  }

  Future<void> updateProduction({
    required String productionId,
    required ProductionInput input,
  }) async {
    final idx = _productions.indexWhere((p) => p.productionId == productionId);
    if (idx != -1) {
      final old = _productions[idx];
      _productions[idx] = Production(
        productionId: old.productionId,
        name: input.name,
        description: input.description,
        directorId: old.directorId,
        startDate: input.startDate,
        endDate: input.endDate,
        status: input.status,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
      _notifyAll();
    }
  }

  // ── Venue Operations ───────────────────────────────────────────────────────

  Stream<List<Venue>> watchVenues() {
    return _venuesStreamController.stream;
  }

  List<Venue> getVenuesSync() {
    return List.unmodifiable(_venues);
  }

  Venue? getVenueById(String id) {
    try {
      return _venues.firstWhere((v) => v.venueId == id);
    } catch (_) {
      return null;
    }
  }

  Future<Venue> createVenue(VenueInput input) async {
    final newId = 'ven_${DateTime.now().millisecondsSinceEpoch}';
    final venue = Venue(
      venueId: newId,
      name: input.name,
      location: input.location,
      capacity: input.capacity,
      availability: input.availability,
      status: VenueStatus.active,
    );
    _venues.add(venue);
    _notifyAll();
    return venue;
  }

  Future<void> updateVenue({
    required String venueId,
    required VenueInput input,
    VenueStatus? status,
  }) async {
    final idx = _venues.indexWhere((v) => v.venueId == venueId);
    if (idx != -1) {
      final old = _venues[idx];
      _venues[idx] = Venue(
        venueId: old.venueId,
        name: input.name,
        location: input.location,
        capacity: input.capacity,
        availability: input.availability,
        status: status ?? old.status,
      );
      _notifyAll();
    }
  }

  // ── Rehearsal & Related Operations ─────────────────────────────────────────

  List<Rehearsal> getRehearsalsForProduction(String productionId) {
    return _rehearsals
        .where((r) =>
            r.productionId == productionId &&
            r.status != RehearsalStatus.cancelled)
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  List<Rehearsal> getRehearsalsForVenue(String venueId) {
    return _rehearsals
        .where((r) =>
            r.venueId == venueId && r.status != RehearsalStatus.cancelled)
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  List<ProductionRole> getRolesForProduction(String productionId) {
    return _roles.where((r) => r.productionId == productionId).toList();
  }

  ProductionRole? getRoleById(String roleId) {
    try {
      return _roles.firstWhere((r) => r.roleId == roleId);
    } catch (_) {
      return null;
    }
  }

  List<CastAssignment> getCastAssignmentsForProduction(String productionId) {
    return _castAssignments
        .where((a) =>
            a.productionId == productionId &&
            a.status == AssignmentStatus.active)
        .toList();
  }

  List<Venue> getVenuesForProduction(String productionId) {
    final venueIds = _rehearsals
        .where((r) =>
            r.productionId == productionId &&
            r.status != RehearsalStatus.cancelled)
        .map((r) => r.venueId)
        .toSet();
    return _venues.where((v) => venueIds.contains(v.venueId)).toList();
  }

  String getUserName(String userId) {
    switch (userId) {
      case 'usr_dir_101':
        return 'Sarah Jenkins';
      case 'usr_dir_102':
        return 'Marcus Vance';
      case 'usr_dir_103':
        return 'Clara Oswald';
      case 'usr_cast_201':
        return 'Alex Rivera';
      case 'usr_cast_202':
        return 'Maya Lin';
      case 'usr_admin_301':
        return 'Theatre Admin';
      default:
        return 'Team Member ($userId)';
    }
  }

  String getDirectorName(String directorId) => getUserName(directorId);

  Future<void> toggleVenueStatus(String venueId) async {
    final idx = _venues.indexWhere((v) => v.venueId == venueId);
    if (idx != -1) {
      final old = _venues[idx];
      final nextStatus = old.status == VenueStatus.active
          ? VenueStatus.inactive
          : VenueStatus.active;
      _venues[idx] = Venue(
        venueId: old.venueId,
        name: old.name,
        location: old.location,
        capacity: old.capacity,
        availability: old.availability,
        status: nextStatus,
      );
      _notifyAll();
    }
  }

  // ── Metrics & Organization Summaries ───────────────────────────────────────

  Map<String, dynamic> getAdminMetrics() {
    final activeProds = _productions.where((p) =>
        p.status == ProductionStatus.rehearsing ||
        p.status == ProductionStatus.casting ||
        p.status == ProductionStatus.planning).length;

    final activeVenues =
        _venues.where((v) => v.status == VenueStatus.active).length;

    final upcomingRehearsals = _rehearsals
        .where((r) =>
            r.status != RehearsalStatus.cancelled &&
            r.startAt.isAfter(DateTime.now()))
        .length;

    // Distinct assigned cast members
    final uniqueCast = _castAssignments
        .where((a) => a.status == AssignmentStatus.active)
        .map((a) => a.castMemberId)
        .toSet()
        .length;

    return {
      'totalProductions': _productions.length,
      'activeProductions': activeProds,
      'totalVenues': _venues.length,
      'activeVenues': activeVenues,
      'upcomingRehearsals': upcomingRehearsals,
      'totalCastMembers': uniqueCast,
    };
  }

  Map<String, dynamic> getDirectorMetrics(String directorId) {
    final myProds =
        _productions.where((p) => p.directorId == directorId).toList();
    final myProdIds = myProds.map((p) => p.productionId).toSet();

    final myRehearsals = _rehearsals
        .where((r) =>
            myProdIds.contains(r.productionId) &&
            r.status != RehearsalStatus.cancelled)
        .toList();

    final myCastCount = _castAssignments
        .where((a) =>
            myProdIds.contains(a.productionId) &&
            a.status == AssignmentStatus.active)
        .map((a) => a.castMemberId)
        .toSet()
        .length;

    return {
      'myProductionsCount': myProds.length,
      'rehearsalsCount': myRehearsals.length,
      'castCount': myCastCount,
      'primaryProduction': myProds.isNotEmpty ? myProds.first : null,
    };
  }

  // ── Interview & Baseline Record Operations ─────────────────────────────────

  DirectorInterviewRecord getInterviewRecord() => _interviewRecord;

  void saveInterviewRecord(DirectorInterviewRecord record) {
    _interviewRecord = record;
  }

  /// Resets dataset to initial state for testing
  void reset() {
    _productions.clear();
    _venues.clear();
    _rehearsals.clear();
    _roles.clear();
    _castAssignments.clear();
    _interviewRecord = DirectorInterviewRecord.emptyTemplate();
    _seedInitialData();
  }
}
