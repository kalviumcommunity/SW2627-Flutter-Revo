import '../core/enums/revo_enums.dart';
import '../models/application.dart';
import '../models/audition.dart';

abstract class AuditionRepository {
  Stream<List<Audition>> watchAuditions({String? productionId, bool openOnly = false});
  Future<Audition> createAudition(AuditionInput input); // Director
  Future<void> updateAudition(String auditionId, AuditionInput input);

  Future<Application> apply(String auditionId); // Cast; uses current user
  Future<void> withdraw(String applicationId); // Cast, own application
  Stream<List<Application>> watchApplicants(String auditionId); // Director
  Stream<List<Application>> watchMyApplications(); // Cast
  Future<void> updateApplicationStatus(String applicationId, ApplicationStatus status); // Director
}
