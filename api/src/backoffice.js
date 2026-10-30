// Web back office: served by the Worker at / and /admin. Talks to the same /api endpoints.
export const BACKOFFICE_HTML = String.raw`<!doctype html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>UNDERGROUND – لوحة الإدارة</title>
<style>
:root{--bg:#0a090e;--panel:#14121b;--panel2:#1b1825;--line:#2b2738;--text:#f4f2f8;--mute:#a29cb4;--v:#8a4dff;--vs:#b79bff;--ok:#34d399;--warn:#fbbf24;--bad:#f87171}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:16px/1.5 system-ui,"Segoe UI",Tahoma,sans-serif}
h1,h2,h3{margin:0}header{display:flex;align-items:center;gap:12px;padding:14px 20px;border-bottom:1px solid var(--line);background:var(--panel)}
header b{letter-spacing:3px;font-size:20px}header small{color:var(--vs);letter-spacing:2px}.sp{flex:1}
main{max-width:980px;margin:0 auto;padding:18px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:18px;margin-bottom:16px}
input,select,button{font:inherit;color:var(--text)}
input,select{width:100%;background:var(--bg);border:1px solid var(--line);border-radius:12px;padding:11px 12px}
input:focus,select:focus{outline:2px solid var(--v);border-color:var(--v)}
label{display:block;color:var(--mute);font-size:13px;margin:10px 0 4px}
button{background:var(--v);border:0;border-radius:12px;padding:11px 18px;font-weight:700;cursor:pointer}
button.ghost{background:var(--panel2);border:1px solid var(--line)}button.bad{background:var(--bad);color:#200}
button:disabled{opacity:.5}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px}
.tabs{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:16px}.tabs button{background:var(--panel2);border:1px solid var(--line)}.tabs button.on{background:var(--v);border-color:var(--v)}
table{width:100%;border-collapse:collapse}th,td{padding:10px 8px;border-bottom:1px solid var(--line);text-align:start;vertical-align:middle}th{color:var(--mute);font-weight:600;font-size:13px}
.pill{display:inline-block;padding:2px 10px;border-radius:20px;font-size:12px;font-weight:700}
.ok{background:#34d3991f;color:var(--ok)}.off{background:#f871711f;color:var(--bad)}.vi{background:#8a4dff2b;color:var(--vs)}
.stat{background:var(--panel2);border:1px solid var(--line);border-radius:14px;padding:14px}.stat small{color:var(--mute)}.stat div{font-size:26px;font-weight:800;margin-top:4px}
#toast{position:fixed;bottom:20px;inset-inline:0;margin:auto;width:fit-content;max-width:90%;padding:12px 20px;border-radius:12px;background:var(--v);display:none;z-index:9}
#toast.err{background:var(--bad);color:#200}
.row{display:flex;gap:8px;flex-wrap:wrap}.row>*{flex:1;min-width:130px}.scroll{overflow-x:auto}
.login{max-width:380px;margin:12vh auto}
</style></head><body>
<header><div><b>UNDERGROUND</b><br><small>BACK OFFICE</small></div><div class="sp"></div><span id="who" style="color:var(--mute)"></span><button class="ghost" id="lng" style="margin-inline-end:8px">EN</button><button class="ghost" id="out" style="display:none">تسجيل الخروج</button></header>
<main id="app"></main><div id="toast"></div>
<script>
const $=(s,r=document)=>r.querySelector(s);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

const EN={"لوحة الإدارة": "Admin panel", "تسجيل الخروج": "Sign out", "د.ب": "BD", "تعذّر الاتصال بالخادم": "Cannot reach the server", "انتهت الجلسة": "Session expired", "خطأ": "Error", "تسجيل الدخول": "Sign in", "اسم المستخدم (إنجليزي)": "Username (English letters)", "اسم المستخدم": "Username", "كلمة المرور (8 أحرف على الأقل)": "Password (at least 8 characters)", "كلمة المرور": "Password", "دخول": "Sign in", "هذه اللوحة للمدير فقط": "This panel is for the admin only", "الحسابات": "Accounts", "الباقات والأسعار": "Plans and prices", "ملخص الشهر": "Month summary", "جاري التحميل": "Loading", "إنشاء حساب جديد": "Create a new account", "الاسم": "Name", "الصلاحية": "Role", "موظف": "Staff", "مدير": "Admin", "الفرع": "Branch", "الراتب الشهري (د.ب)": "Monthly salary (BD)", "إنشاء الحساب": "Create account", "توليد كلمة مرور": "Generate password", "المستخدم": "User", "الراتب": "Salary", "الحالة": "Status", "فعّال": "Active", "موقوف": "Disabled", "كلمة مرور جديدة": "New password", "إيقاف": "Disable", "تفعيل": "Enable", "تم إنشاء الحساب": "Account created", "كلمة المرور الجديدة (8 أحرف على الأقل)": "New password (at least 8 characters)", "تم تغيير كلمة المرور": "Password changed", "الباقة": "Plan", "المدة (شهر)": "Duration (months)", "السعر (د.ب)": "Price (BD)", "يوم": "day", "حفظ": "Save", "تم الحفظ": "Saved", "الدخل": "Income", "المصروفات": "Expenses", "الرواتب": "Salaries", "الربح": "Profit", "أعضاء فعّالون": "Active members", "ينتهي خلال 7 أيام": "Ending within 7 days", "للتفاصيل الكاملة استخدم تطبيق الجوال": "For full details use the mobile app", "الأعضاء": "Members", "بحث بالاسم أو الهاتف": "Search by name or phone", "رابط البطاقة": "Card link", "فتح": "Open", "تم نسخ الرابط": "Link copied", "لا توجد نتائج": "No results", "الهاتف": "Phone", "حسابات العملاء": "Customer accounts", "الفروع": "Branches", "كود ربط التطبيق": "App link code", "قيد المراجعة": "Pending", "مفعّل": "Active", "العضو المرتبط": "Linked member", "الايميل": "Email", "فك الربط": "Unlink", "ربط:": "Link:", "العنوان (عربي)": "Address (Arabic)", "ساعات العمل (عربي)": "Hours (Arabic)", "رابط الخريطة (Google Maps)": "Map link (Google Maps)"};
const EN_KEYS=Object.keys(EN).sort((a,b)=>b.length-a.length);
let LANG=localStorage.getItem('ug_l')||'ar';
function trText(t){let o=t;for(const k of EN_KEYS){if(o.indexOf(k)>-1)o=o.split(k).join(EN[k])}return o}
function applyLang(root){
  document.documentElement.lang=LANG;document.documentElement.dir=LANG==='ar'?'rtl':'ltr';
  const b=document.getElementById('lng');const want=LANG==='ar'?'EN':'عربي';if(b&&b.textContent!==want)b.textContent=want;
  if(LANG!=='en')return;
  const w=document.createTreeWalker(root||document.body,NodeFilter.SHOW_TEXT);let n;const list=[];
  while((n=w.nextNode()))if(/[\u0600-\u06FF]/.test(n.nodeValue))list.push(n);
  for(const x of list){if(x.parentNode&&x.parentNode.tagName==='SCRIPT')continue;const v=trText(x.nodeValue);if(v!==x.nodeValue)x.nodeValue=v}
  (root||document.body).querySelectorAll('[placeholder],[title]').forEach(e=>{for(const a of ['placeholder','title']){const v=e.getAttribute(a);if(v&&/[\u0600-\u06FF]/.test(v))e.setAttribute(a,trText(v))}})}
new MutationObserver(()=>{if(LANG==='en')applyLang()}).observe(document.body,{childList:true,subtree:true,characterData:true});
document.addEventListener('click',e=>{if(e.target&&e.target.id==='lng'){LANG=LANG==='ar'?'en':'ar';localStorage.setItem('ug_l',LANG);location.reload()}});
let token=localStorage.getItem('ug_t'),me=null,branches=[],plans=[],tab='mem';
const money=v=>(Math.round(v*1000)/1000)+' د.ب';
function toast(m,err){const t=$('#toast');t.textContent=m;t.className=err?'err':'';t.style.display='block';clearTimeout(toast.t);toast.t=setTimeout(()=>t.style.display='none',3500)}
async function api(method,path,body){
  let r;try{r=await fetch(path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined})}catch{throw new Error('تعذّر الاتصال بالخادم')}
  const d=await r.json().catch(()=>({}));
  if(r.status===401&&token){logout();throw new Error('انتهت الجلسة')}
  if(!r.ok)throw new Error(d.error||('خطأ '+r.status));return d}
function logout(){token=null;me=null;localStorage.removeItem('ug_t');render()}
$('#out').onclick=logout;applyLang();
function loginView(){
  $('#app').innerHTML='<div class="card login"><h2>تسجيل الدخول</h2><label>اسم المستخدم</label><input id="u" autocomplete="username" autocapitalize="off"><label>كلمة المرور</label><input id="p" type="password" autocomplete="current-password"><div style="height:16px"></div><button id="go" style="width:100%">دخول</button></div>';
  const go=async()=>{try{const d=await api('POST','/api/login',{username:$('#u').value.trim().toLowerCase(),password:$('#p').value});
    if(d.user.role!=='admin'){toast('هذه اللوحة للمدير فقط',true);return}
    token=d.token;localStorage.setItem('ug_t',token);await boot()}catch(e){toast(e.message,true)}};
  $('#go').onclick=go;$('#p').onkeydown=e=>{if(e.key==='Enter')go()}}
async function boot(){
  try{me=await api('GET','/api/me');if(me.role!=='admin'){toast('هذه اللوحة للمدير فقط',true);logout();return}
    [branches,plans]=await Promise.all([api('GET','/api/branches'),api('GET','/api/plans')]);render()}catch(e){logout()}}
function render(){
  $('#out').style.display=token?'':'none';$('#who').textContent=me?me.name:'';
  if(!token||!me){loginView();return}
  $('#app').innerHTML='<div class="tabs"><button data-t="mem">الأعضاء</button><button data-t="acc">حسابات العملاء</button><button data-t="brn">الفروع</button><button data-t="users">الحسابات</button><button data-t="plans">الباقات والأسعار</button><button data-t="sum">ملخص الشهر</button></div><div id="v"></div>';
  document.querySelectorAll('.tabs button').forEach(b=>{b.className=b.dataset.t===tab?'on':'';b.onclick=()=>{tab=b.dataset.t;render()}});
  ({mem:memView,acc:accView,brn:brnView,users:usersView,plans:plansView,sum:sumView})[tab]()}
const gym=()=>branches.filter(b=>b.kind==='gym');
async function usersView(){
  const v=$('#v');v.innerHTML='جاري التحميل...';
  let list;try{list=await api('GET','/api/users')}catch(e){v.textContent=e.message;return}
  v.innerHTML='<div class="card"><h3>إنشاء حساب جديد</h3><div class="row"><div><label>الاسم</label><input id="n"></div><div><label>اسم المستخدم (إنجليزي)</label><input id="un" autocapitalize="off"></div><div><label>كلمة المرور (8 أحرف على الأقل)</label><input id="pw" type="text" autocomplete="off"></div></div><div class="row"><div><label>الصلاحية</label><select id="rl"><option value="staff">موظف</option><option value="admin">مدير</option></select></div><div><label>الفرع</label><select id="br">'+gym().map(b=>'<option value="'+b.id+'">'+esc(LANG==='en'?b.name:(b.name_ar||b.name))+'</option>').join('')+'</select></div><div><label>الراتب الشهري (د.ب)</label><input id="sl" type="number" step="0.001" value="0"></div></div><div style="height:14px"></div><button id="add">إنشاء الحساب</button> <button class="ghost" id="gen">توليد كلمة مرور</button></div><div class="card scroll"><h3 style="margin-bottom:8px">الحسابات</h3><table><thead><tr><th>الاسم</th><th>المستخدم</th><th>الصلاحية</th><th>الفرع</th><th>الراتب</th><th>الحالة</th><th></th></tr></thead><tbody>'+list.map(u=>'<tr><td>'+esc(u.name)+'</td><td dir="ltr" style="text-align:right">'+esc(u.username)+'</td><td><span class="pill vi">'+(u.role==='admin'?'مدير':'موظف')+'</span></td><td>'+esc((LANG==='en'?u.branch_name:(u.branch_name_ar||u.branch_name))||'—')+'</td><td>'+money(u.base_salary||0)+'</td><td><span class="pill '+(u.active?'ok':'off')+'">'+(u.active?'فعّال':'موقوف')+'</span></td><td style="white-space:nowrap"><button class="ghost" data-pw="'+u.id+'">كلمة مرور جديدة</button> <button class="ghost" data-tg="'+u.id+'">'+(u.active?'إيقاف':'تفعيل')+'</button></td></tr>').join('')+'</tbody></table></div>';
  $('#gen').onclick=()=>{const c='abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';const a=crypto.getRandomValues(new Uint8Array(10));$('#pw').value=[...a].map(x=>c[x%c.length]).join('')};
  $('#add').onclick=async()=>{try{await api('POST','/api/users',{name:$('#n').value.trim(),username:$('#un').value.trim(),password:$('#pw').value,role:$('#rl').value,branch_id:$('#rl').value==='staff'?Number($('#br').value):null,base_salary:Number($('#sl').value)||0});
    toast('تم إنشاء الحساب: '+$('#un').value.trim()+' — كلمة المرور: '+$('#pw').value);usersView()}catch(e){toast(e.message,true)}};
  v.querySelectorAll('[data-pw]').forEach(b=>b.onclick=async()=>{const p=prompt('كلمة المرور الجديدة (8 أحرف على الأقل)');if(!p)return;try{await api('PUT','/api/users/'+b.dataset.pw,{password:p});toast('تم تغيير كلمة المرور')}catch(e){toast(e.message,true)}});
  v.querySelectorAll('[data-tg]').forEach(b=>b.onclick=async()=>{const u=list.find(x=>x.id==b.dataset.tg);try{await api('PUT','/api/users/'+u.id,{active:!u.active});usersView()}catch(e){toast(e.message,true)}})}
async function memView(){
  const v=$('#v');
  v.innerHTML='<div class="card"><input id="q" placeholder="بحث بالاسم أو الهاتف"></div><div id="ml"></div>';
  const load=async()=>{const ml=$('#ml');ml.innerHTML='جاري التحميل...';
    try{const l=await api('GET','/api/members?limit=60&q='+encodeURIComponent($('#q').value.trim()));
      ml.innerHTML=l.length?'<div class="card scroll"><table><thead><tr><th>الاسم</th><th>الهاتف</th><th>الحالة</th><th></th></tr></thead><tbody>'+l.map(m=>'<tr><td>'+esc(m.name)+'</td><td>'+esc(m.phone)+'</td><td>'+esc(m.status)+'</td><td><button data-id="'+m.id+'">رابط البطاقة</button> <button class="ghost" data-lc="'+m.id+'">كود ربط التطبيق</button></td></tr>').join('')+'</tbody></table></div>':'<p style="color:var(--mute)">لا توجد نتائج</p>';
      ml.querySelectorAll('[data-id]').forEach(b=>b.onclick=async()=>{try{const p=await api('GET','/api/members/'+b.dataset.id+'/pass');
        try{await navigator.clipboard.writeText(p.link);toast('تم نسخ الرابط')}catch{prompt('رابط البطاقة',p.link)}}catch(e){toast(e.message,true)}});
      ml.querySelectorAll('[data-lc]').forEach(b=>b.onclick=async()=>{try{const c=await api('POST','/api/members/'+b.dataset.lc+'/link-code',{});prompt('كود الربط (صالح 24 ساعة) - أعطه للعضو',c.code)}catch(e){toast(e.message,true)}})}
    catch(e){ml.textContent=e.message}};
  let tm;$('#q').oninput=()=>{clearTimeout(tm);tm=setTimeout(load,300)};load()}
async function accView(){
  const v=$('#v');v.innerHTML='جاري التحميل...';
  try{const d=await api('GET','/api/accounts');const L=d.items;
    const st={pending:'قيد المراجعة',active:'مفعّل',disabled:'موقوف'};
    v.innerHTML='<div class="card scroll"><h3 style="margin-bottom:8px">حسابات العملاء</h3><p style="color:var(--mute)">الحساب يصير مشترك فعلي لما تربطه بعضو. للمشتركين القدام: اربطه من الاقتراحات (نفس رقم الهاتف) أو اعطِ العضو كود ربط من تبويب الأعضاء.</p><table><thead><tr><th>الاسم</th><th>المستخدم</th><th>الهاتف</th><th>الايميل</th><th>الحالة</th><th>العضو المرتبط</th><th></th></tr></thead><tbody>'+L.map(a=>'<tr><td>'+esc(a.name)+'</td><td dir="ltr">'+esc(a.username)+'</td><td dir="ltr">'+esc(a.phone)+'</td><td dir="ltr">'+esc(a.email||'—')+(a.email&&a.email_verified?' ✓':'')+'</td><td><span class="pill '+(a.status==='active'?'ok':'off')+'">'+st[a.status]+'</span></td><td>'+(a.member_id?esc(a.member_name)+' ('+esc(a.end_date)+')':((a.suggestions||[]).map(s=>'<button class="ghost" data-lk="'+a.id+'" data-m="'+s.id+'">ربط: '+esc(s.name)+'</button>').join(' ')||'—'))+'</td><td style="white-space:nowrap">'+(a.member_id?'<button class="ghost" data-ul="'+a.id+'">فك الربط</button> ':'')+'<button class="ghost" data-tg="'+a.id+'" data-s="'+(a.status==='disabled'?'pending':'disabled')+'">'+(a.status==='disabled'?'تفعيل':'إيقاف')+'</button></td></tr>').join('')+'</tbody></table></div>';
    const act=async(fn)=>{try{await fn();accView()}catch(e){toast(e.message,true)}};
    v.querySelectorAll('[data-lk]').forEach(b=>b.onclick=()=>act(()=>api('POST','/api/accounts/'+b.dataset.lk+'/link',{member_id:Number(b.dataset.m)})));
    v.querySelectorAll('[data-ul]').forEach(b=>b.onclick=()=>act(()=>api('POST','/api/accounts/'+b.dataset.ul+'/link',{member_id:null})));
    v.querySelectorAll('[data-tg]').forEach(b=>b.onclick=()=>act(()=>api('POST','/api/accounts/'+b.dataset.tg+'/status',{status:b.dataset.s})))}
  catch(e){v.textContent=e.message}}
async function brnView(){
  const v=$('#v');v.innerHTML='جاري التحميل...';
  try{const d=await api('GET','/api/public/branches');
    v.innerHTML=d.items.map(b=>'<div class="card"><h3>'+esc(b.name_ar)+' - '+esc(b.name)+'</h3><div class="row"><div><label>العنوان (عربي)</label><input data-f="address_ar" value="'+esc(b.address_ar||'')+'"></div><div><label>Address (English)</label><input data-f="address" value="'+esc(b.address||'')+'"></div></div><div class="row"><div><label>ساعات العمل (عربي)</label><input data-f="hours_ar" value="'+esc(b.hours_ar||'')+'"></div><div><label>Hours (English)</label><input data-f="hours" value="'+esc(b.hours||'')+'"></div></div><div class="row"><div><label>الهاتف</label><input data-f="phone" dir="ltr" value="'+esc(b.phone||'')+'"></div><div><label>رابط الخريطة (Google Maps)</label><input data-f="map_url" dir="ltr" value="'+esc(b.map_url||'')+'"></div></div><div style="height:12px"></div><button data-sv="'+b.id+'">حفظ</button></div>').join('');
    v.querySelectorAll('[data-sv]').forEach(btn=>btn.onclick=async()=>{const card=btn.closest('.card');const body={};card.querySelectorAll('[data-f]').forEach(i=>body[i.dataset.f]=i.value);
      try{await api('PUT','/api/branches/'+btn.dataset.sv,body);toast('تم الحفظ')}catch(e){toast(e.message,true)}})}
  catch(e){v.textContent=e.message}}
function plansView(){
  const v=$('#v');v.innerHTML='<div class="card scroll"><h3 style="margin-bottom:8px">الباقات والأسعار</h3><table><thead><tr><th>الباقة</th><th>المدة (شهر)</th><th>السعر (د.ب)</th><th></th></tr></thead><tbody>'+plans.map(p=>'<tr><td>'+esc(LANG==='en'?p.name:(p.name_ar||p.name))+'</td><td>'+(p.months===0?'يوم':p.months)+'</td><td style="max-width:140px"><input type="number" step="0.001" value="'+p.price+'" data-p="'+p.id+'"></td><td><button class="ghost" data-s="'+p.id+'">حفظ</button></td></tr>').join('')+'</tbody></table></div>';
  v.querySelectorAll('[data-s]').forEach(b=>b.onclick=async()=>{const i=v.querySelector('[data-p="'+b.dataset.s+'"]');try{await api('PUT','/api/plans/'+b.dataset.s,{price:Number(i.value)});toast('تم الحفظ')}catch(e){toast(e.message,true)}})}
async function sumView(){
  const v=$('#v');const m=new Date(Date.now()+3*3600e3).toISOString().slice(0,7);v.innerHTML='جاري التحميل...';
  try{const r=await api('GET','/api/reports/summary?month='+m);
    v.innerHTML='<div class="card"><h3 style="margin-bottom:12px">'+m+'</h3><div class="grid"><div class="stat"><small>الدخل</small><div>'+money(r.income)+'</div></div><div class="stat"><small>المصروفات</small><div>'+money(r.expenses)+'</div></div><div class="stat"><small>الرواتب</small><div>'+money(r.salaries)+'</div></div><div class="stat"><small>الربح</small><div style="color:'+(r.profit>=0?'var(--ok)':'var(--bad)')+'">'+money(r.profit)+'</div></div><div class="stat"><small>أعضاء فعّالون</small><div>'+r.members.active+'</div></div><div class="stat"><small>ينتهي خلال 7 أيام</small><div>'+r.members.expiring_7d+'</div></div></div></div><p style="color:var(--mute)">للتفاصيل الكاملة استخدم تطبيق الجوال.</p>'}catch(e){v.textContent=e.message}}
if(token)boot();else render();
</script></body></html>`;
