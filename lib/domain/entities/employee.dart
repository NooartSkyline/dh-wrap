import 'package:equatable/equatable.dart';

class Employee extends Equatable {
  const Employee({
    required this.personId,
    required this.firstName,
    required this.lastName,
    required this.firstNameAlt1,
    required this.lastNameAlt1,
    required this.nickName,
    required this.employeeStatus,
    required this.positionDesc,
    required this.employeeType,
    required this.company,
    required this.businessName,
    required this.divisionHqName,
    required this.divisionBranchName,
    required this.sectionName,
    required this.unitName,
    required this.supervisor,
    required this.branchName,
    required this.locationDesc,
    required this.branchLabel,
    required this.mobilePhone,
    required this.businessPhone,
    required this.emailCompany,
    required this.hireDate,
    required this.endDate,
  });

  final String personId;
  final String firstName;
  final String lastName;
  final String firstNameAlt1;
  final String lastNameAlt1;
  final String nickName;
  final String employeeStatus;
  final String positionDesc;
  final String employeeType;
  final String company;
  final String businessName;
  final String divisionHqName;
  final String divisionBranchName;
  final String sectionName;
  final String unitName;
  final String supervisor;
  final String branchName;
  final String locationDesc;
  final String branchLabel;
  final String mobilePhone;
  final String businessPhone;
  final String emailCompany;
  final String hireDate;
  final String endDate;

  bool get isWorking => employeeStatus == 'Active';

  String get statusLabel {
    if (isWorking) return 'ปฏิบัติงาน';
    if (employeeStatus == 'InActive' || employeeStatus == 'Inactive') {
      return 'ไม่ปฏิบัติงาน';
    }
    return employeeStatus;
  }

  String get displayName {
    final thai = joinName(firstName, lastName);
    if (thai.isNotEmpty) return thai;
    final english = displayNameEn;
    if (english.isNotEmpty) return english;
    return personId;
  }

  String get displayNameEn => joinName(firstNameAlt1, lastNameAlt1);

  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) return '?';
    return String.fromCharCodes([source.runes.first]).toUpperCase();
  }

  String get hireDateLabel => formatStoredDate(hireDate);

  String get endDateLabel => formatStoredDate(endDate);

  /// คนที่ปฏิบัติงานนับถึงวันนี้ คนที่ออกแล้วนับถึงวันสิ้นสุด
  String? serviceLengthLabel({DateTime? asOf}) {
    final start = parseStoredDate(hireDate);
    if (start == null) return null;
    final DateTime? end;
    if (isWorking) {
      final clock = asOf ?? DateTime.now();
      end = DateTime(clock.year, clock.month, clock.day);
    } else {
      end = parseStoredDate(endDate);
    }
    if (end == null || end.isBefore(start)) return null;
    return formatServiceLength(start, end);
  }

  static DateTime? parseStoredDate(String stored) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(stored.trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1) return null;
    final lastDay = DateTime(year, month + 1, 0).day;
    if (day > lastDay) return null;
    return DateTime(year, month, day);
  }

  static String formatServiceLength(DateTime start, DateTime end) {
    var cursor = start;
    var years = 0;
    while (true) {
      final next = _addMonths(cursor, 12);
      if (next.isAfter(end)) break;
      years++;
      cursor = next;
    }
    var months = 0;
    while (true) {
      final next = _addMonths(cursor, 1);
      if (next.isAfter(end)) break;
      months++;
      cursor = next;
    }
    final days = end.difference(cursor).inDays;
    final parts = <String>[
      if (years > 0) '$years ปี',
      if (months > 0) '$months เดือน',
      if (days > 0) '$days วัน',
    ];
    if (parts.isEmpty) return '0 วัน';
    return parts.join(' ');
  }

  static DateTime _addMonths(DateTime date, int months) {
    final total = date.year * 12 + (date.month - 1) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day);
  }

  static String joinName(String first, String last) {
    return [
      first.trim(),
      last.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
  }

  static String formatStoredDate(String stored) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(stored.trim());
    if (match == null) return stored.trim();
    return '${match[3]}/${match[2]}/${match[1]}';
  }

  @override
  List<Object?> get props => [
    personId,
    firstName,
    lastName,
    firstNameAlt1,
    lastNameAlt1,
    nickName,
    employeeStatus,
    positionDesc,
    employeeType,
    company,
    businessName,
    divisionHqName,
    divisionBranchName,
    sectionName,
    unitName,
    supervisor,
    branchName,
    locationDesc,
    branchLabel,
    mobilePhone,
    businessPhone,
    emailCompany,
    hireDate,
    endDate,
  ];
}
