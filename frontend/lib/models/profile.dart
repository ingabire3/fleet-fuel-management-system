double _parseDecimal(dynamic v, {double fallback = 0.0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

class Profile {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String role;
  final String? avatarUrl;
  final String? organizationId;
  final bool isApproved;
  final bool isActive;
  final double monthlyBudgetRwf;
  final bool isProfileComplete;

  Profile({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    this.avatarUrl,
    this.organizationId,
    this.isApproved = true,
    this.isActive = true,
    this.monthlyBudgetRwf = 400000,
    this.isProfileComplete = true,
  });

  /// Builds from either the old Supabase `profiles` row (snake_case) or the
  /// new backend's `PublicUser` shape (camelCase, upper-case role enum).
  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        fullName: (json['fullName'] ?? json['full_name']) as String? ?? 'Unknown',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        role: (json['role'] as String? ?? 'driver').toUpperCase(),
        avatarUrl: (json['avatarUrl'] ?? json['avatar_url']) as String?,
        organizationId: json['organizationId'] as String?,
        isApproved: (json['isApproved'] ?? json['is_approved']) as bool? ?? false,
        isActive: (json['isActive'] ?? json['is_active']) as bool? ?? true,
        monthlyBudgetRwf: _parseDecimal(
            json['monthlyBudgetRwf'] ?? json['monthly_budget_rwf'],
            fallback: 400000),
        isProfileComplete: (json['isProfileComplete'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'avatarUrl': avatarUrl,
        'organizationId': organizationId,
        'isApproved': isApproved,
        'isActive': isActive,
        'monthlyBudgetRwf': monthlyBudgetRwf,
      };

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  String get _normalizedRole => role.toUpperCase();

  bool get isSuperAdmin => _normalizedRole == 'SUPER_ADMIN' || _normalizedRole == 'ADMIN';
  bool get isAdmin => isSuperAdmin;
  bool get isFinance =>
      _normalizedRole == 'FLEET_MANAGER' || _normalizedRole == 'FINANCE_OFFICER' || _normalizedRole == 'FINANCE';
  bool get isDriver => _normalizedRole == 'DRIVER';

  String get roleLabel {
    if (isSuperAdmin) return 'Super Admin';
    if (_normalizedRole == 'FLEET_MANAGER') return 'Fleet Manager';
    if (isFinance) return 'Finance (DAF)';
    return 'Driver';
  }
}
