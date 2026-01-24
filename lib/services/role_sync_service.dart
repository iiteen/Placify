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
      var applicationDeadline = parsedData['application_deadline'];
      var pptDate = parsedData['ppt']?['datetime'];
      final rolesData = parsedData['roles'];
      final defaultRole = "TBD";

      if (companyName == null || companyName.isEmpty) {
        AppLogger.log("⚠️ No valid company name found in parsed data.");
        return;
      }

      if (rolesData == null || rolesData.isEmpty) {
        AppLogger.log(
          "⚠️ No valid roles found in parsed data. It should never appear. (Possible loss of INFO)",
        );
        return;
      }

      Role? placeholderRole = await _db.findRole(companyName, defaultRole);

      for (var roleData in rolesData) {
        final roleName = roleData['name'];
        //TODO: later handle mutliple tests for each role
        final tests = roleData['tests'];
        final test = (tests != null && tests.isNotEmpty) ? tests[0] : null;
        final testDate = test != null ? test['datetime'] : null;

        final DateTime? tstDt = testDate != null
            ? DateTime.tryParse(testDate)
            : null;
        DateTime? pptDt = pptDate != null ? DateTime.tryParse(pptDate) : null;
        DateTime? appDl = applicationDeadline != null
            ? DateTime.tryParse(applicationDeadline)
            : null;

        if (roleName == null || roleName.isEmpty) {
          AppLogger.log(
            "ℹ️ Role name missing. Updating PPT/Application Deadline for all roles of $companyName",
          );

          final roles = await _db.findRolesByCompany(companyName);
          if (roles.isEmpty) {
            AppLogger.log(
              "ℹ️ No roles available. Generating a placeholder role.",
            );

            final placeholderRole = Role(
              companyName: companyName,
              roleName: defaultRole,
              pptDate: pptDt,
              applicationDeadline: appDl,
              testDate: tstDt,
              isInterested: false,
              isRejected: false,
            );

            await _db.insertRole(placeholderRole);

            try {
              await _calendar.syncRoleEvents(placeholderRole);
            } catch (e, st) {
              AppLogger.log(
                "❌ Calendar sync failed for placeholder role: $e\n$st",
              );
            }

            await _db.updateRole(placeholderRole);
            continue;
          }

          for (final role in roles) {
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

              try {
                await _calendar.syncRoleEvents(role);
              } catch (e, st) {
                AppLogger.log(
                  "❌ Calendar sync failed for bulk role update: $e\n$st",
                );
              }

              await _db.updateRole(role);

              AppLogger.log(
                "♻️ Bulk-updated role: ${role.companyName} — ${role.roleName}",
              );
            } else {
              AppLogger.log("ℹ️ No updates needed");
            }
          }

          continue;
        }

        //Real roles
        if (placeholderRole != null) {
          AppLogger.log(
            "ℹ️ Placeholder role found for $companyName. Will apply merge logic.",
          );

          applicationDeadline ??= placeholderRole.applicationDeadline
              ?.toIso8601String();
          pptDate ??= placeholderRole.pptDate?.toIso8601String();
          pptDt ??= placeholderRole.pptDate;
          appDl ??= placeholderRole.applicationDeadline;

          // Delete placeholder
          placeholderRole.isRejected = true;
          try {
            await _calendar.syncRoleEvents(placeholderRole);
          } catch (e, st) {
            AppLogger.log(
              "❌ Calendar sync failed while deleting placeholder: $e\n$st",
            );
          }
          await _db.deleteRole(placeholderRole.id!);

          AppLogger.log("Deleted placeholder role for $companyName");
          placeholderRole = null;
        }

        Role? role = await _db.findRole(companyName, roleName);

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
