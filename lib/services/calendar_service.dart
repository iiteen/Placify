import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import '../models/role.dart';

class CalendarService {
  final DeviceCalendarPlugin _calendar = DeviceCalendarPlugin();
  String? _calendarId;

  Future<void> initCalendar() async {
    final perms = await _calendar.requestPermissions();

    if (!(perms.isSuccess && perms.data == true)) {
      debugPrint(
        "⚠️ Calendar permission NOT granted. Events cannot be created.",
      );
      return;
    }

    final calendarsResult = await _calendar.retrieveCalendars();
    final calendars = calendarsResult.data;

    if (calendars == null || calendars.isEmpty) {
      debugPrint("⚠️ No calendars found on this device.");
      return;
    }

    final writable = calendars.firstWhere(
      (c) => c.isReadOnly == false,
      orElse: () => calendars.first,
    );

    _calendarId = writable.id;
    debugPrint("✅ Using calendar: ${writable.name}");
  }

  // ---------------------------------------------------------------------------
  // 🔥 Smart Reminder Logic
  // ---------------------------------------------------------------------------
  List<Reminder> _buildSmartReminder(DateTime eventStart) {
    final now = DateTime.now();

    // 1. Preferred: 30 min before
    final preferred = eventStart.subtract(const Duration(minutes: 30));
    if (preferred.isAfter(now)) {
      final mins = eventStart.difference(preferred).inMinutes;
      return [Reminder(minutes: mins)];
    }

    // 2. Backup: 5 minutes from now
    final fiveMin = now.add(const Duration(minutes: 5));
    if (fiveMin.isBefore(eventStart)) {
      final mins = eventStart.difference(fiveMin).inMinutes;
      return [Reminder(minutes: mins)];
    }

    // Event too close — no reminder possible
    return [];
  }

  // ---------------------------------------------------------------------------
  // CREATE EVENT (with smart reminder)
  // ---------------------------------------------------------------------------
  Future<String?> _createEvent(
    Role role,
    String eventType,
    DateTime date,
  ) async {
    if (_calendarId == null) return null;

    final start = TZDateTime.from(date, local);
    final end = start.add(const Duration(hours: 1));
    final reminders = _buildSmartReminder(start);

    debugPrint("⏰ Reminder(s) for $eventType event: $reminders");

    final event = Event(
      _calendarId!,
      title: "${role.companyName} — ${role.roleName} ($eventType)",
      start: start,
      end: end,
      // reminders: reminders,
    );

    final res = await _calendar.createOrUpdateEvent(event);
    return res?.data;
  }

  // ---------------------------------------------------------------------------
  // DELETE EVENT
  // ---------------------------------------------------------------------------
  Future<void> _deleteEvent(String? eventId) async {
    if (_calendarId == null || eventId == null || eventId.isEmpty) {
      return;
    }
    await _calendar.deleteEvent(_calendarId!, eventId);
  }

  // ---------------------------------------------------------------------------
  // 🔥 SYNC ONE (delete + recreate)
  // ---------------------------------------------------------------------------
  Future<void> _syncSingle({
    required Role role,
    required String type,
    required DateTime? date,
    required String? eventId,
    required void Function(String? id) setEventId,
  }) async {
    // CASE 1 — date removed → delete event
    if (date == null) {
      if (eventId != null && eventId.isNotEmpty) {
        debugPrint("🗑 Removing $type event because date was cleared.");
        await _deleteEvent(eventId);
        setEventId(null);
      }
      return;
    }

    // CASE 2 — always delete old before creating new
    if (eventId != null && eventId.isNotEmpty) {
      debugPrint("♻️ Deleting old $type event before recreating...");
      await _deleteEvent(eventId);
    }

    // CASE 3 — create new
    final newId = await _createEvent(role, type, date);
    if (newId != null && newId.isNotEmpty) {
      setEventId(newId);
      debugPrint("✨ Created $type event → ID: $newId");
    } else {
      debugPrint("❌ Failed to create $type event.");
    }
  }

  // ---------------------------------------------------------------------------
  // SYNC ALL EVENTS FOR A ROLE
  // ---------------------------------------------------------------------------
  Future<void> syncRoleEvents(Role role) async {
    await initCalendar();
    if (_calendarId == null) return;

    // If rejected → delete everything
    if (role.isRejected) {
      debugPrint("🚫 Role rejected → deleting all events...");
      await _deleteEvent(role.pptEventId);
      await _deleteEvent(role.testEventId);
      await _deleteEvent(role.applicationDeadlineEventId);

      role.pptEventId = null;
      role.testEventId = null;
      role.applicationDeadlineEventId = null;
      return;
    }

    // Otherwise sync each
    await _syncSingle(
      role: role,
      type: 'PPT',
      date: role.pptDate,
      eventId: role.pptEventId,
      setEventId: (id) => role.pptEventId = id,
    );

    await _syncSingle(
      role: role,
      type: 'Test',
      date: role.testDate,
      eventId: role.testEventId,
      setEventId: (id) => role.testEventId = id,
    );

    await _syncSingle(
      role: role,
      type: 'Application Deadline',
      date: role.applicationDeadline,
      eventId: role.applicationDeadlineEventId,
      setEventId: (id) => role.applicationDeadlineEventId = id,
    );
  }
}
