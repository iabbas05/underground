import 'dart:async';
import 'dart:io' show Platform;
import 'package:ota_update/ota_update.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'build_info.dart';

const _bg = Color(0xFF0A090E);
const _panel = Color(0xFF14121B);
const _line = Color(0xFF2B2738);
const _text = Color(0xFFF4F2F8);
const _mute = Color(0xFFA29CB4);
const _violet = Color(0xFF8A4DFF);
const _violetSoft = Color(0xFFB79BFF);
const _ok = Color(0xFF34D399);
const _warn = Color(0xFFFBBF24);
const _bad = Color(0xFFF87171);

const _defaultBase = 'https://admin.gossipbh.com';

final ValueNotifier<String> lang = ValueNotifier<String>('ar');
final ValueNotifier<String?> tokenN = ValueNotifier<String?>(null);
String base = _defaultBase;

const _s = <String, Map<String, String>>{
  'ar': {
    'pass': 'البطاقة', 'me': 'اشتراكي', 'cls': 'الحصص',
    'scan_hint': 'يتجدد الرمز تلقائياً · امسحه عند البوابة',
    'left': 'يوم متبقي', 'plan': 'الباقة', 'branch': 'الفرع', 'ends': 'ينتهي في',
    'active': 'اشتراك فعّال', 'expiring': 'ينتهي قريباً', 'expired': 'منتهي', 'blocked': 'موقوف',
    'noacc': 'لا يمكن الدخول بهذه البطاقة',
    'men': 'رجال', 'ladies': 'سيدات', 'rest': 'الجمعة يوم راحة', 'none': 'لا توجد حصص',
    'ba': 'مبتدئين ومتقدمين', 'beast': 'بيست',
    'renew': 'للتجديد، زر فرعك أو تواصل مع الموظف.',
    'link_title': 'ربط حسابك', 'link_body': 'اطلب من الموظف رابط بطاقتك، ثم امسح الرمز أو الصق الرابط هنا.',
    'scan_qr': 'مسح الرمز من الموظف', 'paste': 'لصق الرابط', 'link_btn': 'ربط', 'link_hint': 'رابط البطاقة',
    'bad_link': 'الرابط غير صالح أو انتهت صلاحيته. اطلب رابطاً جديداً من الموظف.',
    'net': 'لا يوجد اتصال بالخادم', 'bad_pass': 'البطاقة غير صالحة أو تم تحديثها. اطلب رابطاً جديداً من الموظف.',
    'relink': 'ربط من جديد', 'unlink': 'تسجيل الخروج', 'unlink_q': 'إلغاء ربط هذا الجهاز؟',
    'cancel': 'إلغاء', 'ok': 'موافق', 'lang': 'EN',
    'upd_check': 'التحقق من التحديثات', 'upd_title': 'يتوفر إصدار جديد',
    'upd_body': 'سيتم تحميل التحديث داخل التطبيق ثم يظهر لك زر التثبيت.', 'upd_now': 'تحديث', 'upd_later': 'لاحقاً',
    'upd_none': 'لديك آخر إصدار', 'loading': 'جاري التحميل...',
    'days': 'الأحد,الاثنين,الثلاثاء,الأربعاء,الخميس,الجمعة,السبت',
    'today': 'اليوم', 'tomorrow': 'غداً', 'book': 'احجز', 'waitjoin': 'قائمة الانتظار', 'full': 'مكتمل', 'free': 'متاح',
    'cancel_booking': 'إلغاء الحجز', 'booked': 'تم الحجز', 'onwait': 'في قائمة الانتظار', 'accept': 'تأكيد', 'decline': 'رفض',
    'closed': 'انتهى التسجيل', 'attended': 'حضرت', 'toolate': 'الإلغاء قبل ساعة على الأقل', 'paused': 'الحجز موقوف حتى',
    'strikes': 'إلغاءات متتالية', 'g_hint': 'للحجز وعرض بطاقتك سجّل الدخول', 'g_link': 'تسجيل الدخول', 'g_need': 'سجّل الدخول أولاً للحجز', 'g_classes': 'الحصص', 'g_info': 'الفروع', 'g_pass': 'بطاقتي', 'g_pass_body': 'اربط حسابك لعرض بطاقة الدخول والاشتراك.', 'g_branch': 'اختر الفرع', 'g_seats': 'مقعد متاح', 'back': 'رجوع', 'bell': 'الإشعارات', 'nonotif': 'لا توجد إشعارات', 'wait_n': 'بالانتظار', 'err': 'حدث خطأ',
    'acct': 'حسابي', 'login': 'تسجيل الدخول', 'signup': 'إنشاء حساب', 'username': 'اسم المستخدم', 'password': 'كلمة المرور (8 أحرف على الأقل)', 'fullname': 'الاسم', 'phone': 'رقم الهاتف', 'have_acc': 'عندي حساب', 'no_acc': 'ما عندي حساب', 'pending_msg': 'حسابك قيد المراجعة. إذا كنت مشتركاً، أدخل كود الربط من الموظف أو انتظر تفعيل الإدارة.', 'link_code': 'كود الربط من الموظف', 'send_code': 'إرسال الرمز', 'verify': 'تأكيد', 'email': 'البريد الإلكتروني', 'otp': 'رمز التحقق', 'email_ok': 'تم توثيق البريد', 'logout': 'تسجيل الخروج', 'sub_none': 'لا يوجد اشتراك مرتبط بهذا الحساب', 'sub_expired': 'اشتراكك منتهي', 'addr': 'العنوان', 'hours': 'ساعات العمل', 'call': 'اتصال', 'map': 'الخريطة', 'view_classes': 'عرض الحصص', 'done': 'تم',
    'store': 'الماركت', 'cart': 'السلة', 'order_now': 'اطلب (الدفع عند الاستلام)', 'sold_out': 'نفدت الكمية', 'left_n': 'متبقي', 'goal_all': 'الكل', 'goal_muscle': 'بناء عضل', 'goal_cut': 'تنشيف', 'goal_light': 'خفيف', 'suggested': 'مقترح لك', 'cal': 'سعرة', 'prot': 'بروتين', 'my_orders': 'طلباتي', 'order_sent': 'تم إرسال الطلب، بانتظار موافقة الموظف. الدفع عند الاستلام.', 'st_pending': 'بانتظار الموافقة', 'st_approved': 'تمت الموافقة', 'st_ready': 'جاهز للاستلام', 'st_picked': 'تم الاستلام', 'st_rejected': 'مرفوض', 'st_cancelled': 'ملغي', 'need_login': 'سجّل الدخول أولاً للطلب', 'bd': 'د.ب', 'note': 'ملاحظة (اختياري)', 'empty_menu': 'لا توجد منتجات متاحة اليوم',
    'well': 'الاستشفاء والتقدّم', 'recovery': 'الاستشفاء', 'progress': 'تقدّمي', 'sauna': 'ساونا', 'massage': 'مساج', 'slot_min': 'دقيقة', 'seats_n': 'متاح', 'book_slot': 'حجز', 'booked_ok': 'تم الحجز', 'my_rec': 'حجوزاتي', 'st_booked': 'محجوز', 'st_attended': 'حضرت', 'st_no_show': 'لم تحضر', 'cancel_rec_q': 'إلغاء الحجز؟', 'weight': 'الوزن (كجم)', 'height': 'الطول (سم)', 'body_fat': 'نسبة الدهون % (اختياري)', 'save_entry': 'حفظ القياس', 'bmi': 'مؤشر كتلة الجسم', 'bmi_under': 'نحيف', 'bmi_normal': 'طبيعي', 'bmi_over': 'وزن زائد', 'bmi_obese': 'سمنة', 'change': 'التغيّر', 'history': 'السجل', 'need_login2': 'سجّل الدخول لحفظ قياساتك وحجوزاتك', 'no_slots': 'لا توجد أوقات', 'price': 'السعر',
    'challenges': 'التحديات', 'ch_none': 'لا توجد تحديات هذا الشهر', 'ch_done': 'أنجزت التحدي', 'ch_link': 'اربط اشتراكك لتتبع تقدمك في التحديات', 'ch_board': 'المتصدرون', 'ch_visits': 'يوم حضور', 'ch_classes': 'حصة', 'freeze': 'تجميد الاشتراك', 'freeze_days': 'مدة التجميد (يوم)', 'freeze_send': 'إرسال الطلب', 'freeze_sent': 'تم إرسال الطلب، بانتظار موافقة الإدارة', 'frozen_until': 'اشتراكك مجمّد حتى', 'sub_frozen': 'مجمّد', 'upd_downloading': 'جاري تحميل التحديث...', 'coupon': 'كود الخصم (اختياري)', 'apply': 'تطبيق', 'coupon_ok': 'خصم', 'order_total': 'المجموع بعد الخصم', 'rate_title': 'قيّم حصصك', 'rate_hint': 'كيف كانت الحصة؟', 'rate_send': 'إرسال التقييم', 'rate_comment': 'تعليق (اختياري)', 'rate_thanks': 'شكراً على تقييمك',  'confirm_book': 'تأكيد الحجز', 'confirm_q': 'تأكيد هذا الحجز؟', 'book_done': 'تم تأكيد حجزك', 'ref': 'رقم الحجز', 'arrive_early': 'الرجاء الحضور قبل الموعد بـ 10 دقائق. الإلغاء مجاني قبل ساعة من الموعد.', 'pay_at_desk': 'الدفع في الاستقبال', 'from_package': 'من رصيد باقتك', 'time_l': 'الوقت', 'date_l': 'التاريخ', 'branch_l': 'الفرع',  'my_sessions': 'جلساتي المتبقية', 'pkg_title': 'باقات الجلسات', 'pkg_hint': 'اشترِ الباقة من الاستقبال وتضاف جلساتها لحسابك تلقائياً', 'used_credit': 'تم الحجز من رصيد باقتك', 'sessions_n': 'جلسات', 'news': 'العروض والإعلانات', 
  },
  'en': {
    'pass': 'Pass', 'me': 'Membership', 'cls': 'Classes',
    'scan_hint': 'Code refreshes automatically · scan it at the gate',
    'left': 'days left', 'plan': 'Plan', 'branch': 'Branch', 'ends': 'Ends on',
    'active': 'Active', 'expiring': 'Ending soon', 'expired': 'Expired', 'blocked': 'Blocked',
    'noacc': 'This pass cannot enter',
    'men': 'Men', 'ladies': 'Ladies', 'rest': 'Friday is a rest day', 'none': 'No classes',
    'ba': 'Beginners & advanced', 'beast': 'Beast',
    'renew': 'To renew, visit your branch or ask the staff.',
    'link_title': 'Link your account', 'link_body': 'Ask the staff for your pass link, then scan the code or paste the link here.',
    'scan_qr': 'Scan the code from staff', 'paste': 'Paste link', 'link_btn': 'Link', 'link_hint': 'Pass link',
    'bad_link': 'The link is invalid or expired. Ask the staff for a new one.',
    'net': 'Cannot reach the server', 'bad_pass': 'This pass is invalid or was replaced. Ask the staff for a new link.',
    'relink': 'Link again', 'unlink': 'Sign out', 'unlink_q': 'Unlink this device?',
    'cancel': 'Cancel', 'ok': 'OK', 'lang': 'عربي',
    'upd_check': 'Check for updates', 'upd_title': 'New version available',
    'upd_body': 'The update downloads inside the app, then Android asks you to install it.', 'upd_now': 'Update', 'upd_later': 'Later',
    'upd_none': 'You have the latest version', 'loading': 'Loading...',
    'days': 'Sun,Mon,Tue,Wed,Thu,Fri,Sat',
    'today': 'Today', 'tomorrow': 'Tomorrow', 'book': 'Book', 'waitjoin': 'Join waitlist', 'full': 'Full', 'free': 'free',
    'cancel_booking': 'Cancel booking', 'booked': 'Booked', 'onwait': 'On the waitlist', 'accept': 'Confirm', 'decline': 'Decline',
    'closed': 'Closed', 'attended': 'Attended', 'toolate': 'Cancel at least 1 hour before', 'paused': 'Booking paused until',
    'strikes': 'cancellations in a row', 'bell': 'Notifications', 'nonotif': 'No notifications', 'wait_n': 'waiting', 'err': 'Something went wrong',
    'acct': 'My account', 'login': 'Log in', 'signup': 'Create account', 'username': 'Username', 'password': 'Password (at least 8 characters)', 'fullname': 'Full name', 'phone': 'Phone number', 'have_acc': 'I have an account', 'no_acc': 'I do not have an account', 'pending_msg': 'Your account is under review. If you are a member, enter the link code from the staff or wait for the admin to activate it.', 'link_code': 'Link code from staff', 'send_code': 'Send code', 'verify': 'Verify', 'email': 'Email', 'otp': 'Verification code', 'email_ok': 'Email verified', 'logout': 'Log out', 'sub_none': 'No membership is linked to this account', 'sub_expired': 'Your membership has expired', 'addr': 'Address', 'hours': 'Opening hours', 'call': 'Call', 'map': 'Map', 'view_classes': 'View classes', 'done': 'Done', 'store': 'Store', 'cart': 'Cart', 'order_now': 'Order (pay on pickup)', 'sold_out': 'Sold out', 'left_n': 'left', 'goal_all': 'All', 'goal_muscle': 'Build muscle', 'goal_cut': 'Cutting', 'goal_light': 'Light', 'suggested': 'Suggested', 'cal': 'kcal', 'prot': 'protein', 'my_orders': 'My orders', 'order_sent': 'Order sent, waiting for staff approval. Pay on pickup.', 'st_pending': 'Waiting approval', 'st_approved': 'Approved', 'st_ready': 'Ready for pickup', 'st_picked': 'Picked up', 'st_rejected': 'Rejected', 'st_cancelled': 'Cancelled', 'need_login': 'Log in first to order', 'bd': 'BD', 'note': 'Note (optional)', 'empty_menu': 'No products available today', 'well': 'Recovery & progress', 'recovery': 'Recovery', 'progress': 'My progress', 'sauna': 'Sauna', 'massage': 'Massage', 'slot_min': 'min', 'seats_n': 'left', 'book_slot': 'Book', 'booked_ok': 'Booked', 'my_rec': 'My bookings', 'st_booked': 'Booked', 'st_attended': 'Attended', 'st_no_show': 'No show', 'cancel_rec_q': 'Cancel this booking?', 'weight': 'Weight (kg)', 'height': 'Height (cm)', 'body_fat': 'Body fat % (optional)', 'save_entry': 'Save measurement', 'bmi': 'BMI', 'bmi_under': 'Underweight', 'bmi_normal': 'Normal', 'bmi_over': 'Overweight', 'bmi_obese': 'Obese', 'change': 'Change', 'history': 'History', 'need_login2': 'Log in to save your measurements and bookings', 'no_slots': 'No time slots', 'price': 'Price', 'challenges': 'Challenges', 'ch_none': 'No challenges this month', 'ch_done': 'Challenge completed', 'ch_link': 'Link your membership to track challenge progress', 'ch_board': 'Leaderboard', 'ch_visits': 'days attended', 'ch_classes': 'classes', 'freeze': 'Freeze membership', 'freeze_days': 'Freeze length (days)', 'freeze_send': 'Send request', 'freeze_sent': 'Request sent, waiting for admin approval', 'frozen_until': 'Your membership is frozen until', 'sub_frozen': 'Frozen', 'upd_downloading': 'Downloading the update...', 'coupon': 'Discount code (optional)', 'apply': 'Apply', 'coupon_ok': 'Discount', 'order_total': 'Total after discount', 'rate_title': 'Rate your classes', 'rate_hint': 'How was the class?', 'rate_send': 'Send rating', 'rate_comment': 'Comment (optional)', 'rate_thanks': 'Thanks for your rating',  'confirm_book': 'Confirm booking', 'confirm_q': 'Confirm this booking?', 'book_done': 'Your booking is confirmed', 'ref': 'Booking ref', 'arrive_early': 'Please arrive 10 minutes early. Free cancellation up to 1 hour before.', 'pay_at_desk': 'Pay at the front desk', 'from_package': 'From your package', 'time_l': 'Time', 'date_l': 'Date', 'branch_l': 'Branch',  'my_sessions': 'My remaining sessions', 'pkg_title': 'Session packages', 'pkg_hint': 'Buy a package at the front desk and its sessions are added to your account', 'used_credit': 'Booked using your package', 'sessions_n': 'sessions', 'news': 'Offers & news', 


 'g_hint': 'Log in to book and see your pass', 'g_link': 'Log in', 'g_need': 'Log in first to book', 'g_classes': 'Classes', 'g_info': 'Branches', 'g_pass': 'My pass', 'g_pass_body': 'Log in to see your entry pass and membership.', 'g_branch': 'Choose a branch', 'g_seats': 'seats left', 'back': 'Back',
  },
};
String t(String k) => _s[lang.value]![k] ?? k;

Future<void> setLang(String l) async {
  lang.value = l;
  final p = await SharedPreferences.getInstance();
  await p.setString('lang', l);
}

Future<Map<String, dynamic>> getJson(String path) async {
  http.Response res;
  try {
    res = await http.get(Uri.parse('$base$path')).timeout(const Duration(seconds: 20));
  } catch (_) {
    throw 'net';
  }
  dynamic d;
  try {
    d = jsonDecode(utf8.decode(res.bodyBytes));
  } catch (_) {}
  if (res.statusCode == 200 && d is Map) return Map<String, dynamic>.from(d);
  throw res.statusCode == 404 ? 'bad_pass' : 'net';
}

Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
  http.Response res;
  try {
    res = await http.post(Uri.parse('$base$path'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 20));
  } catch (_) {
    throw t('net');
  }
  dynamic d;
  try {
    d = jsonDecode(utf8.decode(res.bodyBytes));
  } catch (_) {}
  if (res.statusCode == 200 && d is Map) return Map<String, dynamic>.from(d);
  throw (d is Map && d['error'] is String) ? d['error'] as String : t('err');
}


String? custToken;
final ValueNotifier<Map<String, dynamic>?> acctN = ValueNotifier<Map<String, dynamic>?>(null);

Future<Map<String, dynamic>> authCall(String method, String path, [Map<String, dynamic>? body]) async {
  http.Response res;
  final h = {'Content-Type': 'application/json', if (custToken != null) 'Authorization': 'Bearer $custToken'};
  try {
    final u = Uri.parse('$base$path');
    res = await (method == 'GET' ? http.get(u, headers: h) : http.post(u, headers: h, body: jsonEncode(body ?? {}))).timeout(const Duration(seconds: 20));
  } catch (_) {
    throw t('net');
  }
  dynamic d;
  try {
    d = jsonDecode(utf8.decode(res.bodyBytes));
  } catch (_) {}
  if (res.statusCode == 200 && d is Map) return Map<String, dynamic>.from(d);
  if (res.statusCode == 401 && custToken != null && path == '/api/customer/me') await clearAccount();
  throw (d is Map && d['error'] is String) ? d['error'] as String : t('err');
}

Future<void> clearAccount() async {
  custToken = null;
  acctN.value = null;
  final p = await SharedPreferences.getInstance();
  await p.remove('ctoken');
}

/// Stores the account answer; an activated subscriber gets the pass screen automatically.
Future<void> applyAccount(Map<String, dynamic> r) async {
  final p = await SharedPreferences.getInstance();
  if (r['token'] is String) {
    custToken = r['token'] as String;
    await p.setString('ctoken', custToken!);
  }
  acctN.value = {'account': r['account'], 'subscription': r['subscription'], 'member': r['member']};
  final m = r['member'];
  if (m is Map && m['pass_token'] is String) {
    await p.setString('token', m['pass_token'] as String);
    tokenN.value = m['pass_token'] as String;
  }
}

Future<void> refreshAccount() async {
  if (custToken == null) return;
  try {
    await applyAccount(await authCall('GET', '/api/customer/me'));
  } catch (_) {}
}

/// Pulls (server, token) out of a pass link such as https://admin.gossipbh.com/m/UGS.12.1.abcd
({String base, String token})? parseLink(String text) {
  final m = RegExp(r'(https?://[^\s/]+)/m/([A-Za-z0-9._\-]+)').firstMatch(text);
  if (m == null) return null;
  return (base: m.group(1)!, token: m.group(2)!);
}

Future<bool> tryLink(String text) async {
  final p = parseLink(text);
  if (p == null) return false;
  final old = base;
  base = p.base;
  try {
    await getJson('/api/pass/${p.token}');
  } catch (_) {
    base = old;
    return false;
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('base', p.base);
  await prefs.setString('token', p.token);
  tokenN.value = p.token;
  return true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final p = await SharedPreferences.getInstance();
  lang.value = p.getString('lang') ?? 'ar';
  base = p.getString('base') ?? _defaultBase;
  tokenN.value = p.getString('token');
  custToken = p.getString('ctoken');
  runApp(const MemberApp());
  refreshAccount();
}

class MemberApp extends StatelessWidget {
  const MemberApp({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = const ColorScheme.dark(primary: _violet, secondary: _violetSoft, surface: _panel);
    return ValueListenableBuilder<String>(
      valueListenable: lang,
      builder: (context, l, _) => MaterialApp(
        title: 'UNDERGROUND',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: _bg, colorScheme: scheme,
            appBarTheme: const AppBarTheme(backgroundColor: _bg, elevation: 0)),
        locale: Locale(l),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ValueListenableBuilder<String?>(
          valueListenable: tokenN,
          builder: (context, tok, _) => tok == null ? const GuestHome() : HomeScreen(token: tok),
        ),
      ),
    );
  }
}

Widget brand() => const Column(children: [
      Text('UNDERGROUND', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 24)),
      Text('STRENGTH & CONDITIONING', style: TextStyle(letterSpacing: 3, fontSize: 10, color: _violetSoft)),
    ]);

class GuestHome extends StatefulWidget {
  const GuestHome({super.key});
  @override
  State<GuestHome> createState() => _GuestHomeState();
}

class _GuestHomeState extends State<GuestHome> {
  int tab = 0;
  List<dynamic> branches = [];
  int? branchId;
  Map<String, dynamic>? data;
  String? err;
  String aud = 'men';
  int dsel = 0;

  @override
  void initState() {
    super.initState();
    loadBranches();
  }

  Future<void> loadBranches() async {
    try {
      final r = await getJson('/api/public/branches');
      final items = r['items'] as List<dynamic>;
      if (!mounted) return;
      setState(() { branches = items; err = null; });
      if (items.isNotEmpty) await pick((items.first as Map)['id'] as int);
    } catch (_) {
      if (mounted) setState(() => err = 'net');
    }
  }

  Future<void> pick(int id) async {
    setState(() { branchId = id; data = null; });
    try {
      final r = await getJson('/api/public/classes?branch_id=$id');
      if (mounted) setState(() { data = r; err = null; });
    } catch (_) {
      if (mounted) setState(() => err = 'net');
    }
  }

  void toLink() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
  void toPassLink() => Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkScreen(canBack: true)));

  String bname(Map b) => lang.value == 'ar' ? ((b['name_ar'] ?? b['name']) as String) : (b['name'] as String);

  Widget classesView() {
    if (err != null && data == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(t('net'), style: const TextStyle(color: _bad)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: loadBranches, child: Text(t('ok'))),
      ]));
    }
    final dd = data == null ? null : Map<String, dynamic>.from((data!['dates'] as List<dynamic>)[dsel] as Map);
    final rows = dd == null ? <Map<String, dynamic>>[] : (dd['items'] as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).where((r) => r['audience'] == aud).toList();
    return ListView(padding: const EdgeInsets.all(18), children: [
      const NewsBar(),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _violet.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 18, color: _violetSoft),
          const SizedBox(width: 8),
          Expanded(child: Text(t('g_hint'), style: const TextStyle(color: _violetSoft, fontSize: 13))),
          TextButton(onPressed: toLink, child: Text(t('g_link'))),
        ]),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        for (final b in branches)
          ChoiceChip(label: Text(bname(Map<String, dynamic>.from(b as Map))), selected: branchId == (b as Map)['id'], onSelected: (_) => pick(b['id'] as int)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        for (final a in ['men', 'ladies'])
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: SizedBox(width: double.infinity, child: Text(t(a), textAlign: TextAlign.center)), selected: aud == a, onSelected: (_) => setState(() => aud = a)))),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < 2; i++)
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: SizedBox(width: double.infinity, child: Text(t(i == 0 ? 'today' : 'tomorrow'), textAlign: TextAlign.center)), selected: dsel == i, onSelected: (_) => setState(() => dsel = i)))),
      ]),
      const SizedBox(height: 12),
      if (data == null)
        const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (dd!['rest'] == true)
        Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('rest'), style: const TextStyle(color: _mute))))
      else if (rows.isEmpty)
        Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('none'), style: const TextStyle(color: _mute))))
      else
        for (final r in rows)
          Card(
            color: _panel,
            child: ListTile(
              title: Text('${r['time']}  ·  ${r['level'] == 'beast' ? t('beast') : t('ba')}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(r['full'] == true ? t('full') : '${r['free']} ${t('g_seats')}', style: TextStyle(color: r['full'] == true ? _warn : _ok)),
              trailing: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _violet),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('g_need'))));
                  toLink();
                },
                child: Text(r['full'] == true ? t('waitjoin') : t('book')),
              ),
            ),
          ),
    ]);
  }

  Widget passView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.qr_code_2, size: 96, color: _violetSoft),
            const SizedBox(height: 16),
            Text(t('g_pass_body'), textAlign: TextAlign.center, style: const TextStyle(color: _mute)),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(220, 50), backgroundColor: _violet),
              onPressed: toLink,
              icon: const Icon(Icons.link),
              label: Text(t('g_link')),
            ),
            TextButton(onPressed: toPassLink, child: Text(t('link_title'))),
          ]),
        ),
      );

  Future<void> openUrl(String u) async {
    try {
      await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget infoView() => ListView(padding: const EdgeInsets.all(18), children: [
        brand(),
        const SizedBox(height: 20),
        for (final raw in branches)
          Builder(builder: (context) {
            final b = Map<String, dynamic>.from(raw as Map);
            final ar = lang.value == 'ar';
            final addr = ((ar ? (b['address_ar'] ?? b['address']) : (b['address'] ?? b['address_ar'])) ?? '').toString();
            final hrs = ((ar ? (b['hours_ar'] ?? b['hours']) : (b['hours'] ?? b['hours_ar'])) ?? '').toString();
            final ph = (b['phone'] ?? '').toString();
            final map = (b['map_url'] ?? '').toString();
            return Card(
              color: _panel,
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.place_outlined, color: _violetSoft),
                    const SizedBox(width: 8),
                    Text(bname(b), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ]),
                  if (addr.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${t('addr')}: $addr', style: const TextStyle(color: _mute))),
                  if (hrs.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${t('hours')}: $hrs', style: const TextStyle(color: _mute))),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (ph.isNotEmpty) OutlinedButton.icon(onPressed: () => openUrl('tel:$ph'), icon: const Icon(Icons.call, size: 18), label: Text(t('call'))),
                    if (map.isNotEmpty) OutlinedButton.icon(onPressed: () => openUrl(map), icon: const Icon(Icons.map_outlined, size: 18), label: Text(t('map'))),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _violet),
                      onPressed: () { setState(() => tab = 0); pick(b['id'] as int); },
                      icon: const Icon(Icons.fitness_center, size: 18),
                      label: Text(t('view_classes')),
                    ),
                  ]),
                ]),
              ),
            );
          }),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('UNDERGROUND', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [IconButton(tooltip: t('acct'), icon: const Icon(Icons.account_circle_outlined), onPressed: toLink), TextButton(onPressed: () => setLang(lang.value == 'ar' ? 'en' : 'ar'), child: Text(t('lang')))],
      ),
      body: tab == 0 ? classesView() : tab == 1 ? const StoreScreen() : tab == 2 ? const WellnessScreen() : tab == 3 ? infoView() : passView(),
      bottomNavigationBar: NavigationBar(
        backgroundColor: _panel,
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.fitness_center), label: t('g_classes')),
          NavigationDestination(icon: const Icon(Icons.restaurant_menu), label: t('store')),
          NavigationDestination(icon: const Icon(Icons.spa_outlined), label: t('well')),
          NavigationDestination(icon: const Icon(Icons.place_outlined), label: t('g_info')),
          NavigationDestination(icon: const Icon(Icons.qr_code_2), label: t('g_pass')),
        ],
      ),
    );
  }
}


/// Asks a member to rate the classes they attended recently (1-5 stars, optional comment).
class RatePrompt extends StatefulWidget {
  final String token;
  const RatePrompt({super.key, required this.token});
  @override
  State<RatePrompt> createState() => _RatePromptState();
}

class _RatePromptState extends State<RatePrompt> {
  List<dynamic> items = [];
  final Map<int, int> stars = {};
  final Map<int, TextEditingController> notes = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await getJson('/api/pass/${widget.token}/rate/pending');
      if (mounted) setState(() => items = r['items'] as List<dynamic>);
    } catch (_) {}
  }

  Future<void> send(int id) async {
    final n = stars[id] ?? 0;
    if (n < 1) return;
    try {
      await postJson('/api/pass/${widget.token}/rate', {'booking_id': id, 'stars': n, 'comment': notes[id]?.text ?? ''});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('rate_thanks'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    await load();
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final ar = lang.value == 'ar';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final raw in items.take(2))
        Builder(builder: (context) {
          final m = Map<String, dynamic>.from(raw as Map);
          final id = (m['booking_id'] as num).toInt();
          notes.putIfAbsent(id, () => TextEditingController());
          final cur = stars[id] ?? 0;
          return Card(
            color: _panel,
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t('rate_hint')}  ·  ${m['class_date']} ${m['class_time']}  ·  ${ar ? (m['branch_ar'] ?? m['branch']) : m['branch']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => stars[id] = i),
                      icon: Icon(i <= cur ? Icons.star : Icons.star_border, color: _violetSoft),
                    ),
                ]),
                TextField(controller: notes[id], decoration: InputDecoration(hintText: t('rate_comment'), isDense: true)),
                const SizedBox(height: 8),
                FilledButton(onPressed: cur < 1 ? null : () => send(id), child: Text(t('rate_send'))),
              ]),
            ),
          );
        }),
    ]);
  }
}

/// Downloads the new APK inside the app (with a percentage) and opens the system installer;
/// falls back to the browser download link if anything goes wrong.
Future<void> installAppUpdate(BuildContext context, String url) async {
  final prog = ValueNotifier<String>('0%');
  final nav = Navigator.of(context, rootNavigator: true);
  var open = true;
  void closeDialog() {
    if (open) {
      open = false;
      nav.pop();
    }
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder<String>(
          valueListenable: prog,
          builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t('upd_downloading')),
            const SizedBox(height: 14),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(v),
          ]),
        ),
      ),
    ),
  );
  try {
    OtaUpdate().execute(url, destinationFilename: 'UNDERGROUND-Member.apk').listen(
      (e) {
        if (e.status == OtaStatus.DOWNLOADING) {
          prog.value = '${e.value}%';
        } else if (e.status == OtaStatus.INSTALLING || e.status == OtaStatus.INSTALLATION_DONE || e.status == OtaStatus.CANCELED) {
          closeDialog();
        } else if (e.status.name.contains('ERROR')) {
          closeDialog();
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      onError: (_) {
        closeDialog();
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      onDone: closeDialog,
    );
  } catch (_) {
    closeDialog();
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

/// Used by the account/settings screen (works for guests too).
Future<void> checkAppUpdate(BuildContext context) async {
  if (Platform.isIOS) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t('upd_none')}  (v$appBuild)')));
    return;
  }
  try {
    final r = await getJson('/api/app/version?app=member');
    final build = (r['build'] as num?)?.toInt() ?? 0;
    if (!context.mounted) return;
    if (build > appBuild && r['url'] is String) {
      final notes = (r['notes'] as String?) ?? '';
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('upd_title')),
          content: Text(notes.isEmpty ? t('upd_body') : '${t('upd_body')}\n\n$notes'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('upd_later'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('upd_now'))),
          ],
        ),
      );
      if (go == true && context.mounted) await installAppUpdate(context, r['url'] as String);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t('upd_none')}  (v$appBuild)')));
    }
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('net'))));
  }
}

/// Offers and announcements posted by the admin; hidden when there are none.
class NewsBar extends StatefulWidget {
  const NewsBar({super.key});
  @override
  State<NewsBar> createState() => _NewsBarState();
}

class _NewsBarState extends State<NewsBar> {
  List<dynamic> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await getJson('/api/public/announcements');
      if (mounted) setState(() => items = r['items'] as List<dynamic>);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final ar = lang.value == 'ar';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final raw in items.take(3))
        Builder(builder: (context) {
          final m = Map<String, dynamic>.from(raw as Map);
          final title = ((ar ? (m['title_ar'] ?? m['title']) : (m['title'] ?? m['title_ar'])) ?? '').toString();
          final body = ((ar ? (m['body_ar'] ?? m['body']) : (m['body'] ?? m['body_ar'])) ?? '').toString();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_violet.withOpacity(0.35), _panel]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.campaign_outlined, size: 18, color: _violetSoft),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
              if (body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(body, style: const TextStyle(color: _mute, fontSize: 13))),
            ]),
          );
        }),
    ]);
  }
}

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<dynamic> branches = [];
  int? bid;
  List<dynamic> items = [];
  Set<int> suggested = {};
  String goal = '';
  final Map<int, int> cart = {};
  final couponCtrl = TextEditingController();
  List<dynamic> orders = [];
  bool loading = true;
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    try {
      final r = await getJson('/api/public/branches');
      branches = r['items'] as List<dynamic>;
      if (branches.isNotEmpty) bid = (branches.first as Map)['id'] as int;
      await loadMenu();
      await loadOrders();
    } catch (_) {
      if (mounted) setState(() { err = t('net'); loading = false; });
    }
  }

  Future<void> loadMenu() async {
    if (bid == null) return;
    setState(() => loading = true);
    try {
      final r = await getJson('/api/public/store?branch_id=$bid${goal.isEmpty ? '' : '&goal=$goal'}');
      if (!mounted) return;
      setState(() {
        items = r['items'] as List<dynamic>;
        suggested = (r['suggestions'] as List<dynamic>).map((e) => e as int).toSet();
        err = null;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { err = t('net'); loading = false; });
    }
  }

  Future<void> loadOrders() async {
    if (custToken == null) return;
    try {
      final r = await authCall('GET', '/api/customer/orders');
      if (mounted) setState(() => orders = r['items'] as List<dynamic>);
    } catch (_) {}
  }

  String bn(Map b) => lang.value == 'ar' ? ((b['name_ar'] ?? b['name']) as String) : (b['name'] as String);
  double get total {
    var sum = 0.0;
    for (final e in cart.entries) {
      final p = items.cast<Map>().firstWhere((x) => x['id'] == e.key, orElse: () => {});
      if (p.isNotEmpty) sum += (p['price'] as num) * e.value;
    }
    return sum;
  }

  Future<void> applyCoupon() async {
    final code = couponCtrl.text.trim();
    if (code.isEmpty) return;
    try {
      final r = await authCall('POST', '/api/customer/coupon/check', {'code': code, 'subtotal': total});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t('coupon_ok')}: -${(r['discount'] as num).toStringAsFixed(3)} ${t('bd')}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> order() async {
    if (custToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('need_login'))));
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
      return;
    }
    setState(() => busy = true);
    try {
      final code = couponCtrl.text.trim();
      final orr = await authCall('POST', '/api/customer/orders', {
        'branch_id': bid,
        'items': [for (final e in cart.entries) {'product_id': e.key, 'qty': e.value}],
        if (code.isNotEmpty) 'coupon': code,
      });
      cart.clear();
      couponCtrl.clear();
      final disc = (orr['discount'] as num?) ?? 0;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(disc > 0 ? '${t('order_sent')}  ${t('order_total')}: ${(orr['total'] as num).toStringAsFixed(3)} ${t('bd')}' : t('order_sent'))));
      await loadMenu();
      await loadOrders();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      await loadMenu();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget card(Map<String, dynamic> p) {
    final ar = lang.value == 'ar';
    final id = p['id'] as int;
    final out = p['sold_out'] == true;
    final q = cart[id] ?? 0;
    final desc = ((ar ? (p['descr_ar'] ?? p['descr']) : (p['descr'] ?? p['descr_ar'])) ?? '').toString();
    final avail = p['available'] as int;
    return Card(
      color: _panel,
      margin: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: out ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p['image'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 3 / 2,
                    child: Image.network('$base${p['image']}', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ),
              ),
            Row(children: [
              Expanded(child: Text((ar ? p['name_ar'] : p['name']).toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              if (suggested.contains(id)) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _ok.withOpacity(0.18), borderRadius: BorderRadius.circular(10)), child: Text(t('suggested'), style: const TextStyle(color: _ok, fontSize: 11))),
              const SizedBox(width: 8),
              Text('${(p['price'] as num).toStringAsFixed(3)} ${t('bd')}', style: const TextStyle(color: _violetSoft, fontWeight: FontWeight.w800)),
            ]),
            if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(desc, style: const TextStyle(color: _mute, fontSize: 13))),
            if (p['calories'] != null && (p['calories'] as num) > 0)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text('${p['calories']} ${t('cal')}  ·  ${p['protein']}g ${t('prot')}', style: const TextStyle(fontSize: 12))),
            const SizedBox(height: 8),
            Row(children: [
              Text(out ? t('sold_out') : '$avail ${t('left_n')}', style: TextStyle(color: out ? _bad : _ok, fontSize: 12)),
              const Spacer(),
              if (!out) ...[
                IconButton(onPressed: q > 0 ? () => setState(() { if (q == 1) { cart.remove(id); } else { cart[id] = q - 1; } }) : null, icon: const Icon(Icons.remove_circle_outline)),
                Text('$q', style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(onPressed: q < avail ? () => setState(() => cart[id] = q + 1) : null, icon: const Icon(Icons.add_circle_outline)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  Widget ordersView() {
    if (orders.isEmpty) return const SizedBox.shrink();
    final ar = lang.value == 'ar';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text(t('my_orders'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 6),
      for (final o in orders.take(5))
        Card(
          color: _panel,
          child: ListTile(
            title: Text('#${o['id']}  ·  ${(o['total'] as num).toStringAsFixed(3)} ${t('bd')}'),
            subtitle: Text(((o['items'] as List<dynamic>).map((i) => '${i['qty']}× ${ar ? i['name_ar'] : i['name']}').join('، ')) + '\n' + t('st_${o['status']}')),
            isThreeLine: true,
            trailing: o['status'] == 'pending'
                ? TextButton(
                    onPressed: () async {
                      try {
                        await authCall('POST', '/api/customer/orders/${o['id']}/cancel');
                      } catch (_) {}
                      await loadMenu();
                      await loadOrders();
                    },
                    child: Text(t('cancel')))
                : null,
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final list = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Stack(children: [
      ListView(padding: EdgeInsets.fromLTRB(18, 14, 18, cart.isEmpty ? 24 : 100), children: [
        const NewsBar(),
        Wrap(spacing: 8, children: [
          for (final b in branches)
            ChoiceChip(label: Text(bn(Map<String, dynamic>.from(b as Map))), selected: bid == b['id'], onSelected: (_) { cart.clear(); bid = b['id'] as int; loadMenu(); }),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final g in const ['', 'muscle', 'cut', 'light'])
            ChoiceChip(label: Text(t(g.isEmpty ? 'goal_all' : 'goal_$g')), selected: goal == g, onSelected: (_) { goal = g; loadMenu(); }),
        ]),
        const SizedBox(height: 12),
        if (loading)
          const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
        else if (err != null)
          Center(child: Column(children: [Text(err!, style: const TextStyle(color: _bad)), OutlinedButton(onPressed: init, child: Text(t('ok')))]))
        else if (list.every((p) => p['sold_out'] == true))
          Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('empty_menu'), style: const TextStyle(color: _mute))))
        else ...[
          for (final p in list.where((p) => suggested.contains(p['id']))) card(p),
          for (final p in list.where((p) => !suggested.contains(p['id']))) card(p),
        ],
        if (cart.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Row(children: [
              Expanded(child: TextField(controller: couponCtrl, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(hintText: t('coupon'), isDense: true))),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: applyCoupon, child: Text(t('apply'))),
            ]),
          ),
        ordersView(),
      ]),
      if (cart.isNotEmpty)
        Positioned(
          left: 18, right: 18, bottom: 16,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: _violet),
            onPressed: busy ? null : order,
            child: Text('${t('order_now')}  ·  ${total.toStringAsFixed(3)} ${t('bd')}'),
          ),
        ),
    ]);
  }
}

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});
  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  int seg = 0;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [ButtonSegment(value: 0, label: Text(t('recovery'))), ButtonSegment(value: 1, label: Text(t('progress'))), ButtonSegment(value: 2, label: Text(t('challenges')))],
          selected: {seg},
          onSelectionChanged: (s) => setState(() => seg = s.first),
        ),
      ),
      Expanded(child: seg == 1 ? const ProgressView() : seg == 2 ? const ChallengesView() : const RecoveryView()),
    ]);
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

class RecoveryView extends StatefulWidget {
  const RecoveryView({super.key});
  @override
  State<RecoveryView> createState() => _RecoveryViewState();
}

class _RecoveryViewState extends State<RecoveryView> {
  List<dynamic> branches = [];
  int bi = 0;
  int si = 0;
  int dayOff = 0;
  List<dynamic> slots = [];
  List<dynamic> mine = [];
  List<dynamic> credits = [];
  List<dynamic> packages = [];
  bool loading = true;
  String? err;

  @override
  void initState() {
    super.initState();
    init();
  }

  String get date => _ymd(DateTime.now().toUtc().add(Duration(hours: 3, days: dayOff)));

  Future<void> init() async {
    try {
      final r = await getJson('/api/public/recovery');
      branches = r['items'] as List<dynamic>;
      try {
        final pk = await getJson('/api/public/recovery/packages');
        packages = pk['items'] as List<dynamic>;
      } catch (_) {}
      await loadSlots();
      await loadMine();
    } catch (_) {
      if (mounted) setState(() { err = t('net'); loading = false; });
    }
  }

  List<dynamic> get services => branches.isEmpty ? [] : ((branches[bi] as Map)['services'] as List<dynamic>);

  Future<void> loadSlots() async {
    if (services.isEmpty) {
      if (mounted) setState(() { slots = []; loading = false; });
      return;
    }
    if (si >= services.length) si = 0;
    setState(() => loading = true);
    try {
      final r = await getJson('/api/public/recovery/slots?service_id=${(services[si] as Map)['id']}&date=$date');
      if (mounted) setState(() { slots = r['slots'] as List<dynamic>; loading = false; err = null; });
    } catch (_) {
      if (mounted) setState(() { err = t('net'); loading = false; });
    }
  }

  Future<void> loadMine() async {
    if (custToken == null) return;
    try {
      final r = await authCall('GET', '/api/customer/recovery');
      final c = await authCall('GET', '/api/customer/credits');
      if (mounted) setState(() { mine = r['items'] as List<dynamic>; credits = c['items'] as List<dynamic>; });
    } catch (_) {}
  }

  Future<void> book(String time) async {
    if (custToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('need_login2'))));
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
      return;
    }
    final ar = lang.value == 'ar';
    final sv = Map<String, dynamic>.from(services[si] as Map);
    final b = Map<String, dynamic>.from(branches[bi] as Map);
    final kind = sv['kind'] as String;
    final haveCredit = credits.any((c) => (c as Map)['kind'] == kind && ((c['remaining'] as num) > 0));
    final price = sv['price'] == null ? '' : '${(sv['price'] as num).toStringAsFixed(1)} ${t('bd')}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        title: Text(t('confirm_q')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t(kind)}  ·  ${sv['slot_minutes']} ${t('slot_min')}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('${t('branch_l')}: ${bn(b)}'),
          Text('${t('date_l')}: $date'),
          Text('${t('time_l')}: $time'),
          const SizedBox(height: 6),
          Text(haveCredit ? t('from_package') : (price.isEmpty ? t('pay_at_desk') : '$price  ·  ${t('pay_at_desk')}'), style: TextStyle(color: haveCredit ? _ok : _violetSoft)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('confirm_book'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final br = await authCall('POST', '/api/customer/recovery/book', {'service_id': sv['id'], 'date': date, 'time': time});
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _panel,
            title: Row(children: [const Icon(Icons.check_circle, color: _ok), const SizedBox(width: 8), Expanded(child: Text(t('book_done')))]),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${t('ref')}: ${br['ref']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 6),
              Text('${t(kind)}  ·  ${ar ? (br['branch_ar'] ?? br['branch']) : br['branch']}'),
              Text('${br['date']}  ${br['time']}'),
              if (br['used_credit'] == true) Padding(padding: const EdgeInsets.only(top: 6), child: Text(t('used_credit'), style: const TextStyle(color: _ok))),
              const SizedBox(height: 10),
              Text(t('arrive_early'), style: const TextStyle(color: _mute, fontSize: 12)),
            ]),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t('done')))],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    await loadSlots();
    await loadMine();
  }

  String bn(Map b) => lang.value == 'ar' ? ((b['name_ar'] ?? b['name']) as String) : (b['name'] as String);

  @override
  Widget build(BuildContext context) {
    final ar = lang.value == 'ar';
    final dayNames = t('days').split(',');
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    return ListView(padding: const EdgeInsets.all(18), children: [
      if (err != null) Center(child: Column(children: [Text(err!, style: const TextStyle(color: _bad)), OutlinedButton(onPressed: init, child: Text(t('ok')))])),
      if (credits.isNotEmpty)
        Card(
          color: _panel,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('my_sessions'), style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final raw in credits)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${t((raw as Map)['kind'] as String)}: ${raw['remaining']} ${t('sessions_n')}  ·  ${raw['expires']}', style: const TextStyle(color: _ok)),
                ),
            ]),
          ),
        ),
      if (packages.isNotEmpty)
        Card(
          color: _panel,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('pkg_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final raw in packages)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Expanded(child: Text(ar ? ((raw as Map)['name_ar'] ?? raw['name']).toString() : (raw as Map)['name'].toString())),
                    Text('${(raw['price'] as num).toStringAsFixed(1)} ${t('bd')}', style: const TextStyle(color: _violetSoft, fontWeight: FontWeight.w800)),
                  ]),
                ),
              const SizedBox(height: 6),
              Text(t('pkg_hint'), style: const TextStyle(color: _mute, fontSize: 12)),
            ]),
          ),
        ),
      Wrap(spacing: 8, children: [
        for (var i = 0; i < branches.length; i++)
          ChoiceChip(label: Text(bn(Map<String, dynamic>.from(branches[i] as Map))), selected: bi == i, onSelected: (_) { bi = i; si = 0; loadSlots(); }),
      ]),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        for (var i = 0; i < services.length; i++)
          ChoiceChip(
            label: Text('${t((services[i] as Map)['kind'] as String)}  ·  ${(services[i] as Map)['slot_minutes']} ${t('slot_min')}${(services[i] as Map)['price'] != null ? '  ·  ${((services[i] as Map)['price'] as num).toStringAsFixed(1)} ${t('bd')}' : ''}'),
            selected: si == i,
            onSelected: (_) { si = i; loadSlots(); },
          ),
      ]),
      const SizedBox(height: 6),
      SizedBox(
        height: 46,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var d = 0; d < 7; d++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(d == 0 ? t('today') : d == 1 ? t('tomorrow') : '${dayNames[now.add(Duration(days: d)).weekday % 7]} ${now.add(Duration(days: d)).day}'),
                selected: dayOff == d,
                onSelected: (_) { dayOff = d; loadSlots(); },
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      if (loading)
        const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (slots.isEmpty)
        Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('no_slots'), style: const TextStyle(color: _mute))))
      else
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final raw in slots)
            Builder(builder: (context) {
              final sl = Map<String, dynamic>.from(raw as Map);
              final off = sl['full'] == true || sl['past'] == true;
              return SizedBox(
                width: 104,
                child: OutlinedButton(
                  onPressed: off ? null : () => book(sl['time'] as String),
                  child: Column(children: [
                    Text(sl['time'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(sl['full'] == true ? t('full') : '${sl['free']} ${t('seats_n')}', style: TextStyle(fontSize: 11, color: off ? _mute : _ok)),
                  ]),
                ),
              );
            }),
        ]),
      if (mine.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(t('my_rec'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        for (final raw in mine)
          Builder(builder: (context) {
            final m = Map<String, dynamic>.from(raw as Map);
            return Card(
              color: _panel,
              child: ListTile(
                title: Text('${t(m['kind'] as String)}  ·  ${m['date']}  ${m['time']}'),
                subtitle: Text('${ar ? (m['branch_ar'] ?? m['branch']) : m['branch']}  ·  ${t('st_${m['status']}')}'),
                trailing: m['status'] == 'booked'
                    ? TextButton(
                        onPressed: () async {
                          try {
                            await authCall('POST', '/api/customer/recovery/${m['id']}/cancel');
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                          }
                          await loadSlots();
                          await loadMine();
                        },
                        child: Text(t('cancel')))
                    : null,
              ),
            );
          }),
      ],
    ]);
  }
}

class ChallengesView extends StatefulWidget {
  const ChallengesView({super.key});
  @override
  State<ChallengesView> createState() => _ChallengesViewState();
}

class _ChallengesViewState extends State<ChallengesView> {
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (custToken == null) return;
    try {
      final r = await authCall('GET', '/api/customer/challenges');
      if (mounted) setState(() => data = r);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (custToken == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t('need_login2'), textAlign: TextAlign.center, style: const TextStyle(color: _mute)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _violet),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())).then((_) => load()),
              child: Text(t('login')),
            ),
          ]),
        ),
      );
    }
    final items = (data?['items'] as List<dynamic>? ?? []);
    final ar = lang.value == 'ar';
    return ListView(padding: const EdgeInsets.all(18), children: [
      if (data != null && data!['linked'] != true)
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: _warn.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
          child: Text(t('ch_link'), style: const TextStyle(color: _warn)),
        ),
      if (data != null && items.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('ch_none'), style: const TextStyle(color: _mute)))),
      for (final raw in items)
        Builder(builder: (context) {
          final c = Map<String, dynamic>.from(raw as Map);
          final target = (c['target'] as num).toInt();
          final count = (c['count'] as num).toInt();
          final board = (c['board'] as List<dynamic>);
          return Card(
            color: _panel,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text((ar ? c['title_ar'] : c['title']).toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  if (c['done'] == true) const Icon(Icons.emoji_events, color: _warn),
                ]),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: (count / target).clamp(0.0, 1.0), minHeight: 8, color: c['done'] == true ? _ok : _violet, backgroundColor: _line),
                const SizedBox(height: 6),
                Text('$count / $target ${t(c['metric'] == 'classes' ? 'ch_classes' : 'ch_visits')}${c['done'] == true ? '  ·  ${t('ch_done')}' : ''}', style: const TextStyle(color: _mute, fontSize: 12)),
                if (board.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(t('ch_board'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  for (var i = 0; i < board.length; i++) Text('${i + 1}.  ${(board[i] as Map)['name']}  ·  ${(board[i] as Map)['n']}', style: const TextStyle(color: _mute)),
                ],
              ]),
            ),
          );
        }),
    ]);
  }
}

class ProgressView extends StatefulWidget {
  const ProgressView({super.key});
  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> {
  Map<String, dynamic>? data;
  bool busy = false;
  final kg = TextEditingController();
  final cm = TextEditingController();
  final fat = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (custToken == null) return;
    try {
      final r = await authCall('GET', '/api/customer/body');
      if (mounted) setState(() => data = r);
    } catch (_) {}
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await authCall('POST', '/api/customer/body', {
        'weight_kg': double.tryParse(kg.text.trim()) ?? 0,
        if (cm.text.trim().isNotEmpty) 'height_cm': double.tryParse(cm.text.trim()),
        if (fat.text.trim().isNotEmpty) 'body_fat': double.tryParse(fat.text.trim()),
      });
      kg.clear();
      fat.clear();
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Color catColor(String? c) => c == 'normal' ? _ok : c == 'under' ? _warn : _bad;

  @override
  Widget build(BuildContext context) {
    if (custToken == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t('need_login2'), textAlign: TextAlign.center, style: const TextStyle(color: _mute)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _violet),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())).then((_) => load()),
              child: Text(t('login')),
            ),
          ]),
        ),
      );
    }
    final latest = data?['latest'] is Map ? Map<String, dynamic>.from(data!['latest'] as Map) : null;
    final items = (data?['items'] as List<dynamic>? ?? []).reversed.toList();
    return ListView(padding: const EdgeInsets.all(18), children: [
      if (latest != null)
        Card(
          color: _panel,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${latest['weight_kg']} kg', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  Text('${t('change')}: ${data!['change_kg']} kg', style: const TextStyle(color: _mute)),
                ]),
              ),
              if (latest['bmi'] != null)
                Column(children: [
                  Text(t('bmi'), style: const TextStyle(color: _mute, fontSize: 12)),
                  Text('${latest['bmi']}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: catColor(latest['category'] as String?))),
                  Text(t('bmi_${latest['category']}'), style: TextStyle(color: catColor(latest['category'] as String?), fontSize: 12)),
                ]),
            ]),
          ),
        ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: kg, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('weight'), border: const OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: cm, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('height'), border: const OutlineInputBorder()))),
      ]),
      const SizedBox(height: 8),
      TextField(controller: fat, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('body_fat'), border: const OutlineInputBorder())),
      const SizedBox(height: 10),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: _violet),
        onPressed: busy ? null : save,
        child: Text(t('save_entry')),
      ),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(t('history'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        for (final raw in items)
          Builder(builder: (context) {
            final e = Map<String, dynamic>.from(raw as Map);
            return ListTile(
              dense: true,
              title: Text('${e['date']}  ·  ${e['weight_kg']} kg${e['bmi'] != null ? '  ·  ${t('bmi')} ${e['bmi']}' : ''}${e['body_fat'] != null ? '  ·  ${e['body_fat']}%' : ''}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  try {
                    await authCall('POST', '/api/customer/body/${e['id']}/delete');
                  } catch (_) {}
                  await load();
                },
              ),
            );
          }),
      ],
    ]);
  }
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool signup = false;
  bool busy = false;
  String? msg;
  bool msgOk = false;
  bool otpSent = false;
  int freezeDays = 7;
  final user = TextEditingController();
  final pass = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final code = TextEditingController();
  final email = TextEditingController();
  final otp = TextEditingController();

  void _leaveWhenPass() {
    if (tokenN.value != null && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void initState() {
    super.initState();
    tokenN.addListener(_leaveWhenPass);
    refreshAccount();
  }

  @override
  void dispose() {
    tokenN.removeListener(_leaveWhenPass);
    super.dispose();
  }

  Future<void> run(Future<void> Function() f, {String? ok}) async {
    setState(() { busy = true; msg = null; });
    try {
      await f();
      if (!mounted) return;
      setState(() { msg = ok; msgOk = ok != null; });
    } catch (e) {
      if (mounted) setState(() { msg = e.toString() == 'net' ? t('net') : e.toString(); msgOk = false; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    await run(() async {
      final r = signup
          ? await authCall('POST', '/api/customer/signup', {'username': user.text.trim(), 'password': pass.text, 'name': name.text.trim(), 'phone': phone.text.trim()})
          : await authCall('POST', '/api/customer/login', {'username': user.text.trim(), 'password': pass.text});
      await applyAccount(r);
    });
  }

  Widget field(TextEditingController c, String label, {bool secret = false, TextInputType? kb}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, obscureText: secret, keyboardType: kb, autocorrect: false, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
      );

  Widget statusMsg() => msg == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(msg!, style: TextStyle(color: msgOk ? _ok : _bad)));

  Widget authForm() => ListView(padding: const EdgeInsets.all(22), children: [
        brand(),
        const SizedBox(height: 24),
        Text(t(signup ? 'signup' : 'login'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        if (signup) field(name, t('fullname')),
        field(user, t('username')),
        if (signup) field(phone, t('phone'), kb: TextInputType.phone),
        field(pass, t('password'), secret: true),
        statusMsg(),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: _violet),
          onPressed: busy ? null : submit,
          child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(t(signup ? 'signup' : 'login')),
        ),
        TextButton(onPressed: () => setState(() { signup = !signup; msg = null; }), child: Text(t(signup ? 'have_acc' : 'no_acc'))),
      ]);

  Widget accountView(Map<String, dynamic> d) {
    final a = Map<String, dynamic>.from(d['account'] as Map);
    final sub = d['subscription'] as String? ?? 'none';
    final m = d['member'] is Map ? Map<String, dynamic>.from(d['member'] as Map) : null;
    final ar = lang.value == 'ar';
    return ListView(padding: const EdgeInsets.all(22), children: [
      Card(
        color: _panel,
        child: ListTile(
          leading: const Icon(Icons.person, color: _violetSoft),
          title: Text(a['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('@${a['username']}  ·  ${a['phone']}'),
        ),
      ),
      const SizedBox(height: 8),
      if (m != null)
        Card(
          color: _panel,
          child: ListTile(
            leading: Icon(sub == 'active' ? Icons.check_circle : Icons.warning_amber, color: sub == 'active' ? _ok : _warn),
            title: Text((ar ? (m['plan_ar'] ?? m['plan']) : m['plan']).toString()),
            subtitle: Text('${ar ? (m['branch_ar'] ?? m['branch']) : m['branch']}  ·  ${t('ends')} ${m['end_date']}'),
          ),
        ),
      if (m != null && sub == 'frozen')
        Padding(padding: const EdgeInsets.only(top: 8), child: Text('${t('frozen_until')} ${m['frozen_until']}', style: const TextStyle(color: _warn))),
      if (m != null && a['status'] == 'active' && sub == 'active') ...[
        const SizedBox(height: 12),
        Row(children: [
          Text(t('freeze_days')),
          const SizedBox(width: 10),
          DropdownButton<int>(value: freezeDays, items: [for (final d in const [7, 14, 21, 30]) DropdownMenuItem(value: d, child: Text('$d'))], onChanged: (v) => setState(() => freezeDays = v ?? 7)),
          const Spacer(),
          OutlinedButton(onPressed: busy ? null : () => run(() async { await authCall('POST', '/api/customer/freeze', {'days': freezeDays}); }, ok: t('freeze_sent')), child: Text(t('freeze_send'))),
        ]),
      ],
      if (a['status'] != 'active' || m == null) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _warn.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
          child: Text(m == null ? t('pending_msg') : t('sub_expired'), style: const TextStyle(color: _warn)),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: TextField(controller: code, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('link_code'), border: const OutlineInputBorder()))),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _violet, minimumSize: const Size(80, 56)),
            onPressed: busy ? null : () => run(() async => applyAccount(await authCall('POST', '/api/customer/link', {'code': code.text.trim()}))),
            child: Text(t('link_btn')),
          ),
        ]),
      ],
      const SizedBox(height: 20),
      if (a['email_verified'] == true)
        Row(children: [const Icon(Icons.verified, color: _ok, size: 18), const SizedBox(width: 6), Text('${t('email_ok')}: ${a['email']}')])
      else ...[
        Row(children: [
          Expanded(child: TextField(controller: email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: InputDecoration(labelText: t('email'), border: const OutlineInputBorder()))),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(80, 56)),
            onPressed: busy ? null : () => run(() async {
              await authCall('POST', '/api/customer/email', {'email': email.text.trim()});
              otpSent = true;
            }, ok: t('done')),
            child: Text(t('send_code')),
          ),
        ]),
        if (otpSent) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: otp, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('otp'), border: const OutlineInputBorder()))),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _violet, minimumSize: const Size(80, 56)),
              onPressed: busy ? null : () => run(() async {
                await authCall('POST', '/api/customer/email/verify', {'code': otp.text.trim()});
                await refreshAccount();
              }, ok: t('email_ok')),
              child: Text(t('verify')),
            ),
          ]),
        ],
      ],
      const SizedBox(height: 12),
      statusMsg(),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () async {
          await clearAccount();
          final p = await SharedPreferences.getInstance();
          await p.remove('token');
          tokenN.value = null;
        },
        child: Text(t('logout')),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('acct')), actions: [IconButton(tooltip: t('upd_check'), icon: const Icon(Icons.system_update), onPressed: () => checkAppUpdate(context))]),
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: acctN,
        builder: (context, d, _) => d == null ? authForm() : accountView(d),
      ),
    );
  }
}

class LinkScreen extends StatefulWidget {
  final bool canBack;
  const LinkScreen({super.key, this.canBack = false});
  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  final ctrl = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> link(String text) async {
    setState(() { busy = true; error = null; });
    final ok = await tryLink(text);
    if (!mounted) return;
    setState(() { busy = false; if (!ok) error = t('bad_link'); });
    if (ok && widget.canBack && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanPage()));
    if (code != null) await link(code);
  }

  Future<void> paste() async {
    final d = await Clipboard.getData('text/plain');
    if (d?.text != null) {
      ctrl.text = d!.text!;
      await link(d.text!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [TextButton(onPressed: () => setLang(lang.value == 'ar' ? 'en' : 'ar'), child: Text(t('lang')))]),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 10),
        brand(),
        const SizedBox(height: 36),
        Text(t('link_title'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(t('link_body'), textAlign: TextAlign.center, style: const TextStyle(color: _mute)),
        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: _violet),
          onPressed: busy ? null : scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(t('scan_qr')),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: busy ? null : paste,
          icon: const Icon(Icons.content_paste),
          label: Text(t('paste')),
        ),
        const SizedBox(height: 12),
        TextField(controller: ctrl, decoration: InputDecoration(hintText: t('link_hint'), border: const OutlineInputBorder()), onSubmitted: link),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: busy ? null : () => link(ctrl.text), child: Text(t('link_btn'))),
        if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: _bad))),
      ]),
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool done = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('scan_qr'))),
      body: MobileScanner(
        onDetect: (capture) {
          if (done) return;
          for (final b in capture.barcodes) {
            final v = b.rawValue;
            if (v != null && parseLink(v) != null) {
              done = true;
              Navigator.pop(context, v);
              return;
            }
          }
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String token;
  const HomeScreen({super.key, required this.token});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? d;
  String? err;
  int left = 0;
  int tab = 0;
  Timer? timer;
  int tickN = 0;
  Map<String, dynamic>? bk;
  Map<String, dynamic> notes = {'unread': 0, 'items': <dynamic>[]};
  String aud = 'men';
  int dsel = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (left > 0) {
        setState(() => left--);
      } else if (d != null) {
        load();
      }
      if (++tickN % 30 == 0) {
        loadNotes();
        if (tab == 2) loadBooking();
      }
    });
    loadNotes();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkUpdate(false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    try {
      final r = await getJson('/api/pass/${widget.token}');
      if (mounted) setState(() { d = r; err = null; left = (r['seconds_left'] as num).toInt(); });
    } catch (e) {
      if (mounted) setState(() => err = e == 'bad_pass' ? 'bad_pass' : (d == null ? 'net' : null));
    }
  }

  Future<void> loadBooking() async {
    try {
      final r = await getJson('/api/pass/${widget.token}/booking');
      if (mounted) setState(() => bk = r);
    } catch (_) {}
  }

  Future<void> loadNotes() async {
    try {
      final r = await getJson('/api/pass/${widget.token}/notifications');
      if (mounted) setState(() => notes = r);
    } catch (_) {}
  }

  Future<void> act(String path, Map<String, dynamic> body) async {
    try {
      await postJson('/api/pass/${widget.token}$path', body);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    await loadBooking();
    await loadNotes();
  }

  Future<void> openNotes() async {
    await loadNotes();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NotesScreen(items: notes['items'] as List<dynamic>)));
    try {
      await postJson('/api/pass/${widget.token}/notifications/read', {});
    } catch (_) {}
    await loadNotes();
  }

  Future<void> checkUpdate(bool manual) async {
    if (Platform.isIOS) return; // APK updates are Android only
    try {
      final r = await getJson('/api/app/version?app=member');
      final build = (r['build'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      if (build > appBuild && r['url'] is String) {
        final notes = (r['notes'] as String?) ?? '';
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t('upd_title')),
            content: Text(notes.isEmpty ? t('upd_body') : '${t('upd_body')}\n\n$notes'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('upd_later'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('upd_now'))),
            ],
          ),
        );
        if (go == true && mounted) await installAppUpdate(context, r['url'] as String);
      } else if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('upd_none'))));
      }
    } catch (_) {}
  }

  Future<void> unlink() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t('unlink_q')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('ok'))),
        ],
      ),
    );
    if (ok != true) return;
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('ctoken');
    custToken = null;
    acctN.value = null;
    tokenN.value = null;
  }

  Color statusColor(String s) => s == 'active' ? _ok : s == 'expiring' ? _warn : _bad;
  bool get valid => d != null && (d!['status'] == 'active' || d!['status'] == 'expiring');

  Widget pill(String s) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(color: statusColor(s).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(t(s), style: TextStyle(color: statusColor(s), fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget card(Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _panel, border: Border.all(color: _line), borderRadius: BorderRadius.circular(22)),
        child: child,
      );

  Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: _mute)),
          Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );

  Widget passTab() {
    final x = d!;
    final planName = (lang.value == 'ar' ? (x['plan_ar'] ?? x['plan']) : x['plan']) ?? '';
    return ListView(padding: const EdgeInsets.all(18), children: [
      card(Column(children: [
        if (valid) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: QrImageView(data: x['code'] as String, size: 230, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (left / 30).clamp(0.0, 1.0), minHeight: 6, backgroundColor: _line, color: _violet)),
          const SizedBox(height: 8),
          Text(t('scan_hint'), textAlign: TextAlign.center, style: const TextStyle(color: _mute, fontSize: 12)),
        ] else
          Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Text(t('noacc'), style: const TextStyle(color: _bad, fontSize: 16))),
        const SizedBox(height: 14),
        Text(x['name'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text('$planName${x['branch'] != null ? ' · ${lang.value == 'ar' ? (x['branch_ar'] ?? x['branch']) : x['branch']}' : ''}', style: const TextStyle(color: _mute)),
        pill(x['status'] as String),
      ])),
    ]);
  }

  Widget meTab() {
    final x = d!;
    final dl = ((x['days_left'] as num).toInt()).clamp(0, 99999);
    final planName = (lang.value == 'ar' ? (x['plan_ar'] ?? x['plan']) : x['plan']) ?? '';
    return ListView(padding: const EdgeInsets.all(18), children: [
      card(Column(children: [
        Text('$dl', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: _violetSoft, height: 1)),
        Text(t('left'), style: const TextStyle(color: _mute)),
        pill(x['status'] as String),
      ])),
      card(Column(children: [
        row(t('plan'), '$planName'),
        row(t('branch'), '${(lang.value == 'ar' ? (x['branch_ar'] ?? x['branch']) : x['branch']) ?? ''}'),
        row(t('ends'), '${x['end_date']}'),
      ])),
      Text(t('renew'), textAlign: TextAlign.center, style: const TextStyle(color: _mute, fontSize: 13)),
    ]);
  }

  int minLeft(String? iso) {
    if (iso == null) return 0;
    final ms = DateTime.parse('${iso.replaceFirst(' ', 'T')}Z').millisecondsSinceEpoch - (DateTime.now().millisecondsSinceEpoch + 3 * 3600000);
    return (ms / 60000).ceil().clamp(0, 9999).toInt();
  }

  Widget slotCard(Map<String, dynamic> r, String date, String? ban) {
    final status = r['my_status'] as String?;
    final full = r['full'] == true;
    final actions = <Widget>[];
    Widget btn(String label, VoidCallback f, {bool alt = false}) => alt
        ? OutlinedButton(onPressed: f, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), child: Text(label))
        : FilledButton(onPressed: f, style: FilledButton.styleFrom(minimumSize: const Size(0, 38), backgroundColor: _violet), child: Text(label));
    Widget chip(String label, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
        );
    if (status == 'booked') {
      actions.add(chip(t('booked'), _ok));
      if (r['can_cancel'] == true) {
        actions.add(btn(t('cancel_booking'), () => act('/cancel', {'booking_id': r['my_booking_id']}), alt: true));
      } else {
        actions.add(Text(t('toolate'), style: const TextStyle(color: _mute, fontSize: 11)));
      }
    } else if (status == 'waitlist') {
      actions.add(chip(t('onwait'), _warn));
      actions.add(btn(t('cancel_booking'), () => act('/cancel', {'booking_id': r['my_booking_id']}), alt: true));
    } else if (status == 'offered') {
      actions.add(chip('${t('free')} · ${minLeft(r['offer_expires_at'] as String?)}m', _ok));
      actions.add(btn(t('accept'), () => act('/offer', {'booking_id': r['my_booking_id'], 'accept': true})));
      actions.add(btn(t('decline'), () => act('/offer', {'booking_id': r['my_booking_id'], 'accept': false}), alt: true));
    } else if (status == 'attended') {
      actions.add(chip(t('attended'), _ok));
    } else if (r['closed'] == true) {
      actions.add(Text(t('closed'), style: const TextStyle(color: _mute, fontSize: 12)));
    } else if (ban == null) {
      actions.add(btn(full ? t('waitjoin') : t('book'), () => act('/book', {'schedule_id': r['schedule_id'], 'date': date}), alt: full));
    }
    final sub = full
        ? '${t('full')}${(r['waitlist'] as num) > 0 ? ' · ${r['waitlist']} ${t('wait_n')}' : ''}'
        : '${r['free']}/${r['capacity']} ${t('free')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: _panel, border: Border.all(color: _line), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Directionality(textDirection: TextDirection.ltr, child: Text('${r['time']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          const SizedBox(width: 10),
          Expanded(child: Text(t('${r['level']}'), style: const TextStyle(color: _mute))),
          Text(sub, style: const TextStyle(color: _mute, fontSize: 12)),
        ]),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
        ],
      ]),
    );
  }

  Widget classesTab() {
    final b = bk;
    if (b == null) return const Center(child: CircularProgressIndicator());
    final dates = b['dates'] as List<dynamic>;
    final dd = Map<String, dynamic>.from(dates[dsel] as Map);
    final ban = b['ban_until'] as String?;
    final strikes = (b['strikes'] as num).toInt();
    final rows = (dd['items'] as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).where((r) => r['audience'] == aud).toList();
    return ListView(padding: const EdgeInsets.all(18), children: [
      RatePrompt(token: widget.token),
      const NewsBar(),
      if (ban != null)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _bad.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
          child: Text('${t('paused')} $ban', style: const TextStyle(color: _bad)),
        )
      else if (strikes > 0)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('$strikes/${b['max_strikes']} ${t('strikes')}', style: const TextStyle(color: _mute, fontSize: 12))),
      Row(children: [
        for (final a in ['men', 'ladies'])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(label: SizedBox(width: double.infinity, child: Text(t(a), textAlign: TextAlign.center)), selected: aud == a, onSelected: (_) => setState(() => aud = a)),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < 2; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(label: SizedBox(width: double.infinity, child: Text(t(i == 0 ? 'today' : 'tomorrow'), textAlign: TextAlign.center)), selected: dsel == i, onSelected: (_) => setState(() => dsel = i)),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      if (dd['rest'] == true)
        Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('rest'), style: const TextStyle(color: _mute))))
      else if (rows.isEmpty)
        Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('none'), style: const TextStyle(color: _mute))))
      else
        for (final r in rows) slotCard(r, dd['date'] as String, ban),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (d == null && err == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (d == null || err == 'bad_pass') {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t(err == 'bad_pass' ? 'bad_pass' : 'net'), textAlign: TextAlign.center, style: const TextStyle(color: _bad)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: err == 'bad_pass' ? unlink : load, child: Text(err == 'bad_pass' ? t('relink') : t('ok'))),
          ]),
        ),
      );
    } else {
      body = tab == 0 ? passTab() : tab == 1 ? meTab() : tab == 2 ? classesTab() : tab == 3 ? const StoreScreen() : const WellnessScreen();
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('UNDERGROUND', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: openNotes,
            icon: Badge(
              isLabelVisible: ((notes['unread'] as num?) ?? 0) > 0,
              label: Text('${notes['unread']}'),
              child: const Icon(Icons.notifications_none),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'lang') setLang(lang.value == 'ar' ? 'en' : 'ar');
              if (v == 'upd') checkUpdate(true);
              if (v == 'out') unlink();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'lang', child: Text(t('lang'))),
              PopupMenuItem(value: 'upd', child: Text('${t('upd_check')}  (v$appBuild)')),
              PopupMenuItem(value: 'out', child: Text(t('unlink'))),
            ],
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        backgroundColor: _panel,
        selectedIndex: tab,
        onDestinationSelected: (i) {
          setState(() => tab = i);
          if (i == 2) loadBooking();
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.qr_code_2), label: t('pass')),
          NavigationDestination(icon: const Icon(Icons.badge_outlined), label: t('me')),
          NavigationDestination(icon: const Icon(Icons.fitness_center), label: t('cls')),
          NavigationDestination(icon: const Icon(Icons.restaurant_menu), label: t('store')),
          NavigationDestination(icon: const Icon(Icons.spa_outlined), label: t('well')),
        ],
      ),
    );
  }
}

class NotesScreen extends StatelessWidget {
  final List<dynamic> items;
  const NotesScreen({super.key, required this.items});
  @override
  Widget build(BuildContext context) {
    final ar = lang.value == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(t('bell'))),
      body: items.isEmpty
          ? Center(child: Text(t('nonotif'), style: const TextStyle(color: _mute)))
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final raw in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _panel, border: Border.all(color: _line), borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(((raw as Map)[ar ? 'title_ar' : 'title_en'] ?? '') as String, style: TextStyle(fontWeight: FontWeight.w800, color: raw['read_at'] == null ? _violetSoft : _text)),
                    const SizedBox(height: 4),
                    Text(((raw)[ar ? 'body_ar' : 'body_en'] ?? '') as String, style: const TextStyle(color: _mute)),
                  ]),
                ),
            ]),
    );
  }
}
