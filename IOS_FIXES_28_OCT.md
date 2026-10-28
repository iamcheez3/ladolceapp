# LaDolce: fixes on 28 Oct 2026 (for the iOS build)

This is the list of what changed on 28 Oct 2026, after a full test of the app and the server. Build the same version for iOS from it.

| | Branch `sith`, latest commit |
|---|---|
| App (`ladolceapp`) | `7106121`, version **1.0.1 (build 10)**: the fixes below plus the new look (section 3c) |
| Backend (`ladolcepos`) | `0fdd9e6` |

The older changes (topping groups, split payment, buy X get Y free, and so on) are in `IOS_BUILD_NOTES.md` in the app repo. Read that too if you haven't built since 10 Oct.

## 1. Build

```bash
git checkout sith && git pull        # app must be at 7106121 or newer
flutter clean && flutter pub get
cd ios && pod install && cd ..
flutter test                         # 1,780 tests, all should pass
flutter build ipa
```

- Build 10 added the bundled font `NotoSansLao` (see 3c). Build 11 sets the version to `1.0.1+11` and adds one package, **`share_plus`** (see 3d), so run `pod install`.
- The translation files are generated and committed, so you don't need to run `flutter gen-l10n`.
- Don't commit line-ending-only changes. Some files are CRLF and some are LF.

## 2. What was fixed (app)

### Selling
1. **Price 0 = the cashier types the price.**
   - A product saved with price 0 now asks **"Enter price"** (ປ້ອນລາຄາ) when it is added on the POS, after its toppings.
   - The typed price is used on the ticket, kitchen ticket, bill, receipt and in Odoo.
   - Lines with different typed prices are never joined.
   - The product form accepts 0 and shows the hint "0 = enter the price at the POS".
   - Customers don't see price-0 products in self-order, unless they are points-redeem items.
2. **Server refusals are no longer treated as "offline".** Before, any error, including a clear "no" from the server, went into the offline queue and was retried forever. A paid sale could then never reach Odoo.
   - New: a 4xx answer (except 401/403/408/429) throws `ServerRejectedException` (in `api_service.dart`) and is **not** queued.
   - Before charging, the POS asks the server whether the cart's free-item promotions are still running. If one has ended, it shows a dialog and doesn't charge.
   - A refused new ticket comes back to the cart, with the server's reason in a dialog.
   - Everything the server refuses is kept in **Settings → "Not saved by the server"**: time, amount and reason, with a Clear button.
   - The offline ticket cache now keeps free items and kitchen notes.
   - The customer app shows the server's reason instead of "check your connection".
3. **Back button.** Leaving the POS with unsaved items now asks "Unsaved items… discard?" first. On Android the system Back did this; on iOS it's the back swipe or gesture. Please check it.

### Payments and cash drawer
4. **Cash drawer.** The drawer signal is now sent in the same printer job as the receipt.
   - It opens when **any** payment row uses a method with "Open cash drawer" ticked in Odoo, even when the amount is exact and there's no change.
   - Before, it sometimes didn't open on an exact split payment.
5. **Change for cash.** A payment method that opens the drawer may take more than the total and give change, even if its name isn't "cash" (for example a Lao name).

### Printing
6. **Receipt, bill and kitchen ticket wait 0.8 s before closing the printer connection.** Before, the end of the ticket (TOTAL, footer, paper cut) could be lost on slow printers.
7. **Reprint and refund slips print Lao names.** They used to print `?????`; every line now uses the same print font as the receipt.
8. **Kitchen tickets group identical items by product id**, not by name.

### Screens and sizes
9. **Layout fixes.** All of these overflowed before; each was found by the new screen-size tests:
   - Items list: long category name.
   - Product form: category dropdown.
   - POS product card: crossed-out price + promo price.
   - Open tickets grid.
   - Customer product cards with large text.
10. **Small phones:**
    - Smaller PIN keys on short screens.
    - One ticket per row below 340 px width.
    - The Save button on the product form and the last Settings tile stay above the navigation bar or home indicator.
11. **New screen-size tests:** `test/screen_size_*_test.dart`.
    - Sizes: 9 screens from 320×568 to 1280×800, in Lao and English, plus large text.
    - Result: no overflow anywhere.
    - To see the report: `LAYOUT_REPORT=out.txt flutter test --concurrency=1 test/screen_size_*_test.dart`.

### App update (Android only)
12. A failed install no longer closes the POS, and old downloaded APKs are deleted. **iOS: nothing to do.** The update button is hidden on iOS (`AppUpdateService.isSupported` is Android only).

## 3. What was fixed (server)

These affect how the app must talk to the server. Deploy with: pull `sith`, then restart Odoo. No `-u` is needed this time.

| Change | What the app must do |
|---|---|
| `POST /api/pos/order/<id>/pay` refuses a broken body, unknown payment methods, and split `payments` that add up to **less than the total** (1 kip tolerance). Before, it marked the order paid anyway. | Send split payments that cover the total. Cash is stored without the change, as the app already does. |
| `POST /api/pos/order` (create, incl. `is_paid`) and `/update` return a clear **400 message** for bad input: qty ≤ 0, negative price, ids that aren't numbers or don't exist, no product lines. Before, these crashed with a 500. | Nothing, if you send what the Android app sends. Show the `message` on 400. |
| A refused self-order no longer uses up the customer's coupon. | Nothing. |
| `/api/products`: a special price limited to some branches only applies at those branches. Products are sorted by name **and id**, so page-by-page loading never skips one. `limit`/`offset` are checked. | Nothing (the app already sends `branch_id` and loads every page). |

## 3b. API changes (all changes since backend commit `14dd06d`)

Use this list if anything on iOS calls the server by its own code (native code, a share extension, a widget), or if you compare against an older build. The Flutter app on `sith` already uses all of it.

- Every call still needs the header `X-API-Key`. Staff calls also send `Cookie: session_id=…` and `X-Openerp-Session-Id: …` (see Login below).
- Errors are always JSON: `{"status": "error", "message": "..."}`.
- **400** = the server refused the request; show `message`, don't retry.
- **401/403** = log in again.
- **5xx or no answer** = offline; queue and retry.

### New endpoints

| Method + path | Request | Response `data` |
|---|---|---|
| `GET /api/pos/topping_groups` | none | `[{id, name, name_lo, sequence, selection_type: "single"\|"multiple", required}]` |
| `POST /api/pos/topping_groups` | `{id?, name, name_lo?, selection_type, required, sequence?}` (with `id` = update) | the saved group |
| `DELETE /api/pos/topping_groups/<id>` | none | none |
| `GET /api/pos/promotions/free_items?branch_id=` | none | `[{id, name, buy_qty, free_qty, product_ids, free_product_ids, end_date}]`. These are the running "buy X get Y free" promotions. `product_ids` = what counts as bought; `free_product_ids` = what may be free. |
| `GET /api/pos/app/latest?platform=android` | none | `{id, version, build, notes, force, size, download_url}` or `null` (Android in-app update; not used on iOS) |
| `GET /api/pos/app/download/<id>` | none | the APK file (Android only) |

### Changed requests (new fields the app sends)

| Endpoint | New / changed fields |
|---|---|
| `POST /api/pos/order` (create) | `ticket_label` (save under a name instead of a table); `payments: [{payment_method_id, amount}]` (split payment, with `is_paid: true`); on each line: `is_free_promo: true` + `promotion_id` (free item, price forced to 0), `note` (kitchen note) |
| `POST /api/pos/order/<id>/update` | `ticket_label` (rename; frees the table, `""` removes the name); `partner_id` (now saved; null never clears it); `replace_all`; line fields as above |
| `POST /api/pos/order/<id>/pay` | `payments: [{payment_method_id, amount}]` |
| `POST /api/pos/toppings` | `id` (update instead of create), `name_lo`, `group_id`, `is_default`, `sequence` |
| `POST /api/pos/categories`, `POST /api/pos/products` | `hide_in_self_order` (POS-only item, not shown in self-order) |
| `GET /api/pos/my_orders` | `date_from`, `date_to` as `YYYY-MM-DD` in Lao time (UTC+7); a wrong format gives 400 |
| `GET /api/products` | still `limit` + `offset` + `branch_id`. Load **every page**; the app uses pages of 10 until a short page comes back. |

### Changed responses (new fields to read)

| Endpoint | New fields |
|---|---|
| `GET /api/products` | per product: `hide_in_self_order`; `toppings[]` now include `name_lo, sequence, is_default, group_id, group_name, group_name_lo, group_sequence, group_type, group_required`; `promotion_price` now only for the tablet's branch. A product with `list_price` **0** = the cashier types the price. |
| `GET /api/pos/toppings` | same topping fields as above |
| `GET /api/pos/payment_methods` | `open_cash_drawer` (bool): open the drawer when this method is used |
| `GET /api/pos/open_tickets` | `ticket_label`, `delivery_status` (`"ready"` = pickup order is ready); `table_name` shows the ticket name when there is one; lines: `is_free_promo`, `promotion_id` |
| `GET /api/pos/order/<id>/receipt` | `payments: [{payment_method_id, payment_method, amount}]`, `points_earned`, `customer_points`, `points_label`, `table` (ticket name or table); lines: `is_free_promo` |
| `POST /api/pos/order/<id>/update` | `state`, `ticket_label`, `table_id` |
| `POST /api/pos/order/<id>/pay` | `state`, `payments` |
| `POST /api/pos/order/<id>/notify_ready` | pickup self-orders now get `delivery_status = "ready"` (customer app shows "Ready for pickup") |
| history / my_orders lines | `is_free_promo`, `subtotal` |

### Behaviour changes that can break a client

| What | Before | Now |
|---|---|---|
| `pay` with a broken body or unknown payment method | ignored, order marked paid | **400**, order stays unpaid |
| split `payments` adding up to less than the total (1 kip tolerance) | accepted | **400**. Cash is stored without the change (the client takes the change off). |
| create/update with `qty <= 0`, negative price, ids that aren't numbers or don't exist, no product lines | 500, or a bad order saved | **400** with a message |
| free item when the promotion ended, wrong product, or too many | n/a | **400**, nothing saved (whole request rolled back) |
| self-order with a POS-only product | accepted | **400** "Not available for self-order" |
| refused self-order with a coupon | coupon was used up | coupon not used |
| `/api/products?limit=abc` | 500 | 400; `limit` capped at 500 |
| `/api/products` order | name only (pages could repeat or skip same-name products) | name, then id (stable) |

### Login session (Odoo 18)

- `POST /api/pos/login` returns `session_id` in the JSON, but Odoo 18 **replaces that session right after login**. The live session is the `session_id` in the response's **`Set-Cookie`** header.
- For staff, store the Set-Cookie value and send it as `Cookie: session_id=<it>`. Keep sending the JSON value in `X-Openerp-Session-Id`.
- Otherwise every staff device except the last one to log in gets "Missing or invalid user session" on menu saves.
- Customers: unchanged.
- **iOS check:** make sure `Set-Cookie` is visible in the login response on iOS. Some HTTP stacks store cookies themselves and hide the header. If it's missing, saves only work on the last device that logged in.

## 3c. New look (build 10)

Every screen was restyled: navy and gold, white "paper" ticket, prices in the receipt font. It is the **same app**: same buttons, menus, dialogs, server calls and printing. **No API changes** come from the redesign.

- **Theme:** colours, sizes and shared widgets are in `lib/theme/ld.dart`. The app theme is in `lib/theme/ld_theme.dart`, used by `main.dart`.
- **Fonts:** the UI font is now bundled: `assets/fonts/NotoSansLao-*.ttf`, family `NotoSansLao` in `pubspec.yaml`. Prices and titles use the already bundled `NotoSerifLao`. Nothing is downloaded at runtime for the UI any more, and `main.dart` no longer uses `google_fonts`. Nothing to do on iOS beyond `flutter pub get`.
- **Back gestures:** iOS uses the normal swipe-from-left-edge back (Cupertino page transitions). Android uses predictive back. The POS "unsaved items" guard (`PopScope`) is unchanged.
- **Status bar:** white icons app-wide, set once in `MaterialApp.builder`. The tablet POS (light top) switches to dark icons. `Info.plist` doesn't set `UIViewControllerBasedStatusBarAppearance`, so Flutter controls it. Keep it that way.
- **Layout:**
  - Screens 1100 px wide or more show the ticket as a navy rail on the right.
  - Smaller screens show a ticket bar at the bottom that opens a sheet.
  - Automated tests check 88 screens/widgets at 9 sizes (320×568 up to 1280×800, text ×1.3), in Lao and English: no overflow.
- **Small additions** (no new server calls):
  - Open cash drawer and Sync are also in the side menu.
  - Quick cash buttons on Charge.
  - Search and category filter on Manage products.
  - Pull down to refresh on lists that already reload.
  - Tap anywhere on a switch row to toggle it.

## 3d. Customer Profile tab + Share my card (build 11)

The customer **Profile** tab has a new "coffee time" layout, in the same app colours and fonts. Nothing was removed and no server call changed.

- **Profile tab** (`_buildProfileTab` in `lib/screens/customer_self_order_screen.dart`):
  - Greeting by time of day, photo with camera button, client ID chip (tap copies) and birthday chip.
  - Navy points card with the LaDolce bear as a faint watermark, the rank chip (opens Ranking), Redeem (opens the Rewards catalog) and **Share my card**.
  - A progress bar shows "N pts more for a free X". X is the cheapest reward in the Rewards catalog that the customer can't afford yet. It is worked out in the app from the products it already loads; it's hidden when the catalog has no rewards.
  - "Your corner" tiles: Rewards catalog, My vouchers, Ranking, Favorite places. Then Edit profile, Notifications and Customer support. The EN / ລາວ switch moved to the top of the tab.
- **Share my card** (new `lib/screens/share_card_screen.dart`):
  - A story-sized card (exported as a 1080 × 1920 PNG) with the bear logo, the name, the rank (Top 50), points and "LaDolce app". The customer can pick 4 colours and hide the rank or points.
  - The bear comes from `assets/images/ladolce_bear_mark.png` (white on transparent, tinted in code). It's part of the picture, so it shows wherever the image is posted.
  - **iOS:** one **Share** button opens the iOS share sheet (`share_plus`; Instagram, Facebook and WhatsApp are listed there), and a **Save** button saves the card to Photos with `ImageGallerySaverPlus` (permission `photosAddOnly`, the same one the QR save uses; the `NSPhotoLibraryAddUsageDescription` text now mentions the card).
  - **Android** also has direct Instagram / Facebook / WhatsApp buttons through a new MethodChannel `ladolce/share` in `MainActivity.kt`. Not needed on iOS.
  - There is no QR code on the card yet (no download link decided).
- **New texts:** 30 new keys in `lib/l10n/app_en.arb` / `app_lo.arb` (generated files are committed).

## 4. Please test on iPhone / iPad

- [ ] Product with price 0: tap it on the POS, type a price, and the line shows that price. Charge it; Odoo shows the same price.
- [ ] Split payment with the exact amount (Cash + card): the receipt prints and the **cash drawer opens**.
- [ ] Free-item promotion: add the free item, then end the promotion in Odoo. **Charge** shows the "has ended" dialog and doesn't charge. **Save ticket** shows the server's reason and the items come back to the cart. Settings shows "Not saved by the server (1)".
- [ ] Reprint a receipt with Lao item names: the names are readable.
- [ ] Back gesture on the POS with unsaved items: it asks before discarding.
- [ ] Small iPhone (SE size) and iPad, portrait and landscape: no cut-off text, the PIN pad fits, and Save buttons are not under the home indicator.
- [ ] New look: Lao text uses the bundled font, not a fallback. Status bar text is white on the navy screens (PIN, POS, settings). Swipe from the left edge goes back on pushed screens. Bottom sheets (ticket, charge, toppings) close with a swipe down and their buttons stay above the home indicator.
- [ ] Profile tab (customer): points card, tiles and buttons fit on iPhone SE and iPad. **Share my card** → Share opens the iOS share sheet with the image; Save asks for Photos permission once and the card appears in Photos with the bear logo.

## 5. Not tested yet

- The **real cash drawer**. On the test setup we confirmed one print job reached the printer, but nobody watched the drawer open.
- **Anything on iOS.** All testing was on Android: the emulator at 4 sizes, plus automated screen-size tests.

## 6. Known open issues (not fixed yet)

- **Security (important):** on Odoo 18 the server's `secure_controller()` protects nothing. Customer data (names, phones, emails), sales history and receipts can be read without login. Customers can also edit the menu. A fix is planned separately, and it will change which calls need a login.
- The app's API key and the Telbiz SMS secret are in plain text inside the app bundle (`.env`). Once the SMS secret is moved to the server, the old one must be replaced.
- A very fast double tap on **Charge** can pay twice.
- A ticket deleted with the trash button can briefly reappear from the cache.
- Some text is still English in Lao mode: "All Items", "View Ticket & Charge", "each", "Welcome back".
- The product form has no Lao name field (the topping form does).
