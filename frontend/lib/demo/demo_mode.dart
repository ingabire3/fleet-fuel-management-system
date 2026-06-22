class DemoMode {
  static const bool active = false;

  // IDs match supabase_seed.sql — same data works in demo AND live Supabase.
  static const Map<String, _Cred> _creds = {
    'admin@npd.rw':   _Cred('npd2024admin', 'a1111111-0000-0000-0000-000000000001'),
    'manager@npd.rw': _Cred('npd2024mgr',   'a1111111-0000-0000-0000-000000000002'),
    'driver1@npd.rw': _Cred('npd2024drv',   'a1111111-0000-0000-0000-000000000011'),
    'driver2@npd.rw': _Cred('npd2024drv',   'a1111111-0000-0000-0000-000000000012'),
    'driver3@npd.rw': _Cred('npd2024drv',   'a1111111-0000-0000-0000-000000000013'),
  };

  // Returns profile ID on success, null on wrong credentials.
  static String? authenticate(String email, String password) {
    final cred = _creds[email.trim().toLowerCase()];
    if (cred == null || cred.password != password) return null;
    return cred.profileId;
  }
}

class _Cred {
  final String password;
  final String profileId;
  const _Cred(this.password, this.profileId);
}
