# UNDERGROUND – Admin & Staff App

Two parts:
- `api/`  – Cloudflare Worker + D1 database (tested locally, 46 checks pass)
- `app/`  – Flutter app (Arabic/English). Admin and staff see different screens after login.
  **The Flutter code was written without a compiler. Run it once and send me any red errors – they are usually one-line fixes.**

## 1. Deploy the API (once)
```
cd api
npm install
npx wrangler login
npx wrangler d1 create ug-admin            # copy the database_id into wrangler.toml
npx wrangler d1 execute ug-admin --remote --file=schema.sql
npx wrangler d1 execute ug-admin --remote --file=seed_schedule.sql
npx wrangler secret put JWT_SECRET         # any long random text
npx wrangler secret put SETUP_KEY          # a private code you choose
npm run deploy                             # prints https://ug-admin-api.<you>.workers.dev
```
Create the first admin (only works once):
```
curl -X POST https://ug-admin-api.<you>.workers.dev/api/setup -H "Content-Type: application/json" \
  -d '{"key":"YOUR_SETUP_KEY","name":"Abbas","username":"abbas","password":"a-strong-password"}'
```
Check: open `/api/health` in the browser.

## 2. Run the app
```
flutter create ug_app
# copy app/lib and app/pubspec.yaml over the new project's lib/ and pubspec.yaml
cd ug_app
# edit lib/config.dart -> put your workers.dev address in apiBase
flutter pub get
flutter run -d chrome            # web test
flutter build web                # then upload build/web to Cloudflare Pages (e.g. admin.gossipbh.com)
flutter build apk                # Android
```
On the web build, the Worker already allows cross-origin calls (CORS).

## 3. Daily use
- Admin: Home (profit, income, expenses, chart), Members, Money (income/expenses, swipe to delete), Team (staff, attendance, pay salary), More (change plan prices).
- Staff: Check-in (search name/phone, green/yellow/red status), New member + payment, Schedule, Me (clock in/out, today's collection).
- Staff pay the plan price at their own branch only. Only admin can change amount, branch or date.

## Back office (web)
Open your API address in a browser (e.g. https://ug-admin-api.xxx.workers.dev). Sign in as admin to create staff accounts and passwords,
reset passwords, disable accounts, edit plan prices and see the month summary. Staff sign in only through the app.
Android note: release builds need `<uses-permission android:name="android.permission.INTERNET"/>` in android/app/src/main/AndroidManifest.xml (the helper scripts add it).
