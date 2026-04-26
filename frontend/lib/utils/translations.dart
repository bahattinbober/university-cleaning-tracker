class StatusTranslator {
  StatusTranslator._();

  static String cleaningStatus(String? status) {
    switch (status) {
      case 'completed': return 'Tamamlandı';
      case 'pending':   return 'Bekliyor';
      case 'noted':     return 'Notlu';
      case 'photo':     return 'Fotoğraflı';
      case 'on_time':   return 'Zamanında';
      case 'late':      return 'Geç';
      default:          return status ?? '-';
    }
  }

  static String userRole(String? role) {
    switch (role) {
      case 'admin': return 'Yönetici';
      case 'staff': return 'Personel';
      default:      return role ?? '-';
    }
  }

  static String approvalStatus(String? status) {
    switch (status) {
      case 'approved': return 'Onaylı';
      case 'pending':  return 'Bekliyor';
      case 'rejected': return 'Reddedildi';
      default:         return status ?? '-';
    }
  }
}
