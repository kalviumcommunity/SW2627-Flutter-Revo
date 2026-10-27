import '../core/enums/revo_enums.dart';

class Production {
  final String productionId;
  final String name;
  final String description;
  final String directorId;
  final DateTime startDate;
  final DateTime endDate;
  final ProductionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Production({
    required this.productionId,
    required this.name,
    required this.description,
    required this.directorId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'productionId': productionId,
      'name': name,
      'description': description,
      'directorId': directorId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Production.fromMap(Map<String, dynamic> map, String id) {
    return Production(
      productionId: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      directorId: map['directorId'] ?? '',
      startDate: DateTime.tryParse(map['startDate'].toString()) ?? DateTime.now(),
      endDate: DateTime.tryParse(map['endDate'].toString()) ?? DateTime.now(),
      status: ProductionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ProductionStatus.planning,
      ),
      createdAt: DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now(),
    );
  }
}

class ProductionInput {
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final ProductionStatus status;

  ProductionInput({
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.status = ProductionStatus.planning,
  });
}
