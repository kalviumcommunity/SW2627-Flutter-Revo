import '../core/enums/revo_enums.dart';

class ProductionRole {
  final String roleId;
  final String productionId;
  final String name;
  final String description;
  final RoleStatus status;

  ProductionRole({
    required this.roleId,
    required this.productionId,
    required this.name,
    required this.description,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'roleId': roleId,
      'productionId': productionId,
      'name': name,
      'description': description,
      'status': status.name,
    };
  }

  factory ProductionRole.fromMap(Map<String, dynamic> map, String id) {
    return ProductionRole(
      roleId: id,
      productionId: map['productionId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      status: RoleStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RoleStatus.open,
      ),
    );
  }
}

class RoleInput {
  final String productionId;
  final String name;
  final String description;

  RoleInput({
    required this.productionId,
    required this.name,
    required this.description,
  });
}
