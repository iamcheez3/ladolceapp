# LaDolce: iOS build notes for the 10 Oct and 28 Oct 2026 changes

These notes cover everything changed in the app (and the backend it talks to) on 10 Oct and 28 Oct 2026. The app version is now **1.0.1 (build 9)**. The Android build with all of this is done. This file is for building the **same version for iOS**. See section 8 for what has not been tested yet.

- App repo: `ladolceApp`, branch **`sith`**. All the changes below are on top of commit `5d2a6f5`.
- Backend repo: `ladolce` (Odoo 18 addons), branch **`sith`**, on top of commit `14dd06d`.

> **Get the code first.** The changes are on the `sith` branch of both repos. Pull the latest `sith` before building. If `git log` still shows `5d2a6f5` as the newest app commit, the changes have not been pushed yet. Ask for them before you start.

---

## 1. What you need

| Thing | Version / note |
|---|---|
| Flutter | **3.41.6** (stable). Use **3.35 or newer** at least: the new code uses `RadioGroup`, `Switch.activeThumbColor` and `DropdownButtonFormField.initialValue`, which older Flutter does not have. |
| iOS deployment target | 15.0 (unchanged) |
| New packages | **None.** `pubspec.yaml` only gained a bundled font (see below), so CocoaPods does not change. |
| `.env` | Same file as before. It is bundled into the app, so check `API_BASE_URL` points at the server you want. |

## 2. Build steps

```bash
git checkout sith && git pull
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter test          # 592 tests (incl. 524 screen-size checks), all should pass
flutter build ipa     # or open ios/Runner.xcworkspace in Xcode and Archive
```

The translation files (`lib/l10n/app_localizations*.dart`) are already generated and committed. You do **not** need to run `flutter gen-l10n`. If you do run it, it is harmless.

**Line endings:** some files in this repo are CRLF (Windows) and some are LF. Do not commit changes that only touch line endings: they make the diff unreadable.

## 3. New files in the app (make sure they are in your checkout)

| File | What it is |
|---|---|
| `assets/fonts/NotoSerifLao-Regular.ttf`, `NotoSerifLao-Bold.ttf`, `OFL.txt` | Print font for receipts and kitchen tickets (declared in `pubspec.yaml` under `fonts:`) |
| `assets/images/receipt_logo.png` | Black-on-white bear logo printed on receipts and bills |
| `lib/widgets/topping_picker.dart` | Grouped topping picker (Type / Taste / Size) |
| `lib/screens/manage_topping_groups_screen.dart` | Items → Toppings → Topping groups screen |
| `lib/models/free_promotion.dart` | "Buy X get Y free" promotion model |
| `test/topping_rules_test.dart`, `test/free_promotion_test.dart`, `test/kitchen_note_print_test.dart`, `test/print_lines_test.dart`, `test/session_cookie_test.dart`, `test/money_test.dart` | Tests |
| `tool/print_font_samples_test.dart` | Font sample tool, used only to choose the font. Not part of the app. |

## 4. What changed (to test on iPhone / iPad)

### Printing (receipts, bills, kitchen tickets)
- A Lao kitchen note no longer stops the kitchen ticket from printing.
- All printed text uses the bundled **Noto Serif Lao** font (rasterised, so Lao always prints).
- The **receipt** prints:
  - the logo, then the store details from the bill template;
  - no "Point of Sale" or "Printer: …" lines;
  - prices as `LAK 35,000`, with a space;
  - each item's choices (Size L…);
  - the payment lines (split payment) and the change;
  - the customer's name, points earned and total points.
- The **kitchen ticket** is titled "Order Ticket", with no printer line. Free items show "(FREE)". Topping lines (Iced, Size L…) print at the same large size as the item; only the item name is bold.
- The **bill** (before payment) now prints every line in the print font, like the receipt. Before, English names used the printer's own font and Lao names an image, so lines did not line up.
- The bill and the receipt join identical lines into one "2x" line (same product, choices, note, price, free state). A reopened ticket keeps each kitchen round as a separate line on screen; only the print is joined. See `mergeSamePrintLines` in `printer_service.dart`.
- Bill templates (header, footer, logo) now reload from the server every time. Before, the first downloaded copy was kept forever.

### Tickets and customers
- A customer added to a ticket is no longer lost when the ticket is saved and reopened.
- Google sign-up customers (no phone) no longer make tickets go "offline".
- **Rename ticket:** Ticket options → Rename. This frees the table, and the name shows instead of the table everywhere, including on paid orders.
- The table picker has a **"Custom name" (ຕັ້ງຊື່ເອງ)** button to save an order under a name instead of a table.
- The open tickets screen has a **grid / list** toggle.
- **Print bill on an unsaved ticket** (⋯ → Print bill) first asks "Save ticket first?" → **Save & print bill**: the ticket is saved as usual (table picker for a new ticket), the kitchen order prints, then the bill prints with the queue number. A ticket with nothing new prints the bill straight away, as before.
- The red **trash** button on a saved ticket now asks for the admin PIN and deletes the ticket on the server. Before, it only cleared the screen.
- Reopened tickets keep their toppings and free items.

### Login session (catalog saves on several devices)
- Saving products, toppings, categories and combos failed with **"Missing or invalid user session"** whenever the same staff account had logged in on another device.
- Cause: Odoo 18 replaces the session id right after login. The `session_id` in the login JSON is the old one; only the `Set-Cookie` header has the live session. The app used the old one as its cookie, so it only passed the server's backup check (`pos_active_sid`), which holds the **last** login only.
- Fix (app only): at a staff login the app also stores the `session_id` from `Set-Cookie` (`ApiService.cookieSessionPrefsKey`) and sends it as the `Cookie`; the old id still goes in `X-Openerp-Session-Id`. Customers are unchanged (single-device rule).
- **On iOS check** that `response.headers['set-cookie']` is present on the `/pos/login` response (it is on Android). If it is missing, saves still work on the last device that logged in, like before.
- Devices updated to this build must **log out and log in once** to get the new session.

### Toppings
- Topping create / edit / delete works again. Before, it failed with 401 because no login session was sent.
- Editing a topping updates it instead of creating a duplicate.
- **Topping groups:** a group is pick-one or pick-many and can be required. Each group can have a default option, and Lao names follow the app language.
- The topping picker is a **3-column grid** (2 columns on very narrow screens).
- The POS reloads products after you edit them, so changes show up without restarting.

### Customer self-order
- Choosing **pickup**, then the cashier pressing **Order Ready**, shows **"Ready for pickup" (ພ້ອມໃຫ້ມາຮັບ)** in the customer's order list. It updates live when the push arrives.
- Products or categories marked **POS only** are hidden in the customer app.
- Paid choices (Size L +₭5000) are now charged correctly. Before, self-orders sent only the base price.

### Payments and promotions
- **Split payment:** on the charge screen, tap "Split payment" (ແຍກຈ່າຍ). Each row is a method and an amount, e.g. BCEL 30,000 + Cash 7,000. Only cash can be more than the total, and the extra becomes the change.
- **Buy X get Y free:**
  - When the cart qualifies, a 🎁 banner appears on the cashier POS (**Add free**) and in the customer cart (**Choose**).
  - The free item is ₭0, choices included.
  - The server checks the counts.
  - Nothing is given free automatically: the cashier or customer chooses.

### Cash drawer and order history
- **Payment methods:** a new **"Open cash drawer"** checkbox in the backend (Configuration → Payment Methods). Paying with a ticked method opens the drawer, including any row of a split payment. "Cash" is ticked automatically on upgrade.
- **Drawer bug fix:** the drawer signal was lost because the printer connection closed too fast. It now waits 0.6 s before closing.
- **Customer order history:** shows **Today** by default, with **Choose dates** and **All** filters. The server endpoint `/api/pos/my_orders` accepts `date_from` / `date_to` (YYYY-MM-DD, Lao time).

### Money format
- Every amount in the app and on paper is whole kip with commas: `90,000` (was `90000.00`). Receipts and bills print `LAK 90,000`. One helper does it: `money()` in `lib/utils/money.dart`.
- Amount boxes (amount received, split payment, product / topping / combo price) add commas while you type (`MoneyInputFormatter`) and read them back with `parseMoney()`.
- The Items and Combos lists showed `$` instead of `₭`; fixed.

### Fixes after the full test (28 Oct, build 9)
- **Price 0 = open price:** a product saved with price 0 asks the cashier "Enter price" when added (after its choices); customers don't see these products in self-order.
- **Server refusals are not "offline" any more:** a 4xx answer (e.g. a free-item promotion that ended) is no longer queued and retried forever. The POS checks free promotions with the server before charging; a refused ticket comes back to the cart with the reason; refused items are listed in Settings → "Not saved by the server". See `ServerRejectedException` in `api_service.dart`.
- **Cash drawer** pulse is sent inside the receipt job, and opens whenever any payment row uses a method with "Open cash drawer" (exact amount or not). Change is allowed for those methods too, not only ones named "cash".
- Receipt, bill and kitchen ticket wait 0.8 s before closing the printer connection (last lines could be lost on slow printers). Reprint/refund slips print Lao names (were "?????"). Kitchen tickets group by product id.
- Back button on the POS asks before discarding unsaved items.
- Layout: no overflow at 9 screen sizes (320×568 → 1280×800, Lao and English, large text); smaller PIN keys on short phones; Save buttons above the navigation bar.
- Server (backend `sith`): pay/create refuse broken input and payments that don't cover the total; a refused self-order no longer uses the coupon; branch-only special prices; stable product paging; clear 400 messages instead of 500s.

### Screen layout
- The bottom of the ticket view, the charge screen and the open tickets list now stay above the system navigation bar. On iPhone this is the home indicator.

### App update button (Android only)
- Settings → **App update** (ອັບເດດແອັບ) shows the installed version and checks the server; the POS also checks once when it opens. A newer build is downloaded and handed to Android's installer.
- Builds are uploaded in Odoo: Custom POS → Configuration → Config → **App Updates**.
- Code: `lib/services/app_update_service.dart`, `lib/widgets/app_update_flow.dart`, and a `ladolce/app_update` channel in `MainActivity.kt` (plus `REQUEST_INSTALL_PACKAGES` and a FileProvider in the manifest).
- **iOS:** nothing to do. Apple does not allow this, so the tile is hidden on iOS (`AppUpdateService.isSupported` is Android only). Use TestFlight / App Store there.

### Product loading (all products, and cellular)
- **No product limit any more.** Before, Items showed only the first 50 products, the POS 100 and the customer app 200; production has 66, so Items missed 16. `ApiService.fetchProducts` now loads every page (10 products per page) until a short page comes back, and keeps each product id once. Items and Combos always load fresh from the server.
- **Opening on cellular works.** Each product carries its picture as base64, so the 66 products are about 11 MB. That was one request with a 5 s timeout, which never finished on mobile data, so a first-time open showed "Network error" and self-order failed to load. Now it is pages of about 2 MB with 30 s each. Test this on an iPhone using **mobile data, not Wi-Fi**.

## 5. iOS things to check

1. **Network printing.** The app prints by opening a TCP connection to the printer (`<ip>:9100`). On iOS 14+ this is "local network" access, and iOS asks the user for permission the first time. `ios/Runner/Info.plist` currently has **no `NSLocalNetworkUsageDescription`**, so iOS shows a generic message. Consider adding:
   ```xml
   <key>NSLocalNetworkUsageDescription</key>
   <string>Used to print receipts and kitchen tickets on the shop's network printers.</string>
   ```
   If printing does nothing on iPhone, check Settings → Privacy & Security → Local Network → LaDolce is ON.
2. **Push "Order ready".** This uses the existing Firebase / APNs setup. Nothing new to configure, but test it on a real device: the iOS simulator does not get pushes.
3. **Fonts.** The print font is bundled in the app, so no internet is needed for printing.
4. **Printer setup for testing.** In the app: Settings → Printer → Add, then the printer's IP and port 9100. Turn on "Receipts" and/or "Orders".

## 6. Backend (must be deployed for the new features)

The app also works with an older server, but these features need the new backend on branch `sith`:

- Changed files:
  - `pos_backend/models/`: `pos_order.py`, `pos_topping.py`, `pos_promotion.py`, `pos_payment_method.py`, `product_category.py`, `product_template.py`
  - `pos_backend/controllers/`: `pos_order_api.py`, `catalog_api.py`, `report_api.py`
  - `pos_backend/views/`: `pos_order_views.xml`, `pos_promotion_views.xml`, `product_contact_views.xml`, `pos_payment_method_views.xml`
  - `pos_backend/security/ir.model.access.csv`
  - `api_for_application/controllers/product_api.py`
  - 28 Oct (app updates): new `pos_backend/models/app_release.py`, `pos_backend/controllers/app_update_api.py`, `pos_backend/views/app_release_views.xml`
- After copying, run the module upgrade: **`-u pos_backend`** (adds new tables and fields). Then restart Odoo.
- New backend screens:
  - Products → **Topping Groups**
  - Promotion form: **Type** (Special price / Buy X get Y free), **Products** tab = what counts as bought, **Free products** tab = what can be free
  - Category and product: **POS only (hide in self-order)**
  - Order form: payment rows for split payments
  - Configuration → Payment Methods: **Open cash drawer** checkbox (Cash is ticked automatically on upgrade)
  - Configuration → Config → **App Updates** (Android APKs for the in-app update)

## 7. Quick test list (iPhone / iPad)

- [ ] Log in as a cashier. Add an Americano: the topping grid shows Type / Taste / Size with defaults ticked.
- [ ] Save to a table. The kitchen ticket prints "Order Ticket", Lao text OK, no printer line.
- [ ] Reopen the ticket. Customer and toppings are still there.
- [ ] Rename the ticket. The table is freed and the name shows.
- [ ] Charge with split payment (BCEL + cash). The receipt shows logo, both payments, change and `LAK 37,000` format.
- [ ] Charge with a customer. The receipt shows points earned and total points.
- [ ] Two promo coffees in the cart: the 🎁 banner appears, Add free gives a ₭0 line, and the receipt says FREE.
- [ ] Trash on a saved ticket asks for the admin PIN and the ticket is gone from Open tickets.
- [ ] Log in as a customer. POS-only items are not visible. The free item banner works. A pickup order shows "Ready for pickup" after the cashier presses Order Ready.
- [ ] Pay with Cash: the drawer opens. Pay with card: it does not (unless ticked in the backend).
- [ ] Customer → History: shows Today; Choose dates and All work.
- [ ] Bottom buttons and totals are not hidden by the home indicator.
- [ ] Items → Products shows every product (production has 66; "water" is near the end).
- [ ] Fresh install on mobile data (Wi-Fi off): log in, the menu loads, POS and self-order open.

## 8. Not tested yet (please check these carefully)

- **Cash drawer opening.** The fix is in, but nobody has tried it with a real drawer connected to the printer.
- **Order history with real orders.** The Today / Choose dates / All buttons were checked on screen, but only with an empty list. The server date filter itself was tested separately.
- **Customer self-order checkout with a free item, on screen.** The cart and banner were tested. Placing the order was tested by calling the server directly, because the test server has no bank QR for the transfer step.
- **Opening on mobile data.** The page sizes and download times were measured against the production server from a PC, but nobody has opened the app on a phone using mobile data yet.
- **Anything on iOS.** All testing so far was on Android.
