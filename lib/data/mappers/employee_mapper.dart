import 'package:csv/csv.dart';

import '../../domain/entities/employee.dart';

class EmployeeMapper {
  const EmployeeMapper._();

  static const droppedColumns = <String>[
    'password',
    'id_card',
    'black_list',
    'black_list_reason',
  ];

  static Employee? fromCsvRow(CsvRow row) {
    String cell(String key) {
      if (droppedColumns.contains(key)) return '';
      return (row[key] ?? '').toString().trim();
    }

    final personId = cell('person_id');
    if (personId.isEmpty) return null;

    final branchName = cell('branch_name');
    final locationDesc = cell('location_desc');
    return Employee(
      personId: personId,
      firstName: cell('first_name'),
      lastName: cell('last_name'),
      firstNameAlt1: cell('first_name_alt1'),
      lastNameAlt1: cell('last_name_alt1'),
      nickName: cell('nick_name'),
      employeeStatus: cell('employee_status'),
      positionDesc: cell('position_desc'),
      employeeType: cell('employee_type'),
      company: cell('company'),
      businessName: cell('business_name'),
      divisionHqName: cell('division_hq_name'),
      divisionBranchName: cell('division_branch_name'),
      sectionName: cell('section_name'),
      unitName: cell('unit_name'),
      supervisor: cell('supervisor'),
      branchName: branchName,
      locationDesc: locationDesc,
      branchLabel: branchLabel(branchName, locationDesc),
      mobilePhone: cell('mobile_phone'),
      businessPhone: cell('business_phone'),
      emailCompany: cell('email_company'),
      hireDate: normalizeDate(cell('hire_date')),
      endDate: endDateOf(
        lastWorking: cell('last_working_date'),
        resign: cell('resign_date'),
        termination: cell('termination_date'),
      ),
    );
  }

  static Employee fromDb(Map<String, Object?> row) {
    String text(String key) => (row[key] ?? '').toString();
    return Employee(
      personId: text('person_id'),
      firstName: text('first_name'),
      lastName: text('last_name'),
      firstNameAlt1: text('first_name_alt1'),
      lastNameAlt1: text('last_name_alt1'),
      nickName: text('nick_name'),
      employeeStatus: text('employee_status'),
      positionDesc: text('position_desc'),
      employeeType: text('employee_type'),
      company: text('company'),
      businessName: text('business_name'),
      divisionHqName: text('division_hq_name'),
      divisionBranchName: text('division_branch_name'),
      sectionName: text('section_name'),
      unitName: text('unit_name'),
      supervisor: text('supervisor'),
      branchName: text('branch_name'),
      locationDesc: text('location_desc'),
      branchLabel: text('branch_label'),
      mobilePhone: text('mobile_phone'),
      businessPhone: text('business_phone'),
      emailCompany: text('email_company'),
      hireDate: text('hire_date'),
      endDate: text('end_date'),
    );
  }

  static Map<String, Object?> toDb(Employee employee) {
    return {
      'person_id': employee.personId,
      'first_name': employee.firstName,
      'last_name': employee.lastName,
      'first_name_alt1': employee.firstNameAlt1,
      'last_name_alt1': employee.lastNameAlt1,
      'nick_name': employee.nickName,
      'employee_status': employee.employeeStatus,
      'position_desc': employee.positionDesc,
      'employee_type': employee.employeeType,
      'company': employee.company,
      'business_name': employee.businessName,
      'division_hq_name': employee.divisionHqName,
      'division_branch_name': employee.divisionBranchName,
      'section_name': employee.sectionName,
      'unit_name': employee.unitName,
      'supervisor': employee.supervisor,
      'branch_name': employee.branchName,
      'location_desc': employee.locationDesc,
      'branch_label': employee.branchLabel,
      'mobile_phone': employee.mobilePhone,
      'business_phone': employee.businessPhone,
      'email_company': employee.emailCompany,
      'hire_date': employee.hireDate,
      'end_date': employee.endDate,
      'search_text': searchText(employee),
    };
  }

  /// มีชื่อสาขาใช้ค่านั้น ถ้าว่างใช้สถานที่
  static String branchLabel(String branchName, String locationDesc) {
    final branch = branchName.trim();
    if (branch.isNotEmpty) return branch;
    return locationDesc.trim();
  }

  /// วันสุดท้ายที่ทำงานมาก่อน แล้ววันลาออก แล้ววันสิ้นสุดสัญญา
  static String endDateOf({
    required String lastWorking,
    required String resign,
    required String termination,
  }) {
    for (final raw in [lastWorking, resign, termination]) {
      final normalized = normalizeDate(raw);
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  static String normalizeDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final match = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(value);
    final date = match?[1];
    if (date != null && date.isNotEmpty) return date;
    return value;
  }

  static String searchText(Employee employee) {
    final parts = <String>[
      employee.personId,
      employee.firstName,
      employee.lastName,
      employee.firstNameAlt1,
      employee.lastNameAlt1,
      employee.nickName,
      employee.displayName,
      employee.displayNameEn,
    ];
    final seen = <String>{};
    final buffer = StringBuffer();
    for (final part in parts) {
      final value = part.trim().toLowerCase();
      if (value.isEmpty || !seen.add(value)) continue;
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(value);
    }
    return buffer.toString();
  }
}
