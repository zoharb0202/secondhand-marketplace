# Cloud Functions

Node.js 20 backend for the marketplace, deployed as Firebase Cloud Functions.

## Setup

```bash
cd functions
npm install
cp .env.example .env   # fill in your own keys
npm test
firebase deploy --only functions
```

## What lives here

| Area | Functions |
| --- | --- |
| Orders & payments | `createPaymentIntent`, `stripeWebhook`, `onOrderStatusChanged`, `expirePendingUnpaidOrders` |
| Disputes & support | `reportOrderProblem`, `resolveOrderDispute`, `listSupportAgents`, `assignSupportTicket`, `updateSupportTicketStatus`, `setSupportTicketPriority`, `addSupportInternalNote` |
| AI | `aiProductSearch`, `analyzeProductImage`, `analyzePhotoQuality`, `enhanceDescription`, `moderateImage`, `chatbot`, `suggestBrand`, `getPersonalizedRecommendations` |
| Discovery | `computeTrendingScores`, `updateTasteProfiles`, `rollupDailyProductStats`, `createSmartAlert`, `matchProductToAlerts`, saved-search, follower and price-drop notifications |
| Pricing signals | `getExpectedPrice`, `recordSaleSignal`, `logSearchClick`, `logListingOutcome`, `rollupSignals`, retail-price estimates |
| Reviews | `submitSellerReview`, `replyToSellerReview`, `markSellerReviewHelpful`, `flagSellerReview`, `aggregateSellerRating` |
| Offers & chat | `acceptCounterOffer`, `expireOfferReservations`, offer and chat push notifications |
| Platform | push notification queue, image variants, attachment cleanup, legal consent records, GDPR account deletion |

## Order lifecycle

```
pending ──(Stripe webhook)──> paid ──(seller)──> readyForPickup ──(buyer)──> completed
   └──────── pay-on-pickup orders skip "paid" ──────────┘

pending ──(buyer or seller)──> cancelled
paid / readyForPickup ──(seller)──> cancelled        stock restored, card payment refunded
paid / readyForPickup / completed ──(buyer report)──> disputed ──(staff)──> cancelled | completed | previous state
```

- Prices are never trusted from the client. `createPaymentIntent` re-derives every
  line item from the product catalog, or from an accepted price offer, before charging.
- A payment that lands after its order was cancelled is refunded automatically.
- The exact pickup address and the seller's phone are copied onto the order only once
  it is paid (or, for pay-on-pickup, marked ready).
