# Secondhand Marketplace

A Hebrew-first (RTL) marketplace app for buying and selling second-hand items locally.
Flutter client, Firebase backend, AI features on top of Cloud Functions.

Every sale in this version is **self-pickup**: the buyer orders in the app, the seller
marks the item ready, the buyer gets the pickup address, and the buyer confirms the
pickup when they collect it.

## Features

- **AI search.** You type what you want in plain Hebrew and the LLM turns it into
  structured filters (category, brand, price range, condition, location).
- **Visual search.** You search by photo.
- **AI listing assistant.** Photo analysis fills in the listing fields. It also
  rewrites descriptions, scores photo quality and moderates images.
- **Personalized feed.** The feed blends a per-user taste profile (categories, brands,
  price band), proximity, trending scores and a discovery slot.
- **Expected price.** It estimates a fair price from real sale signals, grouped by
  category, brand, model and condition.
- **Orders.** Single-item and multi-seller cart checkout, and stock-managed listings.
  Price offers and counter-offers reserve the item for the buyer. Stripe card payments
  are optional; pay-on-pickup works without them.
- **Chat.** Buyer and seller chat with attachments and warnings about paying outside
  the app.
- **Seller reviews.** Only verified purchases can review. Reviews support photos,
  seller replies, "helpful" votes and moderation flags.
- **Storefronts and stories.** Sellers get customizable storefronts and 24-hour stories.
- **Smart alerts.** You can save searches and follow sellers. You get notified about
  new matches and price drops.
- **Support.** Order problem reports turn into support tickets. A staff console handles
  assignment, internal notes and dispute resolution.
- **Admin dashboard.** Analytics, user management, a brand catalog review queue and AI
  usage monitoring.

## Architecture

```
lib/
  core/       routing (go_router), theme, services (location, notifications, payments)
  features/   one folder per feature: data / domain / presentation
  shared/     models and widgets used across features
functions/    Node.js Cloud Functions (AI, orders, payments, notifications, signals)
firestore.rules, storage.rules, firestore.indexes.json
test/         Dart unit and widget tests
```

- **State.** Riverpod.
- **Data.** Cloud Firestore with security rules. Clients can only move an order along
  its allowed status transitions. Money fields and dispute fields can only be written
  by the server.
- **Server.** Cloud Functions handle payment intents, the Stripe webhook, order side
  effects (restock and refund on cancel, seller stats on completion), unpaid-order
  expiry, disputes, AI endpoints, push notifications through an FCM queue, and
  scheduled rollups.
- **AI.** LLM calls go through Groq and Gemini. Output is checked against strict JSON
  schemas, and usage is tracked per feature.

### Order flow

```
pending ──(card payment confirmed)──> paid ──(seller)──> readyForPickup ──(buyer)──> completed
   └──────────────(pay on pickup)──────────────────────────┘
```

Cancelling restores stock and refunds card payments. Buyers can report a problem, and
staff resolve it from the support console.

## Getting started

Requirements: Flutter 3.35+, Node.js 20, the Firebase CLI and a Firebase project of
your own.

```bash
flutter pub get
flutterfire configure              # generates lib/core/utils/firebase_options.dart
cd functions && npm install && cp .env.example .env && cd ..
firebase deploy --only firestore,storage,functions
flutter run --dart-define=MAPS_API_KEY=... --dart-define=STRIPE_PUBLISHABLE_KEY=...
```

Android also needs `android/app/google-services.json` and `MAPS_API_KEY=...` in
`android/local.properties`. Card payments are off by default. Turn them on with
`FeatureFlags.paymentEnabled`.

## Live demo build

The web build can run as a public demo: guests can sign in without an account, a
DEMO banner is shown, and guest data is wiped every night.

```bash
flutter build web --dart-define=DEMO_MODE=true --dart-define=MAPS_API_KEY=...
firebase deploy --only hosting
```

For the nightly cleanup, set `DEMO_MODE=true` in `functions/.env`. Also turn on
**Anonymous** sign-in in Firebase Authentication. Only use this on a dedicated demo
project.

## Tests

```bash
flutter test          # feed ranking, similarity, taste profile, UI geometry, widgets
cd functions && npm test
```
