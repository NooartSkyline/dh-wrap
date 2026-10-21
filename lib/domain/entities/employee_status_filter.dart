enum EmployeeStatusFilter {
  working,
  notWorking,
  all;

  String get label => switch (this) {
    EmployeeStatusFilter.working => 'ปฏิบัติงาน',
    EmployeeStatusFilter.notWorking => 'ไม่ปฏิบัติงาน',
    EmployeeStatusFilter.all => 'ทั้งหมด',
  };
}
