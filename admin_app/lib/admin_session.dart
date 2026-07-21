/// Holds the logged-in admin's identity/role for the rest of the app.
/// Built once from the login response and threaded through every page
/// instead of a bare token, so role checks live in one place.
class AdminSession {
  final String token;
  final String name;
  final String email;
  final String role;
  final int? deptId;
  final int? facultyId;
  final String deptName;

  const AdminSession({
    required this.token,
    required this.name,
    required this.email,
    required this.role,
    this.deptId,
    this.facultyId,
    this.deptName = '',
  });

  factory AdminSession.fromLogin(String token, Map<String, dynamic> admin) {
    return AdminSession(
      token: token,
      name: admin['name']?.toString() ?? '',
      email: admin['email']?.toString() ?? '',
      role: admin['role']?.toString() ?? 'faculty',
      deptId: admin['dept_id'] is int ? admin['dept_id'] as int : null,
      facultyId: admin['faculty_id'] is int ? admin['faculty_id'] as int : null,
      deptName: admin['dept_name']?.toString() ?? '',
    );
  }

  bool get isSuperAdmin => role == 'super_admin' || role == 'admin';
  bool get isHod => role == 'hod';
  bool get isFaculty => role == 'faculty';

  /// super_admin/admin manage any department's staff; hod manages their own.
  bool get canManageStaff => isSuperAdmin || isHod;

  /// Only super_admin/admin/hod may edit or delete student records.
  bool get canEditStudents => isSuperAdmin || isHod;
}
