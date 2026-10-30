import 'dart:async';
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
    'upd_body': 'حمّل التحديث ثم اضغط على الملف للتثبيت.', 'upd_now': 'تحديث', 'upd_later': 'لاحقاً',
    'upd_none': 'لديك آخر إصدار', 'loading': 'جاري التحميل...',
    'days': 'الأحد,الاثنين,الثلاثاء,الأربعاء,الخميس,الجمعة,السبت',
    'today': 'اليوم', 'tomorrow': 'غداً', 'book': 'احجز', 'waitjoin': 'قائمة الانتظار', 'full': 'مكتمل', 'free': 'متاح',
    'cancel_booking': 'إلغاء الحجز', 'booked': 'تم الحجز', 'onwait': 'في قائمة الانتظار', 'accept': 'تأكيد', 'decline': 'رفض',
    'closed': 'انتهى التسجيل', 'attended': 'حضرت', 'toolate': 'الإلغاء قبل ساعة على الأقل', 'paused': 'الحجز موقوف حتى',
    'strikes': 'إلغاءات متتالية', 'g_hint': 'للحجز وعرض بطاقتك سجّل الدخول', 'g_link': 'تسجيل الدخول', 'g_need': 'سجّل الدخول أولاً للحجز', 'g_classes': 'الحصص', 'g_info': 'الفروع', 'g_pass': 'بطاقتي', 'g_pass_body': 'اربط حسابك لعرض بطاقة الدخول والاشتراك.', 'g_branch': 'اختر الفرع', 'g_seats': 'مقعد متاح', 'back': 'رجوع', 'bell': 'الإشعارات', 'nonotif': 'لا توجد إشعارات', 'wait_n': 'بالانتظار', 'err': 'حدث خطأ',
    'acct': 'حسابي', 'login': 'تسجيل الدخول', 'signup': 'إنشاء حساب', 'username': 'اسم المستخدم', 'password': 'كلمة المرور (8 أحرف على الأقل)', 'fullname': 'الاسم', 'phone': 'رقم الهاتف', 'have_acc': 'عندي حساب', 'no_acc': 'ما عندي حساب', 'pending_msg': 'حسابك قيد المراجعة. إذا كنت مشتركاً، أدخل كود الربط من الموظف أو انتظر تفعيل الإدارة.', 'link_code': 'كود الربط من الموظف', 'send_code': 'إرسال الرمز', 'verify': 'تأكيد', 'email': 'البريد الإلكتروني', 'otp': 'رمز التحقق', 'email_ok': 'تم توثيق البريد', 'logout': 'تسجيل الخروج', 'sub_none': 'لا يوجد اشتراك مرتبط بهذا الحساب', 'sub_expired': 'اشتراكك منتهي', 'addr': 'العنوان', 'hours': 'ساعات العمل', 'call': 'اتصال', 'map': 'الخريطة', 'view_classes': 'عرض الحصص', 'done': 'تم',
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
    'upd_body': 'Download the update, then tap the file to install.', 'upd_now': 'Update', 'upd_later': 'Later',
    'upd_none': 'You have the latest version', 'loading': 'Loading...',
    'days': 'Sun,Mon,Tue,Wed,Thu,Fri,Sat',
    'today': 'Today', 'tomorrow': 'Tomorrow', 'book': 'Book', 'waitjoin': 'Join waitlist', 'full': 'Full', 'free': 'free',
    'cancel_booking': 'Cancel booking', 'booked': 'Booked', 'onwait': 'On the waitlist', 'accept': 'Confirm', 'decline': 'Decline',
    'closed': 'Closed', 'attended': 'Attended', 'toolate': 'Cancel at least 1 hour before', 'paused': 'Booking paused until',
    'strikes': 'cancellations in a row', 'bell': 'Notifications', 'nonotif': 'No notifications', 'wait_n': 'waiting', 'err': 'Something went wrong',
    'acct': 'My account', 'login': 'Log in', 'signup': 'Create account', 'username': 'Username', 'password': 'Password (at least 8 characters)', 'fullname': 'Full name', 'phone': 'Phone number', 'have_acc': 'I have an account', 'no_acc': 'I do not have an account', 'pending_msg': 'Your account is under review. If you are a member, enter the link code from the staff or wait for the admin to activate it.', 'link_code': 'Link code from staff', 'send_code': 'Send code', 'verify': 'Verify', 'email': 'Email', 'otp': 'Verification code', 'email_ok': 'Email verified', 'logout': 'Log out', 'sub_none': 'No membership is linked to this account', 'sub_expired': 'Your membership has expired', 'addr': 'Address', 'hours': 'Opening hours', 'call': 'Call', 'map': 'Map', 'view_classes': 'View classes', 'done': 'Done', 'g_hint': 'Log in to book and see your pass', 'g_link': 'Log in', 'g_need': 'Log in first to book', 'g_classes': 'Classes', 'g_info': 'Branches', 'g_pass': 'My pass', 'g_pass_body': 'Log in to see your entry pass and membership.', 'g_branch': 'Choose a branch', 'g_seats': 'seats left', 'back': 'Back',
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
      body: tab == 0 ? classesView() : tab == 1 ? infoView() : passView(),
      bottomNavigationBar: NavigationBar(
        backgroundColor: _panel,
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.fitness_center), label: t('g_classes')),
          NavigationDestination(icon: const Icon(Icons.place_outlined), label: t('g_info')),
          NavigationDestination(icon: const Icon(Icons.qr_code_2), label: t('g_pass')),
        ],
      ),
    );
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
      appBar: AppBar(title: Text(t('acct'))),
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
        if (go == true) await launchUrl(Uri.parse(r['url'] as String), mode: LaunchMode.externalApplication);
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
      body = tab == 0 ? passTab() : tab == 1 ? meTab() : classesTab();
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
