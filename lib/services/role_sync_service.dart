import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/calendar_service.dart';
import '../models/role.dart';

class RoleSyncService {
  final DatabaseService _db = DatabaseService();
  final CalendarService _calendar = CalendarService();

  /// Sync parsed email → DB → Calendar (and save event IDs)
  Future<void> syncRoleFromParsedData(Map<String, dynamic> parsedData) async {
    final companyName = parsedData['company'];
    final applicationDeadline = parsedData['application_deadline'];
    final pptDate = parsedData['ppt']?['datetime'];
    final rolesData = parsedData['roles'];

    if (companyName == null || companyName.isEmpty) {
      debugPrint("No valid company name found in parsed data.");
      return;
    }

    for (var roleData in rolesData) {
      final roleName = roleData['name'];
      final tests = roleData['tests'];
      final test = (tests != null && tests.isNotEmpty) ? tests[0] : null;
      final testDate = test != null ? test['datetime'] : null;

      /// Check if this role already exists
      Role? existingRole = await _db.findRole(companyName, roleName);

      if (existingRole == null) {
        // -------------- NEW ROLE --------------
        Role newRole = Role(
          companyName: companyName,
          roleName: roleName,
          pptDate: pptDate != null ? DateTime.parse(pptDate) : null,
          applicationDeadline: applicationDeadline != null
              ? DateTime.parse(applicationDeadline)
              : null,
          testDate: testDate != null ? DateTime.parse(testDate) : null,
          isInterested: false,
          isRejected: false,
        );

        await _db.insertRole(newRole);
        debugPrint(
          "Inserted new role: ${newRole.companyName} — ${newRole.roleName}",
        );

        // CREATE calendar events
        await _calendar.syncRoleEvents(newRole);

        // 🔥 SAVE eventIds BACK TO DB (important!)
        await _db.updateRole(newRole);
      } else {
        // -------------- EXISTING ROLE --------------
        bool needsUpdate = false;

        if (pptDate != null &&
            existingRole.pptDate != DateTime.parse(pptDate)) {
          existingRole.pptDate = DateTime.parse(pptDate);
          needsUpdate = true;
        }

        if (applicationDeadline != null &&
            existingRole.applicationDeadline !=
                DateTime.parse(applicationDeadline)) {
          existingRole.applicationDeadline = DateTime.parse(
            applicationDeadline,
          );
          needsUpdate = true;
        }

        if (testDate != null &&
            existingRole.testDate != DateTime.parse(testDate)) {
          existingRole.testDate = DateTime.parse(testDate);
          needsUpdate = true;
        }

        if (needsUpdate) {
          // First update DB
          await _db.updateRole(existingRole);
          debugPrint(
            "Updated role: ${existingRole.companyName} — ${existingRole.roleName}",
          );

          // Then sync calendar events
          await _calendar.syncRoleEvents(existingRole);

          // 🔥 Save updated event IDs too
          await _db.updateRole(existingRole);
        } else {
          debugPrint(
            "No changes detected for role: ${existingRole.companyName} — ${existingRole.roleName}",
          );
        }
      }
    }
  }
}
