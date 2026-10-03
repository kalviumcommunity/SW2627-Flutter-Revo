import '../core/enums/revo_enums.dart';
import '../models/production.dart';

abstract class ProductionRepository {
  Stream<List<Production>> watchProductions({
    required String userId,
    required UserRole role,
  });
  Future<Production> getProduction(String productionId);
  Future<Production> createProduction(ProductionInput input);
  Future<void> updateProduction(String productionId, ProductionInput input);
  Future<void> setStatus(String productionId, ProductionStatus status);
}
