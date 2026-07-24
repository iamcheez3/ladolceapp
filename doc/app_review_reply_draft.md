# App Store Review Reply Draft — v1.0 (build 7)

> Copy each section into the reply thread in App Store Connect.
> Items marked `[CONFIRM]` need your confirmation before sending.

---

## Guideline 4.8 — Design — Login Services

Thank you for the feedback. We have resolved this issue by removing the
third-party login service (Google Sign-In) from the iOS version of the app
in this new build. The iOS app now offers only our own first-party login
(phone number with SMS OTP verification, or email/password). Since the app
no longer uses any third-party login service on iOS, guideline 4.8 no
longer applies. We plan to introduce Sign in with Apple alongside Google
Sign-In in a future update.

---

## Guideline 2.1(a) — Performance — App Completeness

Both reported issues have been addressed in this build:

1. **Google login error:** This was caused by a misconfiguration in the
   Google Sign-In integration. The Google login option has been removed
   from the iOS app entirely (see our reply to guideline 4.8), so this
   error can no longer occur.

2. **Home Screen error messages:** We were unable to reproduce this issue.
   We re-tested this build extensively on an iPad Air 11-inch (M3)
   running iPadOS 26 with an active internet connection: the Home screen
   loads products, banners, and store information correctly with no error
   messages. We also improved the app's error handling so that any
   transient server-connectivity issue now shows a clear, user-friendly
   message. If the issue persists on your end, we would appreciate the
   specific error text displayed so we can investigate further.

---

## Guideline 5.1.1(v) — Account Deletion

Account deletion is now fully supported in this build:

- Users can delete their account directly in the app:
  **Profile tab → Delete account → confirmation dialog → account deleted.**
- Deletion is permanent (not a deactivation). The user's account record
  and associated personal data are removed from our servers, and the user
  is signed out and returned to the login screen.
- No customer-service interaction (call/email) is required.

A screen recording captured on a physical device demonstrating account
creation, navigation to the deletion option, and the complete deletion
flow has been added to the Notes field of the App Review Information
section.

---

## Guideline 5.1.1(v) — Phone Number Requirement

The phone number is directly relevant to our app's core functionality for
two reasons:

1. **Account verification (anti-fraud):** Our app is a restaurant loyalty
   and ordering app. Registration is verified via a 6-digit SMS OTP sent
   to the user's phone number — the phone number is the account
   verification credential itself, not supplementary data. Without it,
   users could create unlimited fake accounts to abuse loyalty rewards.

2. **Food delivery:** The app offers food delivery. Delivery riders must
   be able to call customers to complete deliveries (confirm the drop-off
   location, hand over orders). A reachable phone number is essential for
   this core service, consistent with standard practice in food-delivery
   apps.

We collect the phone number solely for these operational purposes. It is
not used for advertising and is not shared with third parties.

---

## Guideline 2.1(b) — Information Needed (Business Model)

1. **Who are the users that will use the paid features in the app?**
   There are no paid digital features. The app is a free ordering and
   loyalty app for customers of our restaurant/café (LaDolce), plus an
   internal staff mode (cashier/rider) used by our own employees.

2. **Where can users purchase the features that can be accessed in the
   app?**
   Nothing in the app is purchased or unlocked with money. Customers use
   the app to order physical food and beverages from our restaurant.
   Payment for those physical goods happens entirely outside the app:
   in person at the store (cash or card), cash on delivery, or bank
   transfer via QR code. The app itself processes no payments and
   contains no purchasable digital content.

3. **What specific types of previously purchased features can a user
   access in the app?**
   None. There are no purchasable features. Loyalty reward points are
   earned from purchases of physical food/drinks and can be redeemed for
   free menu items — points cannot be bought.

4. **What paid content, subscriptions, or features are unlocked within
   the app that do not use In-App Purchase?**
   None. The app contains no paid digital content, subscriptions, or
   unlockable features. All purchases are of physical goods (food and
   beverages) consumed outside the app, which are exempt from In-App
   Purchase under guideline 3.1.5(a).

5. **Are the enterprise services in your app sold to single users,
   consumers, or for family use?**
   The app is not an enterprise service and is not sold. It is a free
   companion app for consumers (our restaurant's customers). The staff
   mode is used internally by our own employees only and is not sold to
   anyone.

6. **How do users obtain an account? Do users have to pay a fee to
   create an account?**
   Users create an account for free inside the app (name + phone number
   verified by SMS OTP). There is no fee of any kind.

---

## Sign-In Information (App Review Information)

Username: sith
Password: 123

## Notes field (App Review Information) — copy-paste text

This app has one consumer role (Customer — the App Store audience) and
two internal staff roles (Cashier, Rider) used only by our restaurant's
own employees. Staff roles are not sold or offered to the public.

Demo accounts (no OTP needed to sign in):

- Customer — login: sith / password: 123
  (main consumer experience: ordering, loyalty points, account deletion)
- Cashier — login: cash / password: 123 / POS PIN: 1122
  (internal staff mode used by our employees at the store)
- Rider — login: rider / password: 123
  (internal staff mode used by our delivery employees)

Feel free to create test orders with the staff accounts.

Account deletion demo video (recorded on a physical device):
https://drive.google.com/drive/folders/1z7XvuV8vKqbGrs9lAGXzM94_3J124x1K?usp=drive_link

Note: the Google Sign-In option present in the previous build has been
removed from the iOS app. New-user registration requires SMS OTP
verification; please use the demo accounts above to sign in directly.
