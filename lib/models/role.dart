class Role {
  int? id;

  String companyName;
  String roleName;

  DateTime? pptDate;
  DateTime? testDate;
  DateTime? interviewDate;

  bool isInterested;
  bool isRejected;

  // Calendar event IDs for update/delete
  String? pptEventId;
  String? testEventId;
  String? interviewEventId;

  Role({
    this.id,
    required this.companyName,
    required this.roleName,
    this.pptDate,
    this.testDate,
    this.interviewDate,
    this.isInterested = false,
    this.isRejected = false,
    this.pptEventId,
    this.testEventId,
    this.interviewEventId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyName': companyName,
      'roleName': roleName,
      'pptDate': pptDate?.toIso8601String(),
      'testDate': testDate?.toIso8601String(),
      'interviewDate': interviewDate?.toIso8601String(),
      'isInterested': isInterested ? 1 : 0,
      'isRejected': isRejected ? 1 : 0,
      'pptEventId': pptEventId,
      'testEventId': testEventId,
      'interviewEventId': interviewEventId,
    };
  }

  factory Role.fromMap(Map<String, dynamic> map) {
    return Role(
      id: map['id'] is int
          ? map['id'] as int
          : (map['id'] != null ? int.parse(map['id'].toString()) : null),
      companyName: map['companyName'] ?? '',
      roleName: map['roleName'] ?? '',
      pptDate: map['pptDate'] != null ? DateTime.parse(map['pptDate']) : null,
      testDate: map['testDate'] != null
          ? DateTime.parse(map['testDate'])
          : null,
      interviewDate: map['interviewDate'] != null
          ? DateTime.parse(map['interviewDate'])
          : null,
      isInterested: (map['isInterested'] == 1),
      isRejected: (map['isRejected'] == 1),
      pptEventId: map['pptEventId'],
      testEventId: map['testEventId'],
      interviewEventId: map['interviewEventId'],
    );
  }
}
