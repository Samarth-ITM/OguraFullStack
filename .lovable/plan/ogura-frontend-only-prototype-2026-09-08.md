# OGURA — Frontend-Only Prototype

Build the complete OGURA storefront prototype exactly as specified: dark editorial luxury UI, full route map, 311 product styles / 1,463 variants from the uploaded catalog, all commerce interactions local only. No backend, no payments, no uploads, no network calls for catalog data.

## One stack correction

This project runs on TanStack Start (file-based routing under `src/routes/`), not plain Vite + React Router. Everything else in the brief is followed literally; routes are created as TanStack route files instead of a `react-router` registry, with `src/config/routes.ts` acting as the central route/nav registry. All paths, params and behaviours stay exactly as written.

## Build order

1. **Foundations** — `src/config/appMode.ts` (mock / frontendOnly / payments off / uploads off / auth off), design tokens in `src/styles.css` (full colour set, Cormorant Garamond + Manrope via root `<link>`, radii 0–8px, spacing scale, 1440px max width, reduced-motion support).
2. **Placeholder media system** — the eight placeholder components, local SVG/CSS wine-to-charcoal blocks, stable `slotId` + role + ratio + target sizes + alt, aspect-ratio boxes so nothing shifts.
3. **Data** — parse the uploaded workbook once into `src/data/generated/products.ts` (311) and `variants.ts` (1,463), plus brands, designers, collections, reviews, orders, homepage and merchandising mocks. Prices are regenerated deterministically from product ID against the hard taxonomy (₹1,111–₹15,000; exactly 202 in ₹1,111–₹2,999; the eight sub-band targets reconciled to 311), overriding workbook prices. MRP only when strictly greater and arithmetically valid.
4. **Domain + repositories** — `domain/catalog.ts`, `domain/commerce.ts`, repository interfaces (Catalog, Cart, Wishlist, Account, Checkout) with mock implementations resolving after a deterministic 150–300ms. Pages consume interfaces only. Dev-only state switcher for loading/empty/error.
5. **State** — cart, buy-now context, wishlist, recently viewed, search history, filters, checkout draft, mock session; all localStorage-backed.
6. **Navigation** — 72–80px header transparent over hero then sticky, primary nav SHOP / BRANDS / DESIGNERS / OCCASIONS / MADE TO ORDER, keyboard-accessible SHOP mega-menu with Shop by Price group, search overlay with all states, mobile drawer + bottom nav (suppressed in checkout), four-column footer with newsletter.
7. **Product card + rails + grid** — exact card anatomy and badge priority, Quick Add variant selector, all card states, neutral pincode delivery line.
8. **Homepage** — all 15 sections in locked order with the specified counts and CTAs; no autoplay rails.
9. **PLP engine** — one engine for category, subcategory, collection, New In, brand, designer, occasion and search. 24-style batches (4×6 / 3×8 / 2×12), Load More +24, inserts after 12 and 36 that never consume product slots, 12 filters in order, sort options, merchandising rules, URL-encoded filters/sort/batch with scroll restore, per-category banner and chip templates.
10. **PDP** — 12 sections, 60/40 desktop, sticky mobile bar, category-specific gallery slot sets, Add to Bag vs Buy Now behaviour, mock reviews.
11. **Directories & programs** — brands, designers, occasions, launchpad, made-to-order landing and request flow (filename-only reference control).
12. **Commerce** — wishlist, cart drawer, cart page grouped by seller, six-step mock checkout, `DEMO-OG-XXXX` order, success page stating no payment was processed.
13. **Shells** — mock auth + account, seller and admin screens, all labelled `Prototype`, route-level code split.
14. **States, a11y, verification** — skeleton/empty/error/no-results everywhere, keyboard journey home → PLP → PDP → cart → checkout, focus traps, live regions, AA contrast; then reconciliation checks (311 / 1,463 / `202 / 311 = 64.95%`), typecheck, production build, browser pass at 320/375/390/768/1024/1280/1440.

## Explicitly not built

Cloud, database, auth, storage, edge functions, payments, shipping/tax/delivery APIs, email/SMS, admin mutations, remote images, secrets.

## Report at the end

Routes implemented, reusable components, product/SKU counts, PLP batch verification, widths tested, typecheck/build results, deferred backend integrations.
