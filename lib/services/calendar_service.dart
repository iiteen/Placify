import 'package:device_calendar/device_calendar.dart';
import '../models/role.dart';
import '../utils/applogger.dart';

class CalendarService {
  final DeviceCalendarPlugin _calendar = DeviceCalendarPlugin();
  String? _calendarId;

  Future<void> initCalendar() async {
    try {
      final perms = await _calendar.requestPermissions();
      if (!(perms.isSuccess && perms.data == true)) {
        AppLogger.log(
          "⚠️ Calendar permission NOT granted. Events cannot be created.",
        );
        return;
      }

      final calendarsResult = await _calendar.retrieveCalendars();
      final calendars = calendarsResult.data;

      if (calendars == null || calendars.isEmpty) {
        AppLogger.log("⚠️ No calendars found on this device.");
        return;
      }

      final writable = calendars.firstWhere(
        (c) => c.isReadOnly == false,
        orElse: () => calendars.first,
      );

      _calendarId = writable.id;
      AppLogger.log("✅ Using calendar: ${writable.name}");
    } catch (e, st) {
      AppLogger.log("❌ Failed to initialize calendar: $e\n$st");
    }
  }

  List<Reminder> _buildSmartReminder(DateTime eventStart) {
    final now = DateTime.now();

    final preferred = eventStart.subtract(const Duration(minutes: 30));
    if (preferred.isAfter(now)) {
      final mins = eventStart.difference(preferred).inMinutes;
      return [Reminder(minutes: mins)];
    }

    final fiveMin = now.add(const Duration(minutes: 5));
    if (fiveMin.isBefore(eventStart)) {
      final mins = eventStart.difference(fiveMin).inMinutes;
      return [Reminder(minutes: mins)];
    }

    return [];
  }

  String _styledEventType(String t) {
    if (t.contains('PPT')) return "🟩 PPT";
    if (t.contains('Test')) return "🟦 TEST";
    if (t.contains('Application Deadline')) return "🟥 APPLY";
    return "📌 EVENT";
  }

  Future<String?> _createEvent(
    Role role,
    String eventType,
    DateTime date,
  ) async {
    if (_calendarId == null) return null;

    try {
      final start = TZDateTime.from(date, local);
      final end = start.add(const Duration(hours: 1));
      final reminders = _buildSmartReminder(start);

      final event = Event(
        _calendarId!,
        title:
            "${_styledEventType(eventType)} — ${role.companyName} (${role.roleName})",
        start: start,
        end: end,
        reminders: reminders,
      );

      final res = await _calendar.createOrUpdateEvent(event);
      if (res?.data != null) {
        AppLogger.log("✨ Created $eventType event → ID: ${res!.data}");
      } else {
        AppLogger.log("❌ Failed to create $eventType event");
      }
      return res?.data;
    } catch (e, st) {
      AppLogger.log("❌ Error creating $eventType event: $e\n$st");
      return null;
    }
  }

  Future<void> _deleteEvent(String? eventId) async {
    if (_calendarId == null || eventId == null || eventId.isEmpty) return;
    try {
      await _calendar.deleteEvent(_calendarId!, eventId);
      AppLogger.log("🗑 Deleted event ID: $eventId");
    } catch (e, st) {
      AppLogger.log("❌ Failed to delete event $eventId: $e\n$st");
    }
  }

  Future<void> _syncSingle({
    required Role role,
    required String type,
    required DateTime? date,
    required String? eventId,
    required void Function(String? id) setEventId,
  }) async {
    try {
      // CASE 1: date removed → delete event
      if (date == null) {
        AppLogger.log("🗑 Skipping $type event because date was cleared.");
        // await _deleteEvent(eventId);
        setEventId(null);
        return;
      }

      // CASE 2: event exists but date changed → delete old event first
      bool needsRecreate = false;
      if (eventId != null && eventId.isNotEmpty) {
        // We could track old date in DB if needed, or just always recreate
        AppLogger.log("♻️ Deleting old $type event before recreating...");
        await _deleteEvent(eventId);
        setEventId(null);
        needsRecreate = true;
      } else {
        needsRecreate = true; // no existing event → create new
      }

      // CASE 3: create new event if needed
      if (needsRecreate) {
        final newId = await _createEvent(role, type, date);
        if (newId != null && newId.isNotEmpty) {
          setEventId(newId);
        } else {
          AppLogger.log("❌ Failed to create $type event.");
        }
      }
    } catch (e, st) {
      AppLogger.log("❌ Error syncing $type event: $e\n$st");
    }
  }

  Future<void> syncRoleEvents(Role role) async {
    try {
      await initCalendar();
      if (_calendarId == null) return;

      if (role.isRejected) {
        AppLogger.log("🚫 Role rejected → deleting all events...");
        await _deleteEvent(role.pptEventId);
        await _deleteEvent(role.testEventId);
        await _deleteEvent(role.applicationDeadlineEventId);

        role.pptEventId = null;
        role.testEventId = null;
        role.applicationDeadlineEventId = null;
        return;
      }

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
    } catch (e, st) {
      AppLogger.log("❌ Failed to sync role events: $e\n$st");
    }
  }
}
