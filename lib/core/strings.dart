import 'package:flutter/widgets.dart';

/// Minimal en/ar strings. Add keys here as screens grow.
const _t = <String, Map<String, String>>{
  'en': {
    'login': 'Log in',
    'phone': 'Phone or email',
    'password': 'Password',
    'shipments': 'Shipments',
    'search': 'Search by code, name or phone',
    'all': 'All',
    'accounts': 'Accounts',
    'balance': 'Balance',
    'transactions': 'Transactions',
    'settings': 'Settings',
    'language': 'Language',
    'logout': 'Log out',
    'details': 'Shipment details',
    'empty': 'Nothing here yet',
    'retry': 'Retry',
    'cod': 'COD',
    'status': 'Status',
    'customer': 'Customer',
    'address': 'Address',
    'call': 'Call',
    'whatsapp': 'WhatsApp',
    'history': 'Status history',
  },
  'ar': {
    'login': 'تسجيل الدخول',
    'phone': 'رقم الهاتف أو البريد',
    'password': 'كلمة المرور',
    'shipments': 'الشحنات',
    'search': 'ابحث بالكود أو الاسم أو الهاتف',
    'all': 'الكل',
    'accounts': 'الحسابات',
    'balance': 'الرصيد',
    'transactions': 'المعاملات',
    'settings': 'الإعدادات',
    'language': 'اللغة',
    'logout': 'تسجيل الخروج',
    'details': 'تفاصيل الشحنة',
    'empty': 'لا توجد بيانات',
    'retry': 'إعادة المحاولة',
    'cod': 'التحصيل',
    'status': 'الحالة',
    'customer': 'العميل',
    'address': 'العنوان',
    'call': 'اتصال',
    'whatsapp': 'واتساب',
    'history': 'سجل الحالات',
  },
};

String tr(BuildContext c, String key) {
  final code = Localizations.localeOf(c).languageCode;
  return (_t[code] ?? _t['en']!)[key] ?? _t['en']![key] ?? key;
}
