class Role {
  int? id;

  String companyName;
  String roleName;

  DateTime? pptDate;
  DateTime? testDate;
  DateTime? applicationDeadline;

  bool isInterested;
  bool isRejected;

  // Calendar event IDs for update/delete
  String? pptEventId;
  String? testEventId;
  String? applicationDeadlineEventId;

  Role({
    this.id,
    required this.companyName,
    required this.roleName,
    this.pptDate,
    this.testDate,
    this.applicationDeadline,
    this.isInterested = false,
    this.isRejected = false,
    this.pptEventId,
    this.testEventId,
    this.applicationDeadlineEventId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyName': companyName,
      'roleName': roleName,
      'pptDate': pptDate?.toIso8601String(),
      'testDate': testDate?.toIso8601String(),
      'applicationDeadline': applicationDeadline?.toIso8601String(),
      'isInterested': isInterested ? 1 : 0,
      'isRejected': isRejected ? 1 : 0,
      'pptEventId': pptEventId,
      'testEventId': testEventId,
      'applicationDeadlineEventId': applicationDeadlineEventId,
    };
  }

  factory Role.fromMap(Map<String, dynamic> map) {
    DateTime? safeParseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    bool safeBool(dynamic value) {
      if (value == null) return false;
      if (value is int) return value == 1;
      if (value is bool) return value;
      if (value is String) return value == '1' || value.toLowerCase() == 'true';
      return false;
    }

    return Role(
      id: map['id'] is int
          ? map['id'] as int
          : (map['id'] != null ? int.tryParse(map['id'].toString()) : null),
      companyName: map['companyName']?.toString() ?? '',
      roleName: map['roleName']?.toString() ?? '',
      pptDate: safeParseDate(map['pptDate']),
      testDate: safeParseDate(map['testDate']),
      applicationDeadline: safeParseDate(map['applicationDeadline']),
      isInterested: safeBool(map['isInterested']),
      isRejected: safeBool(map['isRejected']),
      pptEventId: map['pptEventId']?.toString(),
      testEventId: map['testEventId']?.toString(),
      applicationDeadlineEventId: map['applicationDeadlineEventId']?.toString(),
    );
  }
}
