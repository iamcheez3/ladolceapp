# LaDolce: fixes on 28 Oct 2026 (for the iOS build)

This is the list of what changed on 28 Oct 2026, after a full test of the app and the server. Build the same version for iOS from it.

| | Branch `sith`, latest commit |
|---|---|
| App (`ladolceapp`) | `0f6af84`, version **1.0.1 (build 9)** |
| Backend (`ladolcepos`) | `0fdd9e6` |

The older changes (topping groups, split payment, buy X get Y free, and so on) are in `IOS_BUILD_NOTES.md` in the app repo. Read that too if you haven't built since 10 Oct.

## 1. Build

```bash
git checkout sith && git pull        # app must be at 0f6af84 or newer
flutter clean && flutter pub get
cd ios && pod install && cd ..
flutter test                         # 592 tests, all should pass
flutter build ipa
```

- No new packages; `pubspec.yaml` only changed the version to `1.0.1+9`.
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

## 4. Please test on iPhone / iPad

- [ ] Product with price 0: tap it on the POS, type a price, and the line shows that price. Charge it; Odoo shows the same price.
- [ ] Split payment with the exact amount (Cash + card): the receipt prints and the **cash drawer opens**.
- [ ] Free-item promotion: add the free item, then end the promotion in Odoo. **Charge** shows the "has ended" dialog and doesn't charge. **Save ticket** shows the server's reason and the items come back to the cart. Settings shows "Not saved by the server (1)".
- [ ] Reprint a receipt with Lao item names: the names are readable.
- [ ] Back gesture on the POS with unsaved items: it asks before discarding.
- [ ] Small iPhone (SE size) and iPad, portrait and landscape: no cut-off text, the PIN pad fits, and Save buttons are not under the home indicator.

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
