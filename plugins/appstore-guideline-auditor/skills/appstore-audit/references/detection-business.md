# ABOUTME: Detection guidance and non-compliant/compliant pairs for the business rule category (Apple section 3).

Loaded by the `business` subagent. One section per rule, keyed by the rule's
`guidance` slug.

Everything here turns on a distinction the code does not state: **is what is
being sold digital or physical?** Apple's payment rules apply to digital content
and services. A payment SDK in a food-delivery app is correct; the same SDK
selling a subscription is a rejection. Nothing in the source says which, so most
of this category is PROBABLE by construction, and saying what you could not
confirm is the substance of the finding rather than a caveat on it.

## digital-goods-outside-iap

A third-party payment SDK together with digital-purchase vocabulary.

**Do not fire on the SDK alone.** Stripe, PayPal, Braintree, Adyen and Square are
all legitimate and expected in apps selling physical goods or real-world
services. Ride-hailing, delivery, ticketing and marketplace apps all carry one.

Before emitting, look for what is actually charged for. Digital signals:
`subscription`, `premium`, `unlockFeature`, `proVersion`, `removeAds`, `credits`,
`coins`, `tokens`. Physical signals: `shipping`, `address`, `delivery`, `cart`,
`booking`, `reservation`.

```swift
// Non-compliant — a digital unlock through a third-party processor
StripeAPI.charge(amount: 999) { PremiumFeatures.unlock() }

// Compliant — a real-world service, correctly outside IAP
StripeAPI.charge(amount: 1450) { DeliveryOrder.confirm(to: shippingAddress) }
```

State in `unconfirmed` that you could not confirm whether the charge covers a
digital or a physical good. That sentence is what stops this finding being an
accusation.

## hardcoded-price-string

A currency literal in a UI string, in a file that also uses StoreKit. Grades
PROVEN — the literal is at a line.

A hardcoded price is wrong in every storefront but one, and wrong everywhere
after a price change.

```swift
// Non-compliant
Text("$9.99 / month")

// Compliant — the price StoreKit returns, localized
Text(product.displayPrice)
```

**Do not fire on** a currency literal in a comment, a test, or a string that is
plainly not a price (`"$0 balance"` in a placeholder is worth a second look, not
a finding).

## subscription-terms-not-disclosed

An auto-renewable subscription paywall must show price, period, what is
included, and links to terms of service and privacy policy — **on the paywall**,
not only in settings.

Detect subscription APIs together with the absence of terms and privacy
vocabulary. Grade PROBABLE: the links may be built from a constant elsewhere, or
rendered by a paywall SDK.

## restore-purchases-absent

StoreKit purchase code with no `restoreCompletedTransactions`, `AppStore.sync`
or `currentEntitlements`.

Reviewers look for the control specifically. Even where entitlements resolve
automatically from `currentEntitlements` on launch, a visible Restore Purchases
button is what gets tested, so recommend it rather than treating automatic
resolution as sufficient.

**Do not fire when** the app sells only consumables — those are not restorable.

## external-purchase-link-unentitled

An outbound link with purchase vocabulary, and no
`com.apple.developer.storekit.external-purchase-link` entitlement.

Two legitimate routes exist: the entitlement, or the United States storefront
allowance under 3.1.1(a). Name both in the resolution — an app shipping only to
the US storefront may need no change at all, and telling it to apply for an
entitlement it does not need is a bad fix.

## receipt-validated-on-device-only

`appStoreReceiptURL` read with no server verification nearby. A **suggestion**,
not a rejection: Apple does not reject for this, but on-device-only validation is
trivially bypassed.

Prefer recommending StoreKit 2's verified transaction result over receipt-file
parsing, which is the older shape this pattern usually indicates.

## loot-box-odds-undisclosed

Randomised purchasable items with no odds vocabulary. Apple requires the odds of
each item type be disclosed before purchase.

**Do not fire when** the randomised item is earned rather than bought. Confirm a
purchase path reaches it; a daily free reward wheel is not a loot box.

## iap-products-approved

MANUAL. Product state lives in App Store Connect. A product identifier in source
proves the app asks for it, not that it exists or is attached to this version.

Show it whenever StoreKit product loading is present, and **list the product
identifiers the scan found**. A list to check beats a reminder to check.

## brazil-alternative-payment-terms

MANUAL, regional and dated. Carries `applies_to.storefronts: ["BR"]` and an
effective date, so it is verified against the **policy sources** rather than the
guidelines page — which contains no mention of Brazil or CADE at all.

The finding must name the storefront and the source it was verified against. On
a run where the policy sources were not retrieved, its citation state is
`unverified` and the report says so.

Show it when the scan found Brazilian payment vocabulary — Pix, boleto,
Mercado Pago, PagSeguro, BRL — or say it applies to any app distributed there.

## eu-core-technology-commission

MANUAL, regional and dated: from October 1 2026 the Core Technology Fee is
replaced by a 5% Core Technology Commission for developers on the EU alternative
terms.

Which terms an account is on is account state. The item exists to make the
developer check, not to decide for them. Same policy-source verification as
above.

## korea-grac-rating-override

MANUAL, regional and dated. Games distributed in the Republic of Korea need a
GRAC classification number entered in App Store Connect, and Apple's October 2026
reclassification moves some descriptors to 12+.

Same policy-source verification. Show it for any app that could be distributed
there — the cost of showing it wrongly is one line a developer skips; the cost of
omitting it is a held submission.
