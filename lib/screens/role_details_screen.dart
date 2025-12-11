import 'package:flutter/material.dart';
import '../models/role.dart';
import '../services/database_service.dart';
import '../services/calendar_service.dart';

class RoleDetailsScreen extends StatefulWidget {
  final Role role;

  const RoleDetailsScreen({super.key, required this.role});

  @override
  State<RoleDetailsScreen> createState() => _RoleDetailsScreenState();
}

class _RoleDetailsScreenState extends State<RoleDetailsScreen> {
  late Role editableRole;
  final db = DatabaseService();
  final calendar = CalendarService();

  @override
  void initState() {
    super.initState();
    editableRole = Role(
      id: widget.role.id,
      companyName: widget.role.companyName,
      roleName: widget.role.roleName,
      pptDate: widget.role.pptDate,
      testDate: widget.role.testDate,
      applicationDeadline: widget.role.applicationDeadline,
      isInterested: widget.role.isInterested,
      isRejected: widget.role.isRejected,
      pptEventId: widget.role.pptEventId,
      testEventId: widget.role.testEventId,
      applicationDeadlineEventId: widget.role.applicationDeadlineEventId,
    );
  }

  Future<void> _pickDateTime(
    Function(DateTime?) setter,
    DateTime? initial,
  ) async {
    try {
      DateTime now = initial ?? DateTime.now();

      final pickedDate = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 3),
      );
      if (!mounted || pickedDate == null) return;

      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
      );
      if (!mounted || pickedTime == null) return;

      final dt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (!mounted) return;
      setState(() => setter(dt));
    } catch (e, st) {
      debugPrint("❌ Error picking date/time: $e\n$st");
    }
  }

  Widget _dateRow(
    String label,
    DateTime? dt,
    Function(DateTime?) setter,
    VoidCallback onClear,
  ) {
    String text = 'Not set';
    if (dt != null) {
      text =
          "${dt.toLocal().toString().split(' ')[0]} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text("$label: $text", style: const TextStyle(fontSize: 16)),
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => _pickDateTime(setter, dt),
              child: const Text('Set'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onClear,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveRole() async {
    try {
      // Persist role changes
      await db.updateRole(editableRole);

      // Sync calendar events safely
      await calendar.syncRoleEvents(editableRole);

      // Save event IDs back to DB
      await db.updateRole(editableRole);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint("❌ Error saving role: $e\n$st");
    }
  }

  Future<void> _toggleInterested(bool interested) async {
    try {
      setState(() {
        editableRole.isInterested = interested;
        editableRole.isRejected = !interested;
      });

      await db.updateRole(editableRole);
      await calendar.syncRoleEvents(editableRole);
      await db.updateRole(editableRole);
    } catch (e, st) {
      debugPrint("❌ Error toggling interested: $e\n$st");
    }
  }

  Future<void> _toggleRejected(bool rejected) async {
    try {
      setState(() {
        editableRole.isRejected = rejected;
        editableRole.isInterested = !rejected;
      });

      await db.updateRole(editableRole);
      await calendar.syncRoleEvents(editableRole);
      await db.updateRole(editableRole);
    } catch (e, st) {
      debugPrint("❌ Error toggling rejected: $e\n$st");
    }
  }

  Future<void> _confirmDelete() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Role'),
          content: const Text(
            'Are you sure you want to delete this role? This will also remove corresponding calendar reminders.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // delete calendar events first
      editableRole.isRejected = true;
      await calendar.syncRoleEvents(editableRole);

      // persist clearing of event ids
      await db.updateRole(editableRole);

      // delete DB row
      await db.deleteRole(editableRole.id!);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint("❌ Error deleting role: $e\n$st");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${editableRole.companyName} — ${editableRole.roleName}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: editableRole.isInterested
                        ? Colors.green
                        : null,
                  ),
                  onPressed: () => _toggleInterested(true),
                  child: const Text('Interested'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: editableRole.isRejected
                        ? Colors.red
                        : null,
                  ),
                  onPressed: () => _toggleRejected(true),
                  child: const Text('Reject'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _dateRow(
              'PPT Date',
              editableRole.pptDate,
              (d) => setState(() => editableRole.pptDate = d),
              () => setState(() => editableRole.pptDate = null),
            ),
            const SizedBox(height: 12),
            _dateRow(
              'Test Date',
              editableRole.testDate,
              (d) => setState(() => editableRole.testDate = d),
              () => setState(() => editableRole.testDate = null),
            ),
            const SizedBox(height: 12),
            _dateRow(
              'Application Deadline',
              editableRole.applicationDeadline,
              (d) => setState(() => editableRole.applicationDeadline = d),
              () => setState(() => editableRole.applicationDeadline = null),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveRole,
                    child: const Text('Save Changes'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: _confirmDelete,
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
