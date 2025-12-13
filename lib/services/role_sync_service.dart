import '../services/database_service.dart';
import '../services/calendar_service.dart';
import '../models/role.dart';
import '../utils/applogger.dart';

class RoleSyncService {
  final DatabaseService _db = DatabaseService();
  final CalendarService _calendar = CalendarService();

  /// Sync parsed email → DB → Calendar (save event IDs)
  Future<void> syncRoleFromParsedData(Map<String, dynamic> parsedData) async {
    try {
      final companyName = parsedData['company'];
      final applicationDeadline = parsedData['application_deadline'];
      final pptDate = parsedData['ppt']?['datetime'];
      final rolesData = parsedData['roles'];

      if (companyName == null || companyName.isEmpty || rolesData == null) {
        AppLogger.log(
          "⚠️ No valid company name or roles found in parsed data.",
        );
        return;
      }

      for (var roleData in rolesData) {
        final roleName = roleData['name'];
        if (roleName == null || roleName.isEmpty) continue;

        //TODO: later handle mutliple tests for each role
        final tests = roleData['tests'];
        final test = (tests != null && tests.isNotEmpty) ? tests[0] : null;
        final testDate = test != null ? test['datetime'] : null;

        Role? role = await _db.findRole(companyName, roleName);

        final DateTime? pptDt = pptDate != null
            ? DateTime.tryParse(pptDate)
            : null;
        final DateTime? appDl = applicationDeadline != null
            ? DateTime.tryParse(applicationDeadline)
            : null;
        final DateTime? tstDt = testDate != null
            ? DateTime.tryParse(testDate)
            : null;

        if (role == null) {
          // -------------- NEW ROLE --------------
          role = Role(
            companyName: companyName,
            roleName: roleName,
            pptDate: pptDt,
            applicationDeadline: appDl,
            testDate: tstDt,
            isInterested: false,
            isRejected: false,
          );

          await _db.insertRole(role);

          AppLogger.log(
            "✅ Inserted new role: ${role.companyName} — ${role.roleName}",
          );

          // Create calendar events
          try {
            await _calendar.syncRoleEvents(role);
          } catch (e, st) {
            AppLogger.log("❌ Calendar sync failed for new role: $e\n$st");
          }

          // Save event IDs
          await _db.updateRole(role);
        } else {
          // -------------- EXISTING ROLE --------------
          bool needsUpdate = false;

          if (pptDt != null && role.pptDate != pptDt) {
            role.pptDate = pptDt;
            needsUpdate = true;
          }
          if (appDl != null && role.applicationDeadline != appDl) {
            role.applicationDeadline = appDl;
            needsUpdate = true;
          }
          if (tstDt != null && role.testDate != tstDt) {
            role.testDate = tstDt;
            needsUpdate = true;
          }

          if (needsUpdate) {
            await _db.updateRole(role);
            AppLogger.log(
              "♻️ Updated role: ${role.companyName} — ${role.roleName}",
            );

            try {
              await _calendar.syncRoleEvents(role);
            } catch (e, st) {
              AppLogger.log(
                "❌ Calendar sync failed for existing role: $e\n$st",
              );
            }

            // Save updated event IDs
            await _db.updateRole(role);
          } else {
            AppLogger.log(
              "ℹ️ No changes detected for role: ${role.companyName} — ${role.roleName}",
            );
          }
        }
      }
    } catch (e, st) {
      AppLogger.log("❌ RoleSyncService sync error: $e\n$st");
    }
  }
}
