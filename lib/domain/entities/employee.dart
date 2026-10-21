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

  static String joinName(String first, String last) {
    return [first.trim(), last.trim()].where((part) => part.isNotEmpty).join(' ');
  }

  static String formatStoredDate(String stored) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(stored.trim());
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
