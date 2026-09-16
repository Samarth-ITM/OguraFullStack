# OGURA FRONTEND FORENSIC EXTRACTION

## 1. Extraction Metadata

- **Extraction Date:** 2026-09-14
- **Inspector Role:** OGURA Execution Engineer (Forensic Extraction Mode Only)
- **Target Repository:** `.` (repository root)
- **Output File:** `/DOCS/frontend.md`
- **Extraction Rules Applied:** 
  - Read-Only Forensic Extraction.
  - Zero application code modifications.
  - Zero UI/UX, styling, or taxonomy changes.
  - Zero backend implementations (no database, no Edge Functions, no RPCs).
  - Concrete file and line evidence cited for all findings.

---

## 2. Repository / Technology Overview

- **Framework:** TanStack Start (`@tanstack/react-start` 1.168.32, `@tanstack/react-router` 1.170.18)
- **Runtime / React:** React 19.2.0, React DOM 19.2.0
- **Language / Typing:** TypeScript 5.8.3 (`tsconfig.json`)
- **Package Manager:** Bun / npm (`bun.lock`, `bunfig.toml`, `package.json`)
- **Build Tool:** Vite 8.1.5 (`vite.config.ts`, `@lovable.dev/vite-tanstack-config` 2.20.0)
- **Styling System:** Tailwind CSS v4 (`tailwindcss` 4.2.1, `@tailwindcss/vite` 4.2.1, `tw-animate-css` 1.3.4, `src/styles.css`)
- **UI Components:** Radix UI primitives (`@radix-ui/react-*`), Lucide icons (`lucide-react` 0.575.0), Sonner toasts (`sonner` 2.0.7)
- **Client State Management:** External Store with `useSyncExternalStore` (`src/state/store.ts`), React Context (`src/state/ui.tsx`), TanStack Query 5.101.1 (`src/router.tsx`)
- **Data Access Architecture:** Contract interfaces (`src/repositories/contracts/index.ts`) backed by in-memory mock repositories (`src/repositories/mock/index.ts`)
- **Latency & Network Simulation:** Synthetic delay utility (`src/repositories/mock/latency.ts`)
- **Testing Framework:** None installed. Zero test files present in repository.
- **Backend / Cloud Platform:** Completely absent. No Supabase client, no Firebase, no PostgreSQL client, no active API routes.

---

## 3. Project Structure

```text
ogura-marketplace
├── .gitignore
├── .lovable/
│   ├── plan/ogura-frontend-only-prototype-2026-09-08.md
│   └── project.json
├── AGENTS.md
├── DOCS/
│   └── frontend.md
├── README.md
├── bun.lock
├── bunfig.toml
├── components.json
├── eslint.config.js
├── package.json
├── public/
│   ├── favicon.png
│   └── robots.txt
├── src/
│   ├── assets/home/
│   │   ├── campaign-festive.jpg, editorial-look.jpg, hero-desktop.jpg, hero-mobile.jpg
│   │   └── tile-celebrity-fashion.jpg, tile-designer-curations.jpg, tile-festive-edit.jpg, ...
│   ├── components/
│   │   ├── commerce/ (CartDrawer.tsx, ProductCard.tsx, ProductRail.tsx, RecentlyViewedRail.tsx, TrustBadges.tsx)
│   │   ├── layout/ (Footer.tsx, Header.tsx, MobileNav.tsx, SearchOverlay.tsx, StaticPage.tsx)
│   │   ├── media/ (CatalogProductImage.tsx, Placeholder.tsx, slots.tsx)
│   │   ├── plp/ (EditorialInsert.tsx, FilterPanel.tsx, PlpEngine.tsx, usePlpQuery.ts)
│   │   ├── ui/ (Radix primitives: accordion, dialog, drawer, dropdown, sheet, etc.)
│   │   └── ui-og/ (primitives.tsx)
│   ├── config/
│   │   ├── appMode.ts
│   │   └── navigation.ts
│   ├── data/
│   │   ├── generated/ (brands.ts, homepageMedia.ts, productMedia.json, productMedia.ts, products.ts, variants.ts)
│   │   ├── mediaSlots.ts
│   │   ├── mockDesigners.ts
│   │   ├── mockHomepage.ts
│   │   ├── mockMerchandising.ts
│   │   ├── mockReviews.ts
│   │   └── taxonomy.ts
│   ├── domain/
│   │   ├── catalog.ts
│   │   └── commerce.ts
│   ├── hooks/
│   │   └── use-mobile.tsx
│   ├── lib/
│   │   ├── error-capture.ts, error-page.ts, format.ts, lovable-error-reporting.ts, storage.ts, utils.ts
│   ├── repositories/
│   │   ├── contracts/index.ts
│   │   ├── mock/ (catalog.ts, index.ts, latency.ts, productMediaRepository.ts)
│   │   └── index.ts
│   ├── routeTree.gen.ts
│   ├── router.tsx
│   ├── routes/ (50 route files, __root.tsx, README.md)
│   ├── server.ts
│   ├── start.ts
│   ├── state/
│   │   ├── store.ts
│   │   └── ui.tsx
│   └── styles.css
├── tsconfig.json
└── vite.config.ts
```

---

## 4. Package / Dependency Inventory

| Package | Version | Purpose | Where Used |
|:---|:---|:---|:---|
| `@tanstack/react-start` | 1.168.32 | Fullstack SSR / TanStack Start server runtime | `src/start.ts`, `src/server.ts` |
| `@tanstack/react-router` | 1.170.18 | File-based client/server routing | All files in `src/routes/`, `src/router.tsx` |
| `@tanstack/react-query` | 5.101.1 | Async state management & query cache | `src/router.tsx`, `src/routes/__root.tsx` |
| `react` | 19.2.0 | Core UI library | Codebase-wide |
| `react-dom` | 19.2.0 | React DOM rendering | Codebase-wide |
| `tailwindcss` | 4.2.1 | Utility-first CSS styling | `src/styles.css` |
| `@tailwindcss/vite` | 4.2.1 | Vite integration plugin for Tailwind v4 | `vite.config.ts` |
| `@radix-ui/react-*` | Various | Accessible unstyled UI primitives | `src/components/ui/*` |
| `lucide-react` | 0.575.0 | SVG icon set | Header, Nav, ProductCard, PLP, CartDrawer |
| `sonner` | 2.0.7 | Toast notification system | `src/routes/__root.tsx`, ProductCard, PDP, Account |
| `zod` | 3.25.76 | TypeScript schema validation | Available in package; imported in utility schemas |
| `react-hook-form` | 7.71.2 | Form state management | Available in package; `src/components/ui/form.tsx` |
| `clsx` & `tailwind-merge` | 2.1.1 / 3.5.0 | Conditional className merging | `src/lib/utils.ts` (`cn`) |
| `class-variance-authority`| 0.7.1 | Component variant styling | `src/components/ui/*` |
| `date-fns` | 4.1.0 | Date formatting utilities | UI presentation |
| `recharts` | 2.15.4 | SVG charting library | `src/components/ui/chart.tsx` |
| `embla-carousel-react` | 8.6.0 | Touch-friendly carousel engine | `src/components/ui/carousel.tsx` |
| `input-otp` | 1.4.2 | One-time password input primitive | `src/components/ui/input-otp.tsx` |
| `vaul` | 1.1.2 | Drawer component primitive | `src/components/ui/drawer.tsx` |
| `cmdk` | 1.1.1 | Command palette primitive | `src/components/ui/command.tsx` |
| `@lovable.dev/vite-tanstack-config` | 2.20.0 | Lovable dev tooling configuration | `vite.config.ts` |

---

## 5. Route Inventory

Every single route in `src/routes/` is individually extracted:

### 1. `/`
- **File:** `src/routes/index.tsx`
- **Actor:** Public Visitor
- **Purpose:** Marketplace homepage presenting campaign hero, promise strip, 6 explore tiles, and curated product rails.
- **Access Type:** Public
- **Data Required:** 6 curated product lists (New In, Under 3k, Ethnicwear, Accessories, Footwear, Made-to-Order), designers list (8 items), recently viewed IDs, hero & campaign media slots.
- **Data Source:** `listProductsSync` (`src/repositories/mock/catalog.ts`), `mockDesigners` (`src/data/mockDesigners.ts`), `HOMEPAGE_MEDIA` (`src/data/generated/homepageMedia.ts`).
- **Repositories / Services Used:** `catalogRepository` (via `listProductsSync`), `pushRecentlyViewed`.
- **User Actions:** Click hero CTA, click explore tiles, click product cards, click designer profiles, click category links.
- **Mutations:** None.
- **State Used:** `useOguraState(s => s.recentlyViewed)`.
- **Local Storage Used:** `ogura.recentlyViewed` (read-only on this screen).
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** CMS/Homepage layout API, dynamic product collection queries, designer discovery query.
- **External Dependencies:** None.
- **Current Mock Behavior:** In-memory synchronous filtering over static 311 products.
- **Notes:** All rails compute slices deterministically in `useMemo`.

### 2. `/shop`
- **File:** `src/routes/shop.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** Full catalog discovery listing all styles.
- **Access Type:** Public
- **Data Required:** Filtered product lists, total count, aggregate facets (sizes, colors, price bands, brands, categories).
- **Data Source:** `PlpEngine` (`src/components/plp/PlpEngine.tsx`) reading `generatedProducts`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Filter selection, sort changes, batch loading (+24 items), quick add, wishlist toggle.
- **Mutations:** URL query parameter updates, cart line appends, wishlist toggles.
- **State Used:** URL search parameters, `useOguraState`.
- **Local Storage Used:** `ogura.cart`, `ogura.wishlist`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Full-text search, facet calculation, catalog filtering.
- **External Dependencies:** None.
- **Current Mock Behavior:** Client-side array filtering in `filterProducts()`.

### 3. `/new-in`
- **File:** `src/routes/new-in.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** Discover recently added styles.
- **Access Type:** Public
- **Data Required:** Products where `newArrival: true` sorted by `newest`.
- **Data Source:** `PlpEngine` with `baseQuery={{ newArrival: true, sort: "newest" }}`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Filter, sort, pagination, add to cart.
- **Mutations:** URL parameters, cart line appends.
- **State Used:** URL search parameters.
- **Local Storage Used:** `ogura.cart`, `ogura.wishlist`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Catalog read query with date sorting.
- **External Dependencies:** None.
- **Current Mock Behavior:** Filtered client-side.

### 4. `/brands`
- **File:** `src/routes/brands.tsx`
- **Actor:** Public Visitor
- **Purpose:** Alphabetical directory of all brands / independent studios on OGURA.
- **Access Type:** Public
- **Data Required:** List of brands, locations, style counts, logo slots.
- **Data Source:** `mockDesigners` (`src/data/mockDesigners.ts`).
- **Repositories / Services Used:** In-memory array.
- **User Actions:** Search brands by text, click brand card.
- **Mutations:** Local React input state (`q`).
- **State Used:** React `useState`.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Brand listing query.
- **External Dependencies:** None.
- **Current Mock Behavior:** Client-side string filtering and alphabetical grouping.

### 5. `/brand/$brandSlug`
- **File:** `src/routes/brand.$brandSlug.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** Brand profile page with banner, statement, metadata, and styles.
- **Access Type:** Public
- **Data Required:** Brand entity by slug, products where `brandSlug === $brandSlug`.
- **Data Source:** `mockDesignerBySlug` and `PlpEngine`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Read brand story, filter brand styles, add to cart.
- **Mutations:** URL search params.
- **State Used:** Route loader data, URL search.
- **Local Storage Used:** `ogura.cart`, `ogura.wishlist`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Brand profile query, brand product listing.
- **External Dependencies:** None.
- **Current Mock Behavior:** Map lookup in `mockDesignerBySlug`.

### 6. `/designers`
- **File:** `src/routes/designers.tsx`
- **Actor:** Public Visitor
- **Purpose:** Designer showcase directory with filter chips (All, New on OGURA, Launchpad, Trending).
- **Access Type:** Public
- **Data Required:** Designer entities, portrait media slots, bio statements.
- **Data Source:** `mockDesigners`.
- **Repositories / Services Used:** In-memory array.
- **User Actions:** Toggle filter chip, click designer card.
- **Mutations:** Local React state (`filter`).
- **State Used:** React `useState`.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Designer directory query with category tags.
- **External Dependencies:** None.
- **Current Mock Behavior:** Filtered in-memory.

### 7. `/designer/$designerSlug`
- **File:** `src/routes/designer.$designerSlug.tsx`
- **Actor:** Public Visitor
- **Purpose:** Deep-dive designer editorial profile with POV, stats, and product rail.
- **Access Type:** Public
- **Data Required:** Designer details, products list by designer.
- **Data Source:** `mockDesignerBySlug`, `listProductsSync`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Click product card, click "Shop all {designer.name}".
- **Mutations:** None.
- **State Used:** Route loader data.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Designer details query, designer product query.
- **External Dependencies:** None.
- **Current Mock Behavior:** Synchronous in-memory lookup.

### 8. `/occasions`
- **File:** `src/routes/occasions.tsx`
- **Actor:** Public Visitor
- **Purpose:** Directory of the 8 shopping occasions (Wedding Guest, Festive, Party, Brunch, Date Night, Vacation, Work, Casual).
- **Access Type:** Public
- **Data Required:** 8 Occasion definitions, counts of matching styles.
- **Data Source:** `OCCASIONS` (`src/data/taxonomy.ts`), `filterProducts`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Click occasion tile.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Occasion taxonomy & count aggregation.
- **External Dependencies:** None.
- **Current Mock Behavior:** Array count calculated in render loop.

### 9. `/occasion/$occasionSlug`
- **File:** `src/routes/occasion.$occasionSlug.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** PLP filtered by occasion tag.
- **Access Type:** Public
- **Data Required:** Occasion entity, matching styles.
- **Data Source:** `OCCASIONS` array, `PlpEngine`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Filter, sort, pagination, add to bag.
- **Mutations:** URL parameters.
- **State Used:** Route loader data, URL search.
- **Local Storage Used:** `ogura.cart`, `ogura.wishlist`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Product listing filtered by occasion enum.
- **External Dependencies:** None.
- **Current Mock Behavior:** In-memory array filtering.

### 10. `/collections`
- **File:** `src/routes/collections.index.tsx`
- **Actor:** Public Visitor
- **Purpose:** Curated collections directory (Price Collections & Style Collections).
- **Access Type:** Public
- **Data Required:** Price collections, style collections, style counts.
- **Data Source:** `PRICE_COLLECTIONS`, `STYLE_COLLECTIONS` (`src/data/taxonomy.ts`).
- **Repositories / Services Used:** `collectionCount` (`src/repositories/mock/catalog.ts`).
- **User Actions:** Click collection link.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Collection rules & count aggregation.
- **External Dependencies:** None.
- **Current Mock Behavior:** In-memory rule evaluation.

### 11. `/collections/$collectionSlug`
- **File:** `src/routes/collections.$collectionSlug.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** PLP driven by curated collection rules (min/max price, subcategories, product types).
- **Access Type:** Public
- **Data Required:** Collection definition, matching products.
- **Data Source:** `COLLECTION_BY_SLUG` (`src/data/taxonomy.ts`), `PlpEngine`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Filter, sort, batch load, add to bag.
- **Mutations:** URL search params.
- **State Used:** Route loader data.
- **Local Storage Used:** `ogura.cart`, `ogura.wishlist`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Dynamic query execution based on collection criteria.
- **External Dependencies:** None.
- **Current Mock Behavior:** In-memory regex and price checks.

### 12. `/women/$categorySlug`
- **File:** `src/routes/women.$categorySlug.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** Top-level category PLP (Clothing, Ethnicwear, Footwear, Accessories).
- **Access Type:** Public
- **Data Required:** Category entity, subcategories list, category products.
- **Data Source:** `CATEGORY_BY_SLUG` (`src/data/taxonomy.ts`), `PlpEngine`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Select subcategory chip, filter, sort, add to bag.
- **Mutations:** URL search params.
- **State Used:** Route loader data.
- **Local Storage Used:** `ogura.cart`, `ogura.wishlist`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Category catalog query with facet aggregation.
- **External Dependencies:** None.
- **Current Mock Behavior:** In-memory filtering by category name.

### 13. `/women/$categorySlug/$subcategorySlug`
- **File:** `src/routes/women.$categorySlug.$subcategorySlug.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** Subcategory PLP (e.g. Dresses, Sarees, Heels, Bags).
- **Access Type:** Public
- **Data Required:** Category entity, subcategory entity, products list.
- **Data Source:** `CATEGORY_BY_SLUG`, `PlpEngine`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Filter by size, color, price; add to bag.
- **Mutations:** URL search params.
- **State Used:** Route loader data.
- **Local Storage Used:** `ogura.cart`, `ogura.wishlist`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Subcategory catalog query.
- **External Dependencies:** None.
- **Current Mock Behavior:** In-memory filtering by subcategory name.

### 14. `/product/$productSlug`
- **File:** `src/routes/product.$productSlug.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** Product Detail Page (PDP) displaying multi-angle gallery, variant selector, pricing, pincode ETA checker, accordion details, customer reviews, and recommendation rails.
- **Access Type:** Public
- **Data Required:** Product entity, associated SKU variants, gallery images, reviews, similar products, brand products.
- **Data Source:** `productBySlug`, `variantsByProduct`, `productMediaRepository`, `reviewsForProduct`, `listProductsSync`.
- **Repositories / Services Used:** `mockCatalogRepository`, `productMediaRepository`, `addToCart`, `setBuyNow`, `toggleWishlist`, `pushRecentlyViewed`.
- **User Actions:** Select color swatch, select size pill, change quantity, check pincode, toggle wishlist, click "Add to Bag", click "Buy Now", switch info tabs.
- **Mutations:** Appends to `cart.lines`, writes `buyNow` line, updates `wishlist`, updates `recentlyViewed`.
- **State Used:** React `useState` (color, size, qty, pincode, eta, activeImage, tab), `useOguraState`.
- **Local Storage Used:** `ogura.cart`, `ogura.buyNow`, `ogura.wishlist`, `ogura.recentlyViewed`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Product entity by slug, live variant inventory check, real pincode courier serviceability, published reviews query.
- **External Dependencies:** Google Drive thumbnail proxy (`renderableUrl`).
- **Current Mock Behavior:** Synchronous lookup; fake pincode formula (`4 + (pincode[5] % 4)`); mock reviews generator.

### 15. `/cart`
- **File:** `src/routes/cart.tsx`
- **Actor:** Public Visitor / Buyer (Guest or Logged In)
- **Purpose:** Full-page shopping bag review with line item quantity editing, removals, order summary calculation, and checkout CTA.
- **Access Type:** Public / Customer
- **Data Required:** Cart line items joined with product metadata and variant details.
- **Data Source:** `useOguraState(s => s.cart.lines)` + in-memory maps (`productById`, `variantsByProduct`).
- **Repositories / Services Used:** `updateCartQuantity`, `removeCartLine`.
- **User Actions:** Increment quantity, decrement quantity, remove line, click "Checkout".
- **Mutations:** Mutates lines in `ogura.cart`.
- **State Used:** `useOguraState`.
- **Local Storage Used:** `ogura.cart` (Read / Write).
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Server cart retrieval, stock validation, authoritative subtotal and shipping calculation.
- **External Dependencies:** None.
- **Current Mock Behavior:** All calculations executed on client. Shipping computed as ₹149 if subtotal < ₹2,999.

### 16. `/checkout`
- **File:** `src/routes/checkout.tsx`
- **Actor:** Customer / Buyer (Guest or Logged In)
- **Purpose:** 5-step checkout flow (Contact, Address, Delivery, Payment, Review) culminating in order placement.
- **Access Type:** Public / Customer
- **Data Required:** Cart lines or Buy Now line, saved checkout draft, address inputs, delivery method, payment method.
- **Data Source:** `useOguraState` (`cart`, `buyNow`, `checkoutDraft`), `mockCheckoutRepository`.
- **Repositories / Services Used:** `repositories.checkout.validateDraft`, `repositories.checkout.createMockOrder`, `clearCart`, `setBuyNow`, `saveCheckoutDraft`.
- **User Actions:** Fill email/phone, fill address, select standard/express delivery, select payment method, click "Place prototype order".
- **Mutations:** Mutates `ogura.checkoutDraft`, writes new order to `ogura.orders`, clears `ogura.cart` or `ogura.buyNow`.
- **State Used:** React `useState` (step, draft, errors, placing), `useOguraState`.
- **Local Storage Used:** `ogura.cart`, `ogura.buyNow`, `ogura.checkoutDraft`, `ogura.orders`.
- **Auth Dependency:** Implicit (User types phone/email, no authentication challenge).
- **Role Dependency:** None.
- **Backend Dependencies:** Address persistence, inventory reservation lock, authoritative tax/shipping calculation, Razorpay order creation, payment signature verification, atomic order placement.
- **External Dependencies:** None (Payment step is a mock radio button).
- **Current Mock Behavior:** Generates `DEMO-OG-XXXX` on client; marks order as `placed`; saves directly to browser `localStorage`.

### 17. `/order/success/$orderId`
- **File:** `src/routes/order.success.$orderId.tsx`
- **Actor:** Customer / Buyer
- **Purpose:** Order confirmation screen stating order number, date, purchased items, totals, and recipient address.
- **Access Type:** Customer
- **Data Required:** Order object matching `$orderId`.
- **Data Source:** `useOguraState(s => s.orders.find(o => o.orderNumber === orderId))`.
- **Repositories / Services Used:** In-memory store.
- **User Actions:** Click "Continue shopping", click "View all orders".
- **Mutations:** None.
- **State Used:** `useOguraState`.
- **Local Storage Used:** `ogura.orders` (Read).
- **Auth Dependency:** None (Lookup performed against local storage array by URL param).
- **Role Dependency:** None.
- **Backend Dependencies:** Secure order query scoped to authenticated customer or verified guest session.
- **External Dependencies:** None.
- **Current Mock Behavior:** Reads exclusively from current browser's localStorage.

### 18. `/wishlist`
- **File:** `src/routes/wishlist.tsx`
- **Actor:** Customer / Buyer
- **Purpose:** Grid view of all styles saved by the user.
- **Access Type:** Public / Customer
- **Data Required:** Wishlisted product IDs joined with product entities.
- **Data Source:** `useOguraState(s => s.wishlist)`, `productById`.
- **Repositories / Services Used:** In-memory map.
- **User Actions:** Click heart to remove, click product card to view, quick add to bag.
- **Mutations:** Removes items from `ogura.wishlist`.
- **State Used:** `useOguraState`.
- **Local Storage Used:** `ogura.wishlist` (Read / Write).
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Server-side customer wishlist table.
- **External Dependencies:** None.
- **Current Mock Behavior:** Unauthenticated client array.

### 19. `/track-order`
- **File:** `src/routes/track-order.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** Informational page on how order tracking operates.
- **Access Type:** Public
- **Data Required:** Static explainer text.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read static text.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Live courier shipment tracking API (AWB query).
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page with zero input fields or API hooks.

### 20. `/made-to-order`
- **File:** `src/routes/made-to-order.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** PLP dedicated to made-to-order and customizable styles.
- **Access Type:** Public
- **Data Required:** Products where `madeToOrder: true`.
- **Data Source:** `PlpEngine` with `baseQuery={{ madeToOrder: true }}`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Filter, sort, add to bag.
- **Mutations:** URL parameters.
- **State Used:** URL search.
- **Local Storage Used:** `ogura.cart`, `ogura.wishlist`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Catalog read filtered by MTO flag.
- **External Dependencies:** None.
- **Current Mock Behavior:** In-memory filtering.

### 21. `/launchpad`
- **File:** `src/routes/launchpad.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** PLP dedicated to emerging designer labels.
- **Access Type:** Public
- **Data Required:** Products where `launchpad: true`.
- **Data Source:** `PlpEngine` with `baseQuery={{ launchpad: true }}`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Filter, sort, add to bag.
- **Mutations:** URL parameters.
- **State Used:** URL search.
- **Local Storage Used:** `ogura.cart`, `ogura.wishlist`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Catalog query filtered by launchpad flag.
- **External Dependencies:** None.
- **Current Mock Behavior:** In-memory filtering.

### 22. `/gift-card`
- **File:** `src/routes/gift-card.tsx`
- **Actor:** Public Visitor
- **Purpose:** Static explainer on gift card denominations, delivery, and validity.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read text.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Gift card ledger & redemption backend.
- **External Dependencies:** None.
- **Current Mock Behavior:** Static text stating purchases are disabled in prototype.

### 23. `/search`
- **File:** `src/routes/search.tsx`
- **Actor:** Public Visitor / Buyer
- **Purpose:** Dedicated search results PLP matching term `q`.
- **Access Type:** Public
- **Data Required:** Products matching query string `q`.
- **Data Source:** `useLocation` search params + `PlpEngine`.
- **Repositories / Services Used:** `mockCatalogRepository`.
- **User Actions:** Filter results, sort, batch load, add to bag.
- **Mutations:** URL search params.
- **State Used:** URL search.
- **Local Storage Used:** `ogura.cart`, `ogura.wishlist`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** PostgreSQL full-text search / Trigram search.
- **External Dependencies:** None.
- **Current Mock Behavior:** In-memory token matching across title, brand, category, tags.

### 24. `/account` (and `/account/`)
- **File:** `src/routes/account.tsx` and `src/routes/account.index.tsx`
- **Actor:** Customer / Buyer
- **Purpose:** Buyer account layout with navigation sidebar and overview KPI cards (Orders, Wishlist, Addresses, Profile).
- **Access Type:** Customer (Mocked)
- **Data Required:** Profile status, orders count, wishlist count.
- **Data Source:** `useOguraState` (`profile`, `orders`, `wishlist`).
- **Repositories / Services Used:** In-memory store.
- **User Actions:** Click overview cards to navigate to sub-routes.
- **Mutations:** None.
- **State Used:** `useOguraState`.
- **Local Storage Used:** `ogura.session`, `ogura.orders`, `ogura.wishlist`.
- **Auth Dependency:** Fake (displays "Guest" or "Signed in" based on localStorage).
- **Role Dependency:** None.
- **Backend Dependencies:** Authenticated customer profile & summary KPIs.
- **External Dependencies:** None.
- **Current Mock Behavior:** Reads local storage.

### 25. `/account/profile`
- **File:** `src/routes/account.profile.tsx`
- **Actor:** Customer / Buyer
- **Purpose:** View and edit personal name, email, and phone, with Sign In / Sign Out toggles.
- **Access Type:** Customer (Mocked)
- **Data Required:** Customer profile fields (`name`, `email`, `phone`, `signedIn`).
- **Data Source:** `useOguraState(s => s.profile)`.
- **Repositories / Services Used:** `signIn`, `signOut` (`src/state/store.ts`).
- **User Actions:** Enter name, email, phone; click "Save details"; click "Sign out".
- **Mutations:** Overwrites `ogura.session` in localStorage.
- **State Used:** React `useState` (form), `useOguraState`.
- **Local Storage Used:** `ogura.session` (Read / Write).
- **Auth Dependency:** Mocked. Clicking "Save details" marks user as authenticated without verification.
- **Role Dependency:** None.
- **Backend Dependencies:** Supabase Auth (Phone OTP verification, Session token).
- **External Dependencies:** None.
- **Current Mock Behavior:** Unsecured client-side state mutation.

### 26. `/account/orders`
- **File:** `src/routes/account.orders.tsx`
- **Actor:** Customer / Buyer
- **Purpose:** List past orders placed in the current browser.
- **Access Type:** Customer (Mocked)
- **Data Required:** Array of Order objects.
- **Data Source:** `useOguraState(s => s.orders)`.
- **Repositories / Services Used:** In-memory store.
- **User Actions:** Click "View details" to open order confirmation page.
- **Mutations:** None.
- **State Used:** `useOguraState`.
- **Local Storage Used:** `ogura.orders` (Read).
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Authenticated orders query (`orders WHERE customer_id = auth.uid()`).
- **External Dependencies:** None.
- **Current Mock Behavior:** Reads exclusively from current browser's localStorage.

### 27. `/account/addresses`
- **File:** `src/routes/account.addresses.tsx`
- **Actor:** Customer / Buyer
- **Purpose:** View saved addresses and add new delivery addresses.
- **Access Type:** Customer (Mocked)
- **Data Required:** Saved address list.
- **Data Source:** `useOguraState(s => s.checkoutDraft?.address)` + local React state.
- **Repositories / Services Used:** In-memory store.
- **User Actions:** Fill address form (Name, Phone, Line 1, Line 2, City, State, Pincode), click "Save address".
- **Mutations:** Appends address to local React state.
- **State Used:** React `useState` (form, local addresses, error).
- **Local Storage Used:** None directly (stored in component memory).
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Customer address book CRUD (`addresses` table with RLS).
- **External Dependencies:** None.
- **Current Mock Behavior:** Ephemeral React state lost on page refresh.

### 28. `/account/wishlist`
- **File:** `src/routes/account.wishlist.tsx`
- **Actor:** Customer / Buyer
- **Purpose:** Wishlist sub-view within account layout.
- **Access Type:** Customer (Mocked)
- **Data Required:** Wishlisted products.
- **Data Source:** `useOguraState(s => s.wishlist)`, `productById`.
- **Repositories / Services Used:** In-memory map.
- **User Actions:** View saved items.
- **Mutations:** Wishlist toggles.
- **State Used:** `useOguraState`.
- **Local Storage Used:** `ogura.wishlist`.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Customer wishlist table.
- **External Dependencies:** None.
- **Current Mock Behavior:** Reads localStorage.

### 29. `/seller` (and `/seller/`)
- **File:** `src/routes/seller.tsx` and `src/routes/seller.index.tsx`
- **Actor:** Seller (Designer / Brand Owner)
- **Purpose:** Designer workspace dashboard presenting mock 30-day GMV, order volume, average rating, and recent fulfillment activity.
- **Access Type:** Seller (Unprotected Prototype Shell)
- **Data Required:** Seller KPIs (live styles count, 30d GMV, orders count, rating, recent activity log).
- **Data Source:** Hardcoded stats array + `allProducts.slice(0, 18)`.
- **Repositories / Services Used:** None.
- **User Actions:** Read dashboard metrics.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** Completely missing (Route has zero auth checks).
- **Role Dependency:** Completely missing (No role verification).
- **Backend Dependencies:** Seller analytics RPC, seller sub-order aggregation.
- **External Dependencies:** None.
- **Current Mock Behavior:** Hardcoded static figures (`GMV ₹4,86,000`, `132 orders`).

### 30. `/seller/products`
- **File:** `src/routes/seller.products.tsx`
- **Actor:** Seller
- **Purpose:** Seller inventory table displaying style name, category, price, variant count, and status.
- **Access Type:** Seller (Unprotected Prototype Shell)
- **Data Required:** Products owned by the seller.
- **Data Source:** `allProducts.slice(0, 24)` (`src/repositories/mock/catalog.ts`).
- **Repositories / Services Used:** In-memory array.
- **User Actions:** View styles table, click product link.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Seller product inventory query (`products WHERE seller_id = auth.seller_id()`).
- **External Dependencies:** None.
- **Current Mock Behavior:** Arbitrary slice of platform products.

### 31. `/seller/orders`
- **File:** `src/routes/seller.orders.tsx`
- **Actor:** Seller
- **Purpose:** Seller fulfillment order queue showing orders to pack and dispatch.
- **Access Type:** Seller (Unprotected Prototype Shell)
- **Data Required:** List of seller sub-orders with fulfillment status (`placed`, `packed`, `shipped`, `delivered`).
- **Data Source:** Hardcoded mapping over `allProducts.slice(30, 42)`.
- **Repositories / Services Used:** None.
- **User Actions:** View order queue.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Sub-order queue query scoped to seller ID, status transition RPC.
- **External Dependencies:** None.
- **Current Mock Behavior:** Fake orders generated from catalog slice.

### 32. `/seller/payouts`
- **File:** `src/routes/seller.payouts.tsx`
- **Actor:** Seller
- **Purpose:** Seller financial payout schedule showing bi-monthly settlement cycles and status.
- **Access Type:** Seller (Unprotected Prototype Shell)
- **Data Required:** Payout cycles, net payout amounts, status (Paid, Scheduled).
- **Data Source:** Hardcoded `PAYOUTS` array.
- **Repositories / Services Used:** None.
- **User Actions:** View payout schedule.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Seller ledger & payout settlement engine.
- **External Dependencies:** None.
- **Current Mock Behavior:** 3 hardcoded static payout cycles.

### 33. `/admin` (and `/admin/`)
- **File:** `src/routes/admin.tsx` and `src/routes/admin.index.tsx`
- **Actor:** Platform Admin
- **Purpose:** Internal operations console overview showing total styles, variants, designers, and MTO counts.
- **Access Type:** Admin (Unprotected Prototype Shell)
- **Data Required:** Platform catalog aggregates.
- **Data Source:** `allProducts.length`, `allVariants.length`, `generatedBrands.length`.
- **Repositories / Services Used:** In-memory arrays.
- **User Actions:** Read platform metrics.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** Completely missing (No auth guard).
- **Role Dependency:** Completely missing (No admin check).
- **Backend Dependencies:** Platform administration KPI query.
- **External Dependencies:** None.
- **Current Mock Behavior:** Array `.length` counts over static data.

### 34. `/admin/catalog`
- **File:** `src/routes/admin.catalog.tsx`
- **Actor:** Platform Admin
- **Purpose:** Administrative catalog management table showing style, designer, category, price, and price band.
- **Access Type:** Admin (Unprotected Prototype Shell)
- **Data Required:** Full product catalog table.
- **Data Source:** `allProducts.slice(0, 40)`.
- **Repositories / Services Used:** In-memory array.
- **User Actions:** View catalog table, click style link.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Admin catalog query with moderation filters.
- **External Dependencies:** None.
- **Current Mock Behavior:** Slices first 40 static products.

### 35. `/admin/orders`
- **File:** `src/routes/admin.orders.tsx`
- **Actor:** Platform Admin
- **Purpose:** Master order log for platform administrators.
- **Access Type:** Admin (Unprotected Prototype Shell)
- **Data Required:** Platform-wide master order list.
- **Data Source:** `useOguraState(s => s.orders)`.
- **Repositories / Services Used:** In-memory store.
- **User Actions:** View orders log.
- **Mutations:** None.
- **State Used:** `useOguraState`.
- **Local Storage Used:** `ogura.orders` (Read).
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Master orders query across all customers and sellers.
- **External Dependencies:** None.
- **Current Mock Behavior:** Reads exclusively from current browser's customer localStorage (`ogura.orders`). If tested on a clean device, admin sees 0 orders.

### 36. `/admin/merchandising`
- **File:** `src/routes/admin.merchandising.tsx`
- **Actor:** Platform Admin
- **Purpose:** Merchandising overview of price and style collections with active style counts.
- **Access Type:** Admin (Unprotected Prototype Shell)
- **Data Required:** Collections list with style counts.
- **Data Source:** `ALL_COLLECTIONS`, `collectionCount`.
- **Repositories / Services Used:** In-memory functions.
- **User Actions:** View collections overview.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Dynamic merchandising rule builder query.
- **External Dependencies:** None.
- **Current Mock Behavior:** Evaluates in-memory collection rules.

### 37. `/seller-program`
- **File:** `src/routes/seller-program.tsx`
- **Actor:** Public Visitor / Potential Seller
- **Purpose:** Marketing landing page explaining commission structure, onboarding process, and studio requirements.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read marketing copy.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** None (Seller onboarding form is future scope).
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page.

### 38. `/join-as-designer`
- **File:** `src/routes/join-as-designer.tsx`
- **Actor:** Public Visitor / Potential Designer
- **Purpose:** Application criteria and curator review guidelines for prospective labels.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read criteria.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Designer application submission API.
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page.

### 39. `/help`
- **File:** `src/routes/help.tsx`
- **Actor:** Public Visitor
- **Purpose:** Customer FAQ covering ordering, measurements, lead times, and cancellations.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read FAQ.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** None.
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page.

### 40. `/contact`
- **File:** `src/routes/contact.tsx`
- **Actor:** Public Visitor
- **Purpose:** Customer support email, operating hours, studio visits, and press inquiries.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read contact info.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** Support ticket submission.
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page.

### 41. `/shipping`
- **File:** `src/routes/shipping.tsx`
- **Actor:** Public Visitor
- **Purpose:** Shipping policy, delivery SLAs (4–7 days standard, 2–4 days express), packaging standards.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read shipping policy.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** None.
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page.

### 42. `/returns`
- **File:** `src/routes/returns.tsx`
- **Actor:** Public Visitor
- **Purpose:** 7-day return window, condition criteria, reverse pickup explanation, refund methods.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read returns policy.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** None.
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page.

### 43. `/stores`
- **File:** `src/routes/stores.tsx`
- **Actor:** Public Visitor
- **Purpose:** Partner studio locations and offline viewing appointments.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read studio details.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** None.
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page.

### 44. `/about`
- **File:** `src/routes/about.tsx`
- **Actor:** Public Visitor
- **Purpose:** OGURA brand mission, founding philosophy, and curation principles.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read about page.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** None.
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page.

### 45. `/careers`
- **File:** `src/routes/careers.tsx`
- **Actor:** Public Visitor
- **Purpose:** Open positions and engineering/curation culture.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read careers copy.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** None.
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page.

### 46. `/privacy`
- **File:** `src/routes/privacy.tsx`
- **Actor:** Public Visitor
- **Purpose:** Privacy policy, data handling, analytics notice, contact for data removal.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read privacy policy.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** None.
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page.

### 47. `/terms`
- **File:** `src/routes/terms.tsx`
- **Actor:** Public Visitor
- **Purpose:** Marketplace terms of service, designer contracts, dispute jurisdiction.
- **Access Type:** Public
- **Data Required:** Static copy.
- **Data Source:** Static `SECTIONS` array.
- **Repositories / Services Used:** None.
- **User Actions:** Read terms.
- **Mutations:** None.
- **State Used:** None.
- **Local Storage Used:** None.
- **Auth Dependency:** None.
- **Role Dependency:** None.
- **Backend Dependencies:** None.
- **External Dependencies:** None.
- **Current Mock Behavior:** Static page.

---

## 6. Shared Component Inventory

| Component | File | Used By | Purpose | Props | State | Data Dependencies | Repositories / Services | Local Storage | Auth Dependencies | Backend Dependencies | Side Effects | Notes |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| `Header` | `src/components/layout/Header.tsx` | `__root.tsx` | Main top navigation bar (logo, mega menu, search trigger, bag counter, account link). | None | Mega-menu open state, scroll shadow | Primary nav config, bag count, wishlist count | None | `ogura.cart`, `ogura.wishlist` | None | None | Toggles UI context drawers | Sticky on scroll |
| `Footer` | `src/components/layout/Footer.tsx` | `__root.tsx` | 4-column footer with links & newsletter input. | None | Newsletter email state | Navigation config | None | None | None | Newsletter subscription API | Toast on submit | Client toast only |
| `MobileNav` & `MobileDrawer` | `src/components/layout/MobileNav.tsx` | `__root.tsx` | Bottom tab bar on mobile + slideout navigation drawer. | None | Drawer open | Navigation config, bag count | None | `ogura.cart` | None | None | Drawer toggle | Suppressed on `/checkout` |
| `SearchOverlay` | `src/components/layout/SearchOverlay.tsx` | `__root.tsx` | Full-screen modal with debounced search input, quick brand/category matches, and search history. | None | `term`, `results`, `status` | `catalogRepository.searchProducts`, search history | `catalogRepository` | `ogura.searchHistory` | None | Instant search autocomplete API | Pushes to search history | Debounced by 220ms |
| `CartDrawer` | `src/components/commerce/CartDrawer.tsx` | `__root.tsx` | Slideout bag drawer displaying line items, variant details, subtotal, and checkout link. | None | None (uses UI context) | Cart lines, product info, variant info | `removeCartLine` | `ogura.cart` | None | Server cart query & mutation | Removes item | Focus trap enabled |
| `PlpEngine` | `src/components/plp/PlpEngine.tsx` | 8 PLP routes | Unified discovery engine with filter sheet, sort dropdown, batch loading (+24), and editorial inserts. | `title`, `description`, `crumbs`, `baseQuery`, `templateKey`, `chipBasePath`, `showSubcategoryFilter` | `sheetOpen`, `pending` | `listProductsSync`, `usePlpSearch`, `PLP_TEMPLATES` | `mockCatalogRepository` | URL Search parameters | None | Filtered catalog query + facet calculation | Navigation URL update | Inserts placed at index 12 and 36 |
| `FilterPanel` | `src/components/plp/FilterPanel.tsx` | `PlpEngine.tsx` | 12 accordion filter groups (Subcategories, Sizes, Price, Brands, Colors, Occasions, Styles, Fits, Materials, Discount, Availability, MTO). | Facets data, selected filters, toggle handler, clear handler | Accordion open states | Product facet counts | None | URL Search parameters | None | Dynamic facet query | Modifies URL query params | Fully keyboard accessible |
| `ProductCard` | `src/components/commerce/ProductCard.tsx` | PLP, rails, wishlist | Garment presentation card with badge priority, hover secondary image, quick-add size selector, and wishlist toggle. | `product: Product` | `pending`, `added`, `hover` | Variants, colors, primary/secondary images, wishlist state | `addToCart`, `setBuyNow`, `toggleWishlist` | `ogura.cart`, `ogura.buyNow`, `ogura.wishlist` | None | Live stock verification | Modifies local storage, triggers toast | Badge priority: Sold Out > Limited > New > MTO > Launchpad > Discount |
| `ProductRail` | `src/components/commerce/ProductRail.tsx` | Home, PDP, Designer | Horizontal scrollable rail of product cards with prev/next buttons. | `products: Product[]`, `perView: number`, `ariaLabel: string` | None | Array of products | None | None | None | None | Scroll animation | No autoplay |
| `CatalogProductImage` | `src/components/media/CatalogProductImage.tsx` | ProductCard, PDP, Cart | Image renderer that resolves primary/secondary Drive thumbnails with error fallback. | `productId`, `title`, `alt`, `role` | `failed` state | `productMediaRepository` | `productMediaRepository` | None | None | CDN Image delivery | Logs console warning on failure | Converts drive links to thumbnails |
| `TrustBadges` | `src/components/commerce/TrustBadges.tsx` | PDP, Cart | Trust signals: Authenticity, 7-day returns, insured transit, artisan craft. | Variant: `panel` or `line` | None | Static strings | None | None | None | None | None | Pure presentational |

---

## 7. Repository / Service Inventory

All repositories are registered in `src/repositories/index.ts` and implemented in `src/repositories/mock/index.ts` & `src/repositories/mock/catalog.ts`.

### 1. `catalogRepository`
- **File:** `src/repositories/mock/catalog.ts:273`
- **Methods:**
  - `listProducts(query: ProductQuery): Promise<ProductListResult>`
    - Callers: `PlpEngine.tsx`
    - Input: `ProductQuery`
    - Output: `{ items: Product[], total: number, facets: Facets }`
    - Data Source: `generatedProducts`, `generatedVariants`
    - Sync/Async: Async (via `simulate`)
    - Mock/Live: Mock
    - Persistence: In-memory
    - Auth Dependency: None
    - Side Effects: Simulates network latency (150–300ms)
    - Business Logic: Multi-attribute filtering, 7 sort algorithms, `diversifyByBrand` streak limiter
    - Backend Requirement: PostgreSQL live query / view
    - Security Sensitivity: Low
  - `getProduct(slug: string): Promise<{ product: Product; variants: Variant[] } | null>`
    - Callers: `product.$productSlug.tsx`
    - Input: `slug: string`
    - Output: Product entity + variant array
    - Data Source: `productBySlug`, `variantsByProduct`
    - Sync/Async: Async (via `simulate`)
    - Mock/Live: Mock
    - Persistence: In-memory
    - Auth Dependency: None
    - Side Effects: Latency simulation
    - Business Logic: Finds product and joins associated variants
    - Backend Requirement: Single product query by slug with variant relation
    - Security Sensitivity: Low
  - `searchProducts(q: string, limit?: number): Promise<Product[]>`
    - Callers: `SearchOverlay.tsx`
    - Input: `q: string, limit = 8`
    - Output: Product array
    - Data Source: `allProducts`
    - Sync/Async: Async (via `simulate`)
    - Mock/Live: Mock
    - Persistence: In-memory
    - Auth Dependency: None
    - Side Effects: Latency simulation
    - Business Logic: Substring token search across 9 entity fields
    - Backend Requirement: PostgreSQL full-text search RPC
    - Security Sensitivity: Low
  - `listBrands(): Promise<Brand[]>`
    - Callers: Navigation, Directories
    - Input: None
    - Output: `Brand[]`
    - Data Source: `generatedBrands`
    - Sync/Async: Async
    - Mock/Live: Mock
    - Persistence: In-memory
    - Auth Dependency: None
    - Side Effects: Latency simulation
    - Backend Requirement: Active brands query
    - Security Sensitivity: Low
  - `getBrand(slug: string): Promise<Brand | null>`
    - Callers: Brand routes
    - Input: `slug: string`
    - Output: `Brand` or `null`
    - Data Source: `brandBySlug`
    - Sync/Async: Async
    - Mock/Live: Mock
    - Persistence: In-memory
    - Auth Dependency: None
    - Backend Requirement: Brand query by slug
    - Security Sensitivity: Low
  - `listCollections(): Promise<Collection[]>`
    - Callers: Merchandising
    - Input: None
    - Output: `Collection[]`
    - Data Source: `ALL_COLLECTIONS`
    - Sync/Async: Async
    - Mock/Live: Mock
    - Persistence: In-memory
    - Auth Dependency: None
    - Backend Requirement: Active collections query
    - Security Sensitivity: Low
  - `getCollection(slug: string): Promise<Collection | null>`
    - Callers: Collection route
    - Input: `slug: string`
    - Output: `Collection` or `null`
    - Data Source: `COLLECTION_BY_SLUG`
    - Sync/Async: Async
    - Mock/Live: Mock
    - Persistence: In-memory
    - Auth Dependency: None
    - Backend Requirement: Collection query by slug
    - Security Sensitivity: Low

### 2. `cartRepository`
- **File:** `src/repositories/mock/index.ts:21`
- **Methods:**
  - `getCart(): Promise<Cart>`
    - Input: None | Output: `{ lines: CartLine[] }` | Source: `localStorage.ogura.cart`
  - `addVariant(productId, variantId, quantity): Promise<Cart>`
    - Input: `productId, variantId, quantity = 1` | Output: `Cart` | Source: `addToCart()`
    - Business Logic: If variant exists, clamps quantity to max 10. Otherwise appends line with ID `${variantId}-${Date.now()}`.
  - `updateQuantity(lineId, quantity): Promise<Cart>`
    - Input: `lineId, quantity` | Output: `Cart` | Source: `updateCartQuantity()`
    - Business Logic: Clamps between 0 and 10; removes if 0.
  - `removeLine(lineId): Promise<Cart>`
    - Input: `lineId` | Output: `Cart` | Source: `removeCartLine()`
  - `clearCart(): Promise<Cart>`
    - Input: None | Output: `{ lines: [] }` | Source: `clearCart()`
- **Backend Requirement:** Server-side `cart_lines` table with RPCs for upsert, remove, and stock verification.
- **Security Sensitivity:** HIGH (Client manages cart items and lines without stock verification).

### 3. `wishlistRepository`
- **File:** `src/repositories/mock/index.ts:39`
- **Methods:**
  - `list(): Promise<string[]>` | Output: Product ID array | Source: `localStorage.ogura.wishlist`
  - `toggle(productId): Promise<string[]>` | Input: `productId` | Output: Product ID array
- **Backend Requirement:** `customer_wishlist` table with unique `(user_id, product_id)`.
- **Security Sensitivity:** Low.

### 4. `accountRepository`
- **File:** `src/repositories/mock/index.ts:48`
- **Methods:**
  - `getProfile(): Promise<Profile>` | Output: `{ name, email, phone, signedIn }` | Source: `localStorage.ogura.session`
  - `updateProfile(patch): Promise<Profile>` | Input: `Partial<Profile>` | Source: `signIn(next)`
  - `listOrders(): Promise<Order[]>` | Output: `Order[]` | Source: `localStorage.ogura.orders` (via `simulate`)
  - `getOrder(orderNumber): Promise<Order | null>` | Input: `orderNumber` | Source: `localStorage.ogura.orders`
- **Backend Requirement:** `profiles` and `orders` tables protected by RLS.
- **Security Sensitivity:** CRITICAL (Reads and updates profile and orders directly from unauthenticated browser storage).

### 5. `checkoutRepository`
- **File:** `src/repositories/mock/index.ts:71`
- **Methods:**
  - `validateDraft(draft: CheckoutDraft): Promise<Record<string, string>>`
    - Input: `CheckoutDraft` | Output: Field errors map
    - Business Logic: Validates email regex, 10-digit phone, required street address, and 6-digit pincode.
  - `createMockOrder(draft: CheckoutDraft, address: Address): Promise<Order>`
    - Input: `draft, address` | Output: `Order`
    - Business Logic:
      1. Reads items from `buyNow` or `cart.lines`.
      2. Assembles line items with prices from in-memory catalog.
      3. Computes subtotal.
      4. Calculates shipping: `subtotal >= 2999 ? 0 : 99`.
      5. Generates random order number: `DEMO-OG-${Math.floor(1000 + Math.random() * 9000)}`.
      6. Hardcodes status: `status = 'placed'`.
      7. Saves order directly to `localStorage.ogura.orders`.
- **Backend Requirement:** Server-authoritative Order Creation Edge Function with Razorpay initialization.
- **Security Sensitivity:** CRITICAL (Client decides pricing, shipping, order ID, and order placement).

### 6. `productMediaRepository`
- **File:** `src/repositories/mock/productMediaRepository.ts`
- **Methods:**
  - `getProductMedia(sourceProductId): ProductMediaRecord | null`
  - `getProductGallery(sourceProductId): ProductImageRecord[]`
  - `getPrimaryImage(sourceProductId): ProductImageRecord | null`
  - `getSecondaryImage(sourceProductId): ProductImageRecord | null`
  - `renderableUrl(image: { url: string }): string`
    - Converts Google Drive file ID into `https://drive.google.com/thumbnail?id=${id}&sz=w1200`.
  - `markImageFailed(image)` / `hasImageFailed(url)`
- **Backend Requirement:** Media asset database table and CDN asset delivery.
- **Security Sensitivity:** Medium (Relies on external Google Drive thumbnail infrastructure).

---

## 8. Data Source Inventory

| Source Name | File Reference | Used By | Data Contained | Read/Write | Persistence | Production Status | Notes |
|:---|:---|:---|:---|:---|:---|:---|:---|
| `generatedProducts` | `src/data/generated/products.ts` | `catalogRepository`, PLP, PDP, Home | 311 product style records (ID, slug, title, prices, attributes) | Read-only | Static File | Prototype Mock | Deterministically generated from workbook |
| `generatedVariants` | `src/data/generated/variants.ts` | `catalogRepository`, PDP, Cart | 1,463 SKU records (SKU, size, color, inventory, price) | Read-only | Static File | Prototype Mock | Inventory numbers are static values |
| `generatedBrands` | `src/data/generated/brands.ts` | `catalogRepository`, Brands, PDP | 35 Brand entities (name, slug, location, established year) | Read-only | Static File | Prototype Mock | Static JSON-like TS structure |
| `productMedia.json` | `src/data/generated/productMedia.json` | `productMediaRepository.ts` | Manifest mapping product IDs to Google Drive image links | Read-only | Static File | Temporary Prototype | Google Drive export URLs |
| `taxonomy.ts` | `src/data/taxonomy.ts` | Categories, Nav, PLP, Filters | Categories, Subcategories, Occasions, Price Collections, Style Collections | Read-only | Static File | Canonical Prototype Spec | Authoritative reference for MVP |
| `mockHomepage.ts` | `src/data/mockHomepage.ts` | `index.tsx` | Explore tiles, Promise strip items, Footwear service cards | Read-only | Static File | Prototype Content | Hardcoded editorial copy |
| `mockMerchandising.ts` | `src/data/mockMerchandising.ts` | `PlpEngine.tsx` | Banners, chips, and editorial inserts at index 12 & 36 | Read-only | Static File | Prototype Content | Contains broken link `/made-to-order/request` |
| `mockReviews.ts` | `src/data/mockReviews.ts` | PDP (`product.$productSlug.tsx`) | Deterministic review generator based on string hash | Read-only | In-Memory Generator | Prototype Mock | Up to 8 reviews per product |
| `mockDesigners.ts` | `src/data/mockDesigners.ts` | Designers directory & PDP | Augments brands with `isNew` flag | Read-only | In-Memory Map | Prototype Mock | Extends `generatedBrands` |
| `localStorage.ogura.*` | `src/lib/storage.ts` | State store, Cart, Wishlist, Checkout | Active cart lines, checkout draft, session profile, placed orders | Read & Write | Browser Storage | Temporary Client Mock | Unencrypted client storage |

---

## 9. Local Persistence

The repository centralizes all browser storage in `src/lib/storage.ts` under the `KEYS` object:

| Storage Key | File | Purpose | Readers | Writers | Data Format | Lifetime | Security Sensitivity | Current Role | Backend Replacement Required? |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| `ogura.cart` | `src/lib/storage.ts:22` | Stores customer's active cart lines | `hydrate()` in `store.ts`, `CartDrawer`, `cart.tsx`, `checkout.tsx` | `addToCart`, `updateCartQuantity`, `removeCartLine`, `clearCart` | JSON: `{ lines: CartLine[] }` | Persistent across browser sessions | HIGH (Client-controlled cart) | Authoritative cart state in prototype | **YES** (Server `cart_lines` table) |
| `ogura.buyNow` | `src/lib/storage.ts:23` | Temporary line item for 1-click checkout | `checkout.tsx` | `setBuyNow` (from PDP or ProductCard) | JSON: `CartLine \| null` | Persistent until cleared or order placed | HIGH (Bypasses cart validation) | Authoritative buy-now state | **YES** (Server checkout intent) |
| `ogura.wishlist` | `src/lib/storage.ts:24` | List of wishlisted product IDs | `hydrate()`, `wishlist.tsx`, `ProductCard`, PDP | `toggleWishlist` | JSON: `string[]` (Product IDs) | Persistent | Low | Customer wishlist | **YES** (`customer_wishlist` table) |
| `ogura.recentlyViewed` | `src/lib/storage.ts:25` | 12 most recently viewed product IDs | `hydrate()`, `RecentlyViewedRail.tsx` | `pushRecentlyViewed` (on PDP mount) | JSON: `string[]` (Max 12 IDs) | Persistent | None | UI convenience | Optional (Can remain in client storage or profile) |
| `ogura.searchHistory` | `src/lib/storage.ts:26` | 8 most recent search terms | `SearchOverlay.tsx` | `pushSearchHistory`, `clearSearchHistory` | JSON: `string[]` (Max 8 terms) | Persistent | None | Search overlay suggestions | Client-only feature |
| `ogura.checkoutDraft` | `src/lib/storage.ts:27` | Form inputs from checkout steps | `checkout.tsx`, `account.addresses.tsx` | `saveCheckoutDraft` | JSON: `CheckoutDraft` | Persistent | Medium (Contains plain text PII) | Form auto-fill | **YES** (Server user address book) |
| `ogura.session` | `src/lib/storage.ts:28` | Customer profile & signed-in flag | `hydrate()`, `Header.tsx`, `account.tsx`, `account.profile.tsx` | `signIn`, `signOut` | JSON: `{ name, email, phone, signedIn }` | Persistent | CRITICAL (Unverified identity) | Session proof in prototype | **YES** (Supabase Auth JWT & session) |
| `ogura.orders` | `src/lib/storage.ts:29` | List of orders placed in this browser | `hydrate()`, `account.orders.tsx`, `order.success.$orderId.tsx`, `admin.orders.tsx` | `saveOrder` (from `createMockOrder`) | JSON: `Order[]` | Persistent | CRITICAL (Fake client orders treated as truth) | Order history in prototype | **YES** (Server `orders` table) |
| `ogura.addresses` | `src/lib/storage.ts:30` | Defined in `KEYS` constant | None (unused key) | None | Unused | N/A | None | Dead key | **YES** (Replaced by `addresses` table) |
| `ogura.reviews` | `src/lib/storage.ts:31` | Defined in `KEYS` constant | None (unused key) | None | Unused | N/A | None | Dead key | **YES** (Replaced by `product_reviews` table) |

---

## 10. Authentication

### 1. Implementation Analysis
- **File:** `src/state/store.ts` (Lines 182–190) and `src/routes/account.profile.tsx` (Lines 34–52)
- **Functions:** `signIn(profile: Profile)`, `signOut()`, `useOguraState(s => s.profile)`
- **Trigger:** Clicking "Save details" in `/account/profile`
- **Input:** `{ name: string, email: string, phone: string }`
- **Output:** Writes to memory and `localStorage.setItem('ogura.session', JSON.stringify({ ...form, signedIn: true }))`
- **Stored State:** `state.profile = { name, email, phone, signedIn: true }`
- **Trusted Source:** Browser localStorage (Zero server interaction)
- **Security Implication:** Any user can spoof any identity or phone number. No OTP verification, no password, no session cookie, no token expiration, no cryptographic signature.
- **Backend Dependency:** Supabase Auth with SMS OTP provider (Twilio / Msg91).
- **Current Mock Behavior:** Fully client-side dummy session.

---

## 11. Authorization

### 1. Route & Component Guard Audit
A comprehensive search was performed across all routes for authorization guards, role checks, and protected route wrappers:

| Protected Area | File Reference | Observed Logic | Action Protected | Client-Only? | Server Equivalent Required? |
|:---|:---|:---|:---|:---|:---|
| `/account/*` | `src/routes/account.tsx` | **NO GUARD.** Mounts unconditionally. Shows "Guest" or "Signed in" text. | Access to account overview | Yes | **YES** (`auth.uid() IS NOT NULL`) |
| `/seller/*` | `src/routes/seller.tsx` | **NO GUARD.** Mounts unconditionally. Displays `PrototypeTag`. | Access to seller workspace, GMV, orders, payouts | Yes | **YES** (Role = `seller` & seller ID matching) |
| `/admin/*` | `src/routes/admin.tsx` | **NO GUARD.** Mounts unconditionally. Displays `PrototypeTag`. | Access to admin operations console, catalog, orders | Yes | **YES** (Role = `platform_admin`) |
| Order Detail | `src/routes/order.success.$orderId.tsx:21` | `orders.find(o => o.orderNumber === orderId)` | Viewing order details | Yes | **YES** (RLS: `customer_id = auth.uid()`) |

---

## 12. Buyer Account

| User Action | Frontend Function | File | State | Data Source | Persistence | Auth | Backend Dependency | Current Mock Behavior |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| View Overview | `AccountOverview` | `account.index.tsx` | `profile`, `orders`, `wishlist` | `store.ts` | Local Storage | Mocked | Customer profile query | Reads local state |
| Edit Profile | `setForm`, `signIn` | `account.profile.tsx:35` | `profile` | Form input | `ogura.session` | Mocked | Profile update mutation | Overwrites local JSON |
| Sign Out | `signOut` | `account.profile.tsx:45` | `profile` | None | `ogura.session` | Mocked | Auth logout / revoke token | Resets profile to `GUEST` |
| View Orders | `OrdersPage` | `account.orders.tsx:20` | `orders` | `store.ts` | `ogura.orders` | Mocked | Orders query (`customer_id`) | Reads local orders array |
| Add Address | `add` | `account.addresses.tsx:41` | `local` | Form input | Component State | None | Address insert mutation | Appends to React array (Lost on refresh) |
| View Wishlist | `WishlistPage` | `wishlist.tsx` | `wishlist` | `store.ts` | `ogura.wishlist` | None | Wishlist query | Reads local product IDs |
| Track Order | `Page` | `track-order.tsx` | None | Static copy | Static | None | Live courier AWB tracking API | Static explainer only |

---

## 13. Cart

### 1. Cart Lifecycle Trace

```text
User Action            Code Location               Operation                           Current Source of Truth
─────────────────────────────────────────────────────────────────────────────────────────────────────────────
1. Select Variant      ProductCard / PDP           Size pill clicked                   Component useState
2. Quick Add           ProductCard.tsx:59          commitCart(variantId)               localStorage.ogura.cart
3. PDP Add to Bag      product.$productSlug.tsx:121 addToCart(productId, variantId, qty)localStorage.ogura.cart
4. Calculate Subtotal  cart.tsx:31                 reduce(variant.price * quantity)    Client-side computation
5. Calculate Shipping  cart.tsx:33                 subtotal >= 2999 ? 0 : 149          Client-side computation
6. Update Quantity     cart.tsx:83                 updateCartQuantity(lineId, qty)     localStorage.ogura.cart
7. Remove Line         cart.tsx:101                removeCartLine(lineId)              localStorage.ogura.cart
8. Clear Cart          checkout.tsx:97             clearCart()                         localStorage.ogura.cart
```

### 2. Trace of Calculations
- **Subtotal Calculation:** `src/routes/cart.tsx:31` & `src/routes/checkout.tsx:47`
  - Input: `line.quantity` × `variant.price`
  - Computed on: **CLIENT ONLY**
  - Trusted: **UNTRUSTED**
- **Savings / Discount Calculation:** `src/routes/cart.tsx:32`
  - Input: `(product.compareAtPrice ?? variant.price) * quantity - subtotal`
  - Computed on: **CLIENT ONLY**
- **Shipping Fee Calculation:**
  - `src/routes/cart.tsx:33`: `subtotal === 0 || subtotal >= 2999 ? 0 : 149`
  - `src/routes/checkout.tsx:48`: `subtotal >= 2999 ? 0 : draft.deliveryMethod === 'express' ? 249 : 99`
  - `src/repositories/mock/index.ts:104`: `subtotal >= 2999 ? 0 : 99`
  - Conflict: 3 separate files execute differing shipping rules!
  - Computed on: **CLIENT ONLY**
- **Inventory & Stock Check:**
  - `ProductCard.tsx:82`: `variants.filter(v => v.availability !== 'sold_out')`
  - Checks static JSON `inventory` field. Does not reserve stock. No concurrency protection.

---

## 14. Checkout

### 1. Checkout Stage Trace (`src/routes/checkout.tsx`)

| Stage | Step | Input Fields | Calculations | State | Side Effects | External Provider | Backend Requirement | Security Sensitivity |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| **Contact** | Step 0 | Email, Mobile Number | Phone regex (`\d{10}`), Email regex | `draft.email`, `draft.phone` | None | None | Phone OTP send & verify | High (Unverified phone) |
| **Address** | Step 1 | Full Name, Line 1, Line 2, City, State, Pincode | Pincode regex (`\d{6}`) | `draft.address.*` | Saves draft to localStorage | None | Validate serviceable address | Medium |
| **Delivery** | Step 2 | Radio: "standard" vs "express" | Standard: Free if subtotal ≥ 2999 else 99; Express: Free if subtotal ≥ 2999 else 249 | `draft.deliveryMethod` | Updates draft | Courier Partner | Authoritative shipping rate calculation | High (Client decides rate) |
| **Payment** | Step 3 | Radio: "card", "upi", "cod" | None (Displays: "No card details collected in prototype") | `draft.paymentMethod` | Updates draft | Razorpay (Stubbed) | Create Razorpay Order & verify HMAC signature | CRITICAL (Mock payment confirmation) |
| **Review** | Step 4 | None (Summary display) | Subtotal + Shipping = Total | View-only | None | None | Review order summary | High |
| **Place Order** | Action | Click "Place prototype order" | Subtotal + Shipping, Random ID generator | `placing = true` | Writes order to `ogura.orders`, clears cart, navigates | None | Atomic transaction (Payment verify + stock decrement + sub-order split) | CRITICAL (Client-authoritative order creation) |

---

## 15. Orders

### 1. Order Status Values in Code
A search for order statuses across the codebase revealed the following 5 status strings:

| Status String | File Reference | Where Used | Who Sets It | What Causes It | Client / Server | Persisted? |
|:---|:---|:---|:---|:---|:---|:---|
| `placed` | `domain/commerce.ts:46`, `mock/index.ts:108`, `seller.orders.tsx:18` | Order creation, buyer order list, seller queue | `createMockOrder` | User clicks "Place prototype order" | Client | Yes (`ogura.orders`) |
| `packed` | `domain/commerce.ts:46`, `seller.orders.tsx:18`, `track-order.tsx:23` | Seller order queue, tracking explainer | Static array / Seller UI | Seller finishes packaging | Client | Yes (in mock array) |
| `shipped` | `domain/commerce.ts:46`, `seller.orders.tsx:18`, `track-order.tsx:23` | Seller queue, tracking explainer | Static array / Seller UI | Courier pickup & AWB assignment | Client | Yes (in mock array) |
| `delivered` | `domain/commerce.ts:46`, `seller.orders.tsx:18`, `track-order.tsx:23` | Seller queue, tracking explainer | Static array / Seller UI | Delivery confirmed by courier | Client | Yes (in mock array) |
| `cancelled` | `domain/commerce.ts:46` | Domain interface definition | Unused in prototype UI | Order cancellation | Client | Interface only |

---

## 16. Catalog / Products

### 1. Product & Variant Field Matrix

| Field | Source | File | Used By | Type | Required? | Client Generated? | Mocked? | Backend Dependency |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| `id` | `generatedProducts` | `domain/catalog.ts:6` | All screens | `string` (UUID) | Yes | No | Yes (Mock DB) | `products.id` PK |
| `slug` | `generatedProducts` | `domain/catalog.ts:7` | Routing, URLs | `string` | Yes | No | Yes | `products.slug` UNIQUE |
| `status` | `generatedProducts` | `domain/catalog.ts:8` | Seller / Admin | `string` | Yes | No | Yes | `products.status` enum |
| `brandId` / `brandSlug` | `generatedProducts` | `domain/catalog.ts:9` | Brand links, PLP | `string` | Yes | No | Yes | `products.brand_id` FK |
| `brandName` | `generatedProducts` | `domain/catalog.ts:11` | ProductCard, PDP, Cart | `string` | Yes | No | Yes | Joined from `brands.name` |
| `title` | `generatedProducts` | `domain/catalog.ts:13` | Everywhere | `string` | Yes | No | Yes | `products.title` |
| `shortDescription` | `generatedProducts` | `domain/catalog.ts:14` | Meta tags, PDP | `string` | Yes | No | Yes | `products.short_description` |
| `price` | `generatedProducts` | `domain/catalog.ts:26` | PLP, PDP, Cart | `number` (INR) | Yes | No | Yes | `products.price` (or variant price) |
| `compareAtPrice` | `generatedProducts` | `domain/catalog.ts:27` | Discounts | `number \| null` | Optional | No | Yes | `products.compare_at_price` |
| `priceBand` | `generatedProducts` | `domain/catalog.ts:29` | Filters, Admin | `string` | Yes | No | Yes | Generated column or filter rule |
| `rating` / `reviewCount` | `generatedProducts` | `domain/catalog.ts:31` | PDP, Sort | `number` | Yes | No | Yes | Aggregated from `product_reviews` |
| `madeToOrder` | `generatedProducts` | `domain/catalog.ts:33` | MTO PLP, Badges | `boolean` | Yes | No | Yes | `products.made_to_order` |
| `launchpad` | `generatedProducts` | `domain/catalog.ts:35` | Launchpad PLP | `boolean` | Yes | No | Yes | `products.launchpad` |
| `newArrival` | `generatedProducts` | `domain/catalog.ts:36` | New In PLP | `boolean` | Yes | No | Yes | `products.new_arrival` |
| `variantIds` | `generatedProducts` | `domain/catalog.ts:39` | Variant resolution | `string[]` | Yes | No | Yes | Relational join with `variants` |
| `sku` | `generatedVariants` | `domain/catalog.ts:47` | Variants | `string` | Yes | No | Yes | `variants.sku` UNIQUE |
| `size` | `generatedVariants` | `domain/catalog.ts:49` | Size selector | `string` | Yes | No | Yes | `variants.size` |
| `color` / `colorHex` | `generatedVariants` | `domain/catalog.ts:50` | Swatches | `string` | Yes | No | Yes | `variants.color`, `color_hex` |
| `inventory` | `generatedVariants` | `domain/catalog.ts:53` | Stock checks | `number` | Yes | No | Yes | `variants.inventory` (Authoritative) |

---

## 17. Search

- **Search Trigger:** Click search icon in `Header.tsx` opens `SearchOverlay.tsx`.
- **Input Handling:** Text input with 220ms debounce (`SearchOverlay.tsx:40`).
- **Processing / Autocomplete:**
  1. Calls `catalogRepository.searchProducts(term, 6)`.
  2. Filters `generatedBrands` for names containing `term` (max 4).
  3. Filters `CATEGORIES` for matching categories and subcategories (max 4).
- **Search History:** On Enter or click result, pushes term to `localStorage.ogura.searchHistory` (max 8 terms).
- **Full Search Page:** Navigates to `/search?q={term}`, triggering `PlpEngine` with `baseQuery={{ q }}`.
- **Matching Algorithm:** Tokenized substring matching across `title`, `brandName`, `category`, `subcategory`, `productType`, `occasion`, `aesthetic`, `colorFamily`, `material`.

---

## 18. Wishlist

- **Read:** `useOguraState(s => s.wishlist)` reads `string[]` of product IDs from `ogura.wishlist`.
- **Toggle:** `toggleWishlist(productId)` in `src/state/store.ts:138`.
  - If ID exists in array, filters it out.
  - If ID does not exist, prepends to array.
  - Writes back to `localStorage.ogura.wishlist`.
- **Authentication Dependency:** None in prototype. Works purely for anonymous visitors.
- **Backend Requirement:** `customer_wishlist(user_id, product_id, created_at)` table with guest-to-user merge on authentication.

---

## 19. Seller

- **Dashboard:** `/seller` reads hardcoded static metrics (`GMV ₹4,86,000`, `132 orders`, `4.4 rating`) and displays a prototype notice.
- **Product Inventory:** `/seller/products` displays the first 24 items of `allProducts` with no ownership checks.
- **Order Queue:** `/seller/orders` maps products 30–42 to simulated orders with static statuses. No action buttons exist to update fulfillment state.
- **Payouts:** `/seller/payouts` displays 3 static payment cycles.
- **Authentication & Ownership:** Completely missing. No seller login, no `seller_id` filtering.

---

## 20. Admin

- **Console Overview:** `/admin` displays platform style count (`allProducts.length`), variant count (`allVariants.length`), and designer count (`generatedBrands.length`).
- **Catalog Moderation:** `/admin/catalog` shows first 40 styles in a read-only table. No approve/reject action buttons exist.
- **Master Orders:** `/admin/orders` reads from `useOguraState(s => s.orders)` (the current browser's local orders).
- **Merchandising:** `/admin/merchandising` counts styles matching price and style collections.
- **Security:** Zero authentication or role verification.

---

## 21. Media

- **Local Editorial Imagery:** `src/assets/home/` contains bundled JPGs (`hero-desktop.jpg`, `hero-mobile.jpg`, `campaign-festive.jpg`, etc.) mapped in `src/data/generated/homepageMedia.ts`.
- **Product Imagery (Google Drive Hotlinking):**
  - Raw metadata stored in `src/data/generated/productMedia.json`.
  - Original URLs follow Google Drive export pattern: `https://drive.google.com/uc?export=view&id={id}`.
  - Transformation function `renderableUrl()` in `src/repositories/mock/productMediaRepository.ts:69` transforms URLs to:
    `https://drive.google.com/thumbnail?id={id}&sz=w1200`.
- **Aspect Ratios (`src/data/mediaSlots.ts`):** Hero (16/9 desktop, 4/5 mobile), Banner (2.4/1), Product (3/4), Portrait (4/5), Review (1/1).
- **Gallery Angles:** Apparel (`front`, `alternate`, `back`, `side`, `detail`, `styled`), Footwear (`primary`, `side`, `top`, `back`, `sole`), Bags (`primary`, `alternate`, `back`, `interior`, `detail`).

---

## 22. External Services

| Service Name | File Reference | Function / Feature | Purpose | Request / Response | Secret Required? | Client / Server | Current Status |
|:---|:---|:---|:---|:---|:---|:---|:---|
| **Google Drive Thumbnails** | `src/repositories/mock/productMediaRepository.ts:72` | `renderableUrl()` | Product image display | GET to `drive.google.com/thumbnail?id=...` | No | Client | **ACTIVE MOCK** (Unreliable; subject to 429 rate limits) |
| **Razorpay Payments** | `src/routes/checkout.tsx:187`, `.lovable/plan/...` | Payment method selection | Card/UPI payment processing | None (Radio button only) | Yes (Key Secret on Server) | Server (init) + Client (modal) | **STUBBED ONLY** (No SDK or network calls) |
| **Courier Logistics** | `src/routes/product.$productSlug.tsx:145` | Pincode delivery ETA | Delivery SLA estimation | Fake arithmetic check | Yes | Server | **FAKE CALCULATION** (`Number(pincode[5]) % 4`) |
| **WhatsApp Concierge** | `src/config/navigation.ts:70`, `.lovable/plan/...` | MTO consultation handoff | Bespoke garment consultation | None | No | Client | **REFERENCED ONLY** |

---

## 23. Business Logic

1. **Brand Diversification Algorithm (`src/repositories/mock/catalog.ts:189`):**
   - In recommended product sorts, the catalog engine enforces that no more than 2 consecutive styles from the same brand appear in the feed.
2. **Badge Priority Hierarchy (`src/components/commerce/ProductCard.tsx:19`):**
   - Badges evaluate in strict order: `Sold Out` > `Limited` > `New` > `Made to Order` > `Launchpad` > `{discount}% off`.
3. **Pincode Delivery SLA Formula (`src/routes/product.$productSlug.tsx:145`):**
   - If `madeToOrder` is true: 14 days.
   - If regular stock: `4 + (Number(pincode[5]) % 4)` days. (Client-side mock arithmetic).
4. **MRP & Discount Arithmetic (`src/lib/format.ts:8`):**
   - Discount % = `Math.round(((compareAtPrice - price) / compareAtPrice) * 100)`. Only shown if `compareAtPrice > price`.
5. **Shipping Calculation Discrepancies:**
   - Cart (`cart.tsx:33`): Free if subtotal ≥ ₹2,999; otherwise ₹149.
   - Checkout (`checkout.tsx:48`): Free if subtotal ≥ ₹2,999; Standard is ₹99; Express is ₹249.
   - Mock Repository (`mock/index.ts:104`): Free if subtotal ≥ ₹2,999; otherwise ₹99.

---

## 24. Application State

| State Container | File | State Contained | Persistence | Writers | Readers |
|:---|:---|:---|:---|:---|:---|
| `OguraState` | `src/state/store.ts:5` | `cart`, `buyNow`, `wishlist`, `recentlyViewed`, `searchHistory`, `checkoutDraft`, `profile`, `orders`, `hydrated` | LocalStorage backed via `readJSON` / `writeJSON` | Store mutation functions (`addToCart`, `saveOrder`, etc.) | `useOguraState` selector across all screens |
| `UiContext` | `src/state/ui.tsx:3` | `searchOpen`, `cartOpen`, `menuOpen` | Ephemeral (React Memory) | `openSearch`, `closeSearch`, `openCart`, etc. | Header, SearchOverlay, CartDrawer, MobileNav |
| `PlpSearch` (URL State) | `src/components/plp/usePlpQuery.ts:19` | Filters (12 categories), `sort`, `batches`, `minPrice`, `maxPrice`, `q` | URL Query String | `write()`, `toggleFilter()`, `clearAll()` | `PlpEngine.tsx` |
| `SimulatedState` | `src/repositories/mock/latency.ts:1` | `"normal" \| "loading" \| "empty" \| "error"` | Ephemeral (Dev Memory) | `setSimulatedState()` | `simulate()` in repositories |

---

## 25. Mock Implementations

- `mockCatalogRepository`: In-memory multi-facet catalog query.
- `mockCartRepository`: LocalStorage cart array.
- `mockWishlistRepository`: LocalStorage product ID array.
- `mockAccountRepository`: LocalStorage profile and order logs.
- `mockCheckoutRepository`: Client regex validation and mock order assembly.
- `mockReviews`: Procedural review generation via hash of product ID.
- `mockDesigners`: Brands array augmented with `isNew` boolean.
- `mockHomepage`: Hardcoded explore and service cards.
- `mockMerchandising`: Hardcoded PLP editorial inserts.

---

## 26. Artificial Network / Loading Simulation

- **File:** `src/repositories/mock/latency.ts`
- **Functions:** `simulate<T>(key: string, value: () => T): Promise<T>`, `stableDelay(key: string): number`
- **Mechanism:**
  - `stableDelay` generates a deterministic delay between 150ms and 300ms using a hash of the operation key: `(n * 31 + key.charCodeAt(i)) % 151 + 150`.
  - If `simulatedState === "loading"`, it creates an unresolved `new Promise(() => {})`.
  - If `simulatedState === "error"`, it throws `new Error("Simulated repository error")`.
- **Other Delays:**
  - `src/components/plp/PlpEngine.tsx:65`: 180ms `setTimeout` to simulate filter loading spinner.
  - `src/components/layout/SearchOverlay.tsx:40`: 220ms `setTimeout` for search typing debounce.
  - `src/components/commerce/ProductCard.tsx:65`: 2000ms `setTimeout` to reset "Added to bag" button state.

---

## 27. Frontend → Backend Dependency Map

| Frontend Action | File & Function | Data Required | Current Source | Required Backend Capability |
|:---|:---|:---|:---|:---|
| Browse PLP / Filter | `PlpEngine.tsx:58` | Product list, total, facet counts | `listProductsSync` (In-memory) | **Catalog Query & Facet Engine** |
| Open PDP | `product.$productSlug.tsx:29` | Product, variants, images, reviews | In-memory maps & JSON | **Product Detail & SKUs Query** |
| Quick Search | `SearchOverlay.tsx:43` | Matching products & brands | In-memory substring match | **Full-Text / Trigram Autocomplete Search** |
| Check Delivery ETA | `product.$productSlug.tsx:140` | Pincode & SLA estimate | Client math (`pincode[5] % 4`) | **Logistics Partner Pincode Serviceability** |
| Add to Bag | `ProductCard.tsx:60` | Product ID, Variant ID, Quantity | `store.ts` (LocalStorage) | **Server Cart Item Upsert & Stock Check** |
| Update Bag Quantity | `cart.tsx:83` | Line ID, Quantity | `store.ts` (LocalStorage) | **Server Cart Line Quantity Mutation** |
| Remove Line from Bag | `cart.tsx:101` | Line ID | `store.ts` (LocalStorage) | **Server Cart Line Deletion** |
| Toggle Wishlist | `ProductCard.tsx:7` | Product ID | `store.ts` (LocalStorage) | **Customer Wishlist Toggle Mutation** |
| Save Profile | `account.profile.tsx:35`| Name, Email, Phone | `store.ts` (LocalStorage) | **Customer Profile Update Mutation** |
| Initiate Checkout | `checkout.tsx:68` | Draft address, delivery method | `store.ts` (LocalStorage) | **Authoritative Order Calculation & Stock Lock** |
| Place Order | `checkout.tsx:95` | Payment verification proof | `createMockOrder` (LocalStorage)| **Razorpay Verification & Atomic Order Placement** |
| Load Customer Orders | `account.orders.tsx:20` | Customer order list | `store.ts` (LocalStorage) | **Authenticated Customer Orders Query** |
| View Seller Dashboard | `seller.index.tsx:18` | Seller 30d GMV, order count | Hardcoded static values | **Seller Performance Analytics Query** |
| View Admin Orders | `admin.orders.tsx:20` | Platform master orders | Customer LocalStorage | **Platform Admin Orders Query** |

---

## 28. Actual Network / Endpoint Inventory

**FINDING: ZERO (0) LIVE NETWORK CALLS OBSERVED.**
- `fetch`: 0
- `axios`: 0
- `supabase`: 0
- `graphql`: 0
- REST Endpoints: 0

The application in its current state is 100% network-isolated for data operations.

---

## 29. Implied Backend Capabilities

The following capabilities are strictly required by the frontend UI, but have no live backend endpoints:

1. `AUTH_SEND_OTP`: Dispatch 6-digit SMS OTP to customer phone.
2. `AUTH_VERIFY_OTP`: Verify code and issue authenticated JWT session.
3. `CATALOG_GET_PRODUCTS`: Filtered, sorted query with dynamic facet generation.
4. `CATALOG_GET_PRODUCT_BY_SLUG`: Retrieve product, inventory, variants, and gallery.
5. `CATALOG_AUTOCOMPLETE`: Instant search across products, brands, and taxonomy.
6. `LOGISTICS_CHECK_PINCODE`: Check courier serviceability and return true SLA days.
7. `CART_GET`: Retrieve authenticated customer cart with live pricing and stock validation.
8. `CART_ITEM_UPSERT`: Add or update variant in server cart with inventory clamping.
9. `CART_ITEM_REMOVE`: Delete cart item.
10. `CART_MERGE_GUEST`: Merge guest browser cart into user account upon sign-in.
11. `WISHLIST_TOGGLE`: Toggle product in user's persistent wishlist.
12. `WISHLIST_GET`: Fetch wishlisted items.
13. `CHECKOUT_INITIATE`: Validate stock, calculate authoritative shipping/taxes, lock inventory, create Razorpay Order.
14. `CHECKOUT_VERIFY_PAYMENT`: Verify Razorpay signature, confirm order, split sub-orders by seller, deduct stock.
15. `CHECKOUT_WEBHOOK`: Asynchronous Razorpay webhook handler for payment reconciliation.
16. `ORDERS_GET_CUSTOMER`: Fetch order history for authenticated user.
17. `ORDERS_GET_DETAIL`: Fetch single order with sub-orders, line items, and delivery timeline.
18. `ORDERS_PUBLIC_TRACK`: Query tracking details via order number + phone without account login.
19. `ACCOUNT_GET_PROFILE`: Retrieve user profile.
20. `ACCOUNT_UPDATE_PROFILE`: Update customer details.
21. `ACCOUNT_ADDRESSES_CRUD`: Create, read, update, delete delivery addresses.
22. `REVIEWS_GET_FOR_PRODUCT`: Fetch published customer reviews and star distribution.
23. `REVIEWS_SUBMIT`: Submit rating and fit feedback (requires verified purchase check).
24. `SELLER_GET_METRICS`: Aggregate 30-day GMV, units sold, and average rating for authenticated seller.
25. `SELLER_GET_SUB_ORDERS`: List order fulfillment queue for seller's styles.
26. `SELLER_UPDATE_FULFILLMENT`: Transition sub-order status (`packed`, `shipped`) and record courier AWB.
27. `SELLER_GET_PAYOUTS`: Ledger of payout cycles and settlements.
28. `ADMIN_GET_METRICS`: Platform-wide inventory and order aggregates.
29. `ADMIN_GET_CATALOG`: Moderation queue for product approvals.
30. `ADMIN_GET_ORDERS`: Platform-wide master order list.
31. `MTO_SUBMIT_CONSULTATION`: Intake customer measurements and customization requests.

---

## 30. Client-Side Authority Findings

| Finding | File | Function | Current Behavior | Why It Matters | Backend Authority Required |
|:---|:---|:---|:---|:---|:---|
| **AUTH-01: Order ID Generation** | `src/repositories/mock/index.ts:106` | `createMockOrder` | Generates random `DEMO-OG-XXXX` ID on client | Order IDs must be sequential, collision-free, and cryptographically sound | Server database sequence / ULID |
| **AUTH-02: Financial Total Calculation** | `src/routes/checkout.tsx:49` | `CheckoutPage` | Client sums variant prices and shipping fee | Malicious actors can modify totals in browser memory before payment | Server recalculation via database prices |
| **AUTH-03: Shipping Rate Selection** | `src/routes/checkout.tsx:48` | `CheckoutPage` | Client decides if shipping is ₹0, ₹99, or ₹249 | Client can force free shipping on low-value orders | Server-authoritative shipping evaluation |
| **AUTH-04: Order Confirmation** | `src/repositories/mock/index.ts:108` | `createMockOrder` | Sets `status: "placed"` without payment gateway verification | Orders are marked placed without payment capture | Server confirms order only upon HMAC verification |
| **AUTH-05: Inventory Deduction** | `src/repositories/mock/index.ts:83` | `createMockOrder` | Completely omits stock deduction; static inventory never decreases | Multiple buyers can buy same limited piece | Server atomic decrement (`inventory = inventory - qty`) |
| **AUTH-06: Identity Trust** | `src/routes/account.profile.tsx:35` | `ProfilePage` | Setting form state signs user in as authenticated | Anyone can claim to be any customer | Server OTP authentication |
| **AUTH-07: Admin Orders View** | `src/routes/admin.orders.tsx:20` | `AdminOrders` | Admin console reads current browser's customer localStorage | Platform admin cannot see actual marketplace transactions | Server query across master `orders` table |

---

## 31. Security Findings

1. **VULN-01: Unprotected Administrative Surfaces (`/admin/*`)**  
   - Evidence: `src/routes/admin.tsx:4`  
   - Risk: Any anonymous visitor can navigate to `/admin`, `/admin/catalog`, `/admin/orders` and view operational screens. Zero auth checks or role checks exist.
2. **VULN-02: Unprotected Seller Consoles (`/seller/*`)**  
   - Evidence: `src/routes/seller.tsx:4`  
   - Risk: Any visitor can view seller dashboard metrics, payout schedules, and order queues.
3. **VULN-03: Unverified Identity Creation in Local Storage**  
   - Evidence: `src/state/store.ts:182-185`  
   - Risk: Typing an arbitrary phone number into `/account/profile` writes an active session. No SMS verification challenge is executed.
4. **VULN-04: Hotlinking Google Drive Thumbnails**  
   - Evidence: `src/repositories/mock/productMediaRepository.ts:72`  
   - Risk: Images served via `drive.google.com/thumbnail` are fragile, subject to IP rate limits, and risk cascading image failure across the storefront.
5. **VULN-05: Unencrypted Plaintext PII Storage**  
   - Evidence: `src/lib/storage.ts:27-29`  
   - Risk: Customer full names, street addresses, phone numbers, and past order details are stored unencrypted in browser `localStorage`.

---

## 32. Data Ownership

| Entity | Current Source of Truth | Storage Type | User Owned? | Seller Owned? | Admin Controlled? | Expected Backend Authority |
|:---|:---|:---|:---|:---|:---|:---|
| **Products** | `generatedProducts.ts` | Static Mock | No | Yes (by `sellerId`) | Yes (Moderation) | PostgreSQL `products` table |
| **Variants & Stock** | `generatedVariants.ts` | Static Mock | No | Yes (by `productId`) | Yes | PostgreSQL `variants` table |
| **Brands / Designers**| `generatedBrands.ts` | Static Mock | No | Yes | Yes | PostgreSQL `brands` table |
| **Cart** | `localStorage.ogura.cart` | Client Local | Yes | No | No | PostgreSQL `cart_lines` table |
| **Wishlist** | `localStorage.ogura.wishlist` | Client Local | Yes | No | No | PostgreSQL `customer_wishlist` table |
| **Orders** | `localStorage.ogura.orders` | Client Local | Yes (Customer) | Yes (Sub-orders) | Yes (Platform) | PostgreSQL `orders` + `sub_orders` |
| **Addresses** | React State / Draft | Client Local | Yes | No | No | PostgreSQL `addresses` table |
| **Customer Profile** | `localStorage.ogura.session` | Client Local | Yes | No | Yes | Supabase `auth.users` + `profiles` |
| **Reviews** | In-Memory Generator | Procedural Mock | Yes (Author) | No | Yes (Moderation) | PostgreSQL `product_reviews` table |
| **Seller Payouts** | Static Array | Hardcoded Mock | No | Yes (Payee) | Yes (Disburser) | Financial Ledger table |

---

## 33. State / Status Inventory

| Entity | Status Value | File Reference | Where Used | Who Appears to Set It | Notes |
|:---|:---|:---|:---|:---|:---|
| **Product** | `published` | `src/domain/catalog.ts:8`, `seller.products.tsx:44` | Catalog, Seller table | Catalog generator | Locked state in mock data |
| **Variant Availability**| `in_stock` | `src/domain/catalog.ts:1`, `mock/catalog.ts:52` | Variant inventory checks | Static variant list | > 0 inventory |
| **Variant Availability**| `low_stock` | `src/domain/catalog.ts:1`, `mock/catalog.ts:60` | Variant inventory checks | Static variant list | Low inventory indicator |
| **Variant Availability**| `sold_out` | `src/domain/catalog.ts:1`, `mock/catalog.ts:55` | Card badge, PDP selector | Static variant list | 0 inventory |
| **Variant Availability**| `made_to_order`| `src/domain/catalog.ts:1` | Domain types | Static variant list | Lead time dependent |
| **Order** | `placed` | `src/domain/commerce.ts:46`, `mock/index.ts:108` | Order creation | Client `createMockOrder` | Initial state |
| **Order** | `packed` | `src/domain/commerce.ts:46`, `seller.orders.tsx:18` | Seller queue | Seller mock | Packaging complete |
| **Order** | `shipped` | `src/domain/commerce.ts:46`, `seller.orders.tsx:18` | Seller queue | Seller mock | In transit |
| **Order** | `delivered` | `src/domain/commerce.ts:46`, `seller.orders.tsx:18` | Seller queue | Seller mock | Delivery confirmed |
| **Order** | `cancelled` | `src/domain/commerce.ts:46` | Domain interface | Unused in prototype | Terminal state |
| **Seller Payout** | `Paid` | `src/routes/seller.payouts.tsx:18` | Payout history table | Static mock array | Disbursed |
| **Seller Payout** | `Scheduled` | `src/routes/seller.payouts.tsx:20` | Payout history table | Static mock array | Upcoming |
| **Search State** | `idle`, `typing`, `loading`, `ready`, `error` | `src/components/layout/SearchOverlay.tsx:17` | Search modal lifecycle | `SearchOverlay` component | Ephemeral UI state |

---

## 34. Error Handling

- **Route Errors:** Caught by `ErrorComponent` in `src/routes/__root.tsx:51`. Logs to console and invokes `reportLovableError(error)`. Renders user-friendly message with "Try again" and "Go home" buttons.
- **Route Not Found:** Caught by `NotFoundComponent` in `src/routes/__root.tsx:23`. Renders 404 screen with links to Home and Shop.
- **Sub-Route 404s:** PDP (`product.$productSlug.tsx:51`), Brand (`brand.$brandSlug.tsx:28`), and Occasion (`occasion.$occasionSlug.tsx:28`) implement custom `notFoundComponent` rendering `EmptyState`.
- **Form Validation Errors:** `checkout.tsx:81` renders field-level errors (`<p id="...-error" role="alert">`) and sets `aria-invalid="true"`.
- **Toast Notifications:** Failed actions trigger `toast.error()` via `sonner` (e.g. "Select a size to continue" in `product.$productSlug.tsx:115`).
- **Simulated Repository Errors:** If `simulatedState === "error"`, `simulate()` throws an exception, caught by caller `.catch(() => setStatus("error"))`.

---

## 35. Loading / Empty States

- **Skeletons:** `ProductCardSkeleton` in `src/components/commerce/ProductCard.tsx:29` renders pulsed aspect-ratio boxes during loading.
- **Empty States:** The `EmptyState` primitive (`src/components/ui-og/primitives.tsx:49`) is implemented across:
  - Empty Bag: `src/routes/cart.tsx:44`
  - Empty Checkout: `src/routes/checkout.tsx:54`
  - Empty Wishlist: `src/routes/wishlist.tsx:31`
  - Empty Orders: `src/routes/account.orders.tsx:24`
  - Empty Saved Addresses: `src/routes/account.addresses.tsx:54`
  - Search No Results: `src/components/plp/PlpEngine.tsx:189`
- **Pending Buttons:** Checkout button displays `"Placing order…"` and disables click while `placing` is true (`checkout.tsx:243`).

---

## 36. Forms

| Form Name | File | Fields | Client Validation | Submit Action | Target Persistence | Auth Required |
|:---|:---|:---|:---|:---|:---|:---|
| **Checkout Form** | `src/routes/checkout.tsx` | Email, Phone, Full Name, Line 1, Line 2, City, State, Pincode, Delivery Method, Payment Method | Email regex, 10-digit phone regex, 6-digit pincode regex, required text | `next()`, `placeOrder()` | `ogura.checkoutDraft`, `ogura.orders` | None in prototype |
| **Profile Form** | `src/routes/account.profile.tsx` | Name, Email, Phone | Basic text presence | `signIn({...form, signedIn: true})` | `ogura.session` | Mocked |
| **Address Form** | `src/routes/account.addresses.tsx`| Full Name, Phone, Line 1, Line 2, City, State, Pincode | Name, line 1, 6-digit pincode | `setLocal([...local, form])` | React component state | None |
| **Search Input** | `src/components/layout/SearchOverlay.tsx` | Search term (`q`) | Non-empty string | `submit()` -> Navigate `/search?q=...` | `ogura.searchHistory` | None |
| **Newsletter Form** | `src/components/layout/Footer.tsx:55` | Email | None | Local state reset + `toast.success("Thank you for subscribing")` | None (Ephemeral) | None |

---

## 37. File Uploads

**AUDIT RESULT: ZERO (0) UPLOAD IMPLEMENTATIONS PRESENT.**
- `src/config/appMode.ts:5` explicitly states: `uploadsEnabled: false`.
- No `<input type="file">` elements exist in the repository.
- No Supabase Storage upload calls or multipart form handlers exist.
- Made-to-order flow references uploading reference images in documentation, but the UI implements no upload inputs.

---

## 38. Environment / Configuration

- `src/config/appMode.ts`:
  ```typescript
  export const appMode = {
    dataMode: "mock" as const,
    frontendOnly: true,
    paymentsEnabled: false,
    uploadsEnabled: false,
    authEnabled: false,
    showPlaceholderLabels: true,
  } as const;
  ```
- `.env` / Environment Variables: Zero `.env` files present in repository. No `process.env` or `import.meta.env` keys are accessed in source code.
- `vite.config.ts`: Configures `@lovable.dev/vite-tanstack-config`, `@tailwindcss/vite`, and `vite-tsconfig-paths`.
- `components.json`: Standard Shadcn / Tailwind configuration pointing to `src/components/ui`.

---

## 39. Existing Tests

**AUDIT RESULT: ZERO (0) TEST FILES PRESENT.**
- No `*.test.ts`, `*.test.tsx`, `*.spec.ts`, or `*.spec.tsx` files exist.
- No Vitest, Jest, Cypress, or Playwright configurations exist in `package.json`.
- All commerce flows (cart, checkout, filtering) are currently untested by automated test suites.

---

## 40. Dead / Suspicious Code

1. **Unused Storage Keys:** `KEYS.addresses` and `KEYS.reviews` in `src/lib/storage.ts:30-31` are declared but never read or written anywhere in the repository.
2. **Unused Root Server / Start Files:** `src/start.ts` and `src/server.ts` export default Nitro handlers, but Vite runs purely in development client mode (`vite dev`).
3. **Dead Repository Method References:** `accountRepository.getOrder` is defined in `src/repositories/mock/index.ts:60`, but routes access `state.orders` directly from `useOguraState`.
4. **Unreachable Made-to-Order Request Flow:** Merchandising inserts point to `/made-to-order/request`, but no corresponding route file exists in `src/routes/`.

---

## 41. Missing / Broken References

1. **Broken Route Link:** `src/data/mockMerchandising.ts:37` links to `/made-to-order/request` and line 43 links to `/made-to-order/request?intent=footwear`. Neither route exists in `src/routes/`. Clicking these links throws an application 404 error.
2. **Missing Multi-Seller Cart Grouping:** The prototype brief (`.lovable/plan/ogura-frontend-only-prototype-2026-09-08.md:22`) specifies: *"cart page grouped by seller"*. In `src/routes/cart.tsx`, cart lines are rendered in a flat list without seller grouping.
3. **Missing Interactive Tracking:** Navigation links to `/track-order`, but the page contains no input field or button to look up a tracking number.
4. **Missing Review Submission:** PDP displays reviews, but provides no interactive UI to submit a review.

---

## 42. Frontend Contradictions

| Conflict ID | File A | File B | Behavior in File A | Behavior in File B | Notes |
|:---|:---|:---|:---|:---|:---|
| **CONTRA-01: Shipping Fee Below ₹2,999** | `src/routes/cart.tsx:33` | `src/routes/checkout.tsx:48` | Calculates shipping as **₹149** | Calculates standard shipping as **₹99** | Inconsistent threshold fee creates customer confusion |
| **CONTRA-02: Mock Repo Shipping Fee** | `src/repositories/mock/index.ts:104` | `src/routes/cart.tsx:33` | Sets order shipping as **₹99** | Summarizes shipping as **₹149** | Placed order total differs from bag page summary |
| **CONTRA-03: Order Scope in Admin** | `src/routes/admin.orders.tsx:20` | `src/routes/account.orders.tsx:20` | Reads `localStorage.ogura.orders` | Reads `localStorage.ogura.orders` | Admin console shares identical storage with customer browser |
| **CONTRA-04: Seller Orders Source** | `src/routes/seller.orders.tsx:21` | `src/routes/checkout.tsx:95` | Generates orders from product slice 30–42 | Generates orders with ID `DEMO-OG-XXXX` | Orders placed in checkout never appear in seller queue |

---

## 43. Feature Matrix

| Feature | Primary Actor | Primary Route | Key Components | Repository / Store | Data Source | Persistence | Auth Required? | Mocked? | Security Sensitivity |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| **Catalog Discovery** | Public / Buyer | `/shop`, `/new-in`, `/women/*` | `PlpEngine`, `FilterPanel` | `catalogRepository` | `generatedProducts` | URL Query Params | No | Yes | Low |
| **Product Detail** | Public / Buyer | `/product/$productSlug` | PDP Gallery, Variant Selector | `catalogRepository`, `productMedia`| Generated data | None | No | Yes | Low |
| **Instant Search** | Public / Buyer | Modal / `/search` | `SearchOverlay`, `PlpEngine` | `catalogRepository` | Generated data | `ogura.searchHistory` | No | Yes | Low |
| **Shopping Bag** | Public / Buyer | Drawer / `/cart` | `CartDrawer`, `CartPage` | `cartRepository` | `ogura.cart` | `ogura.cart` | No | Yes | High |
| **Checkout** | Customer | `/checkout` | `CheckoutPage` | `checkoutRepository` | `ogura.checkoutDraft`| `ogura.orders` | No (Mock) | Yes | **CRITICAL** |
| **Order Confirmation** | Customer | `/order/success/$orderId`| `OrderSuccess` | Store | `ogura.orders` | `ogura.orders` | No | Yes | High |
| **Wishlist** | Customer | `/wishlist` | `WishlistPage`, `ProductCard` | `wishlistRepository` | `ogura.wishlist` | `ogura.wishlist` | No | Yes | Low |
| **Buyer Profile** | Customer | `/account/profile` | `ProfilePage` | `accountRepository` | `ogura.session` | `ogura.session` | Mocked | Yes | **CRITICAL** |
| **Seller Dashboard** | Seller | `/seller` | `SellerDashboard` | None | Hardcoded array | None | No (Missing) | Yes | **CRITICAL** |
| **Seller Queue** | Seller | `/seller/orders` | `SellerOrders` | None | Product slice | None | No (Missing) | Yes | **CRITICAL** |
| **Admin Catalog** | Admin | `/admin/catalog` | `AdminCatalog` | None | Product slice | None | No (Missing) | Yes | **CRITICAL** |
| **Admin Orders** | Admin | `/admin/orders` | `AdminOrders` | Store | `ogura.orders` | `ogura.orders` | No (Missing) | Yes | **CRITICAL** |

---

## 44. Backend Dependency Matrix

| Frontend Feature | Required Backend Capability | Entities Involved | Auth Level | Authorization Rule | Target Persistence | External Provider |
|:---|:---|:---|:---|:---|:---|:---|
| **PLP Filtering** | Catalog search & facet aggregation | `products`, `variants`, `brands` | Public / Anon | Status = `published` | PostgreSQL View / Gin Index | None |
| **PDP Presentation**| Product entity by slug + SKUs | `products`, `variants`, `media` | Public / Anon | Status = `published` | PostgreSQL Table | CDN Media Storage |
| **Pincode Delivery**| Pincode serviceability check | `pincode_zones` | Public / Anon | Public Read | PostgreSQL Table | Courier Partner API |
| **Bag Management** | Server cart line upsert/delete | `cart_lines`, `variants` | Customer | `user_id = auth.uid()` | PostgreSQL Table | None |
| **Order Initiation**| Authoritative price & stock check | `orders`, `variants`, `addresses` | Customer | `user_id = auth.uid()` | PostgreSQL Row Lock | Razorpay Orders API |
| **Payment Confirm**| Signature check & atomic split | `orders`, `sub_orders`, `ledger` | Customer / Webhook | Signature HMAC Match | PostgreSQL Transaction | Razorpay Payment API |
| **Order History** | List past customer purchases | `orders`, `order_items` | Customer | `customer_id = auth.uid()`| PostgreSQL Table | None |
| **Fulfillment** | Seller sub-order status transition | `sub_orders` | Seller | `seller_id = auth.seller_id()`| PostgreSQL RPC | Delhivery / Shiprocket |
| **Platform Admin** | Master orders and catalog approval | `orders`, `products` | Admin | Role = `platform_admin` | PostgreSQL Tables | None |

---

## 45. Critical Findings

### P0 (Critical for Backend Readiness, Commerce Correctness & Security)
- **P0-1:** Client-Authoritative Financial Math. Order subtotals, shipping charges, and order numbers are computed and generated in the browser (`src/routes/checkout.tsx:48`, `src/repositories/mock/index.ts:106`).
- **P0-2:** Zero Authentication Security. Profile edit marks any user as authenticated without an OTP challenge (`src/state/store.ts:182`).
- **P0-3:** Unprotected Seller & Admin Surfaces. Any user can access `/seller` and `/admin` routes with zero authorization checks (`src/routes/seller.tsx`, `src/routes/admin.tsx`).
- **P0-4:** Client-Side Order Creation & Mock Confirmation. Orders are marked `status: 'placed'` without payment gateway integration or signature verification.
- **P0-5:** No Concurrency / Inventory Reservation. Concurrent checkouts for the last available SKU will create overselling because stock is not locked.

### P1 (Important for Backend Integration)
- **P1-1:** Shipping Fee Conflict. Cart page charges ₹149 while checkout charges ₹99 / ₹249 for orders under ₹2,999.
- **P1-2:** Fragile Media Infrastructure. Garment images hotlink Google Drive thumbnail endpoints (`drive.google.com/thumbnail`), risking 429 rate limiting and image failure.
- **P1-3:** Admin Orders Querying Client Storage. `/admin/orders` reads from `localStorage.ogura.orders`, showing only what the local user placed.
- **P1-4:** Broken MTO Link. Banner CTAs navigate to non-existent route `/made-to-order/request`, causing 404s.

### P2 (Non-Blocking Engineering Issues)
- **P2-1:** Zero Automated Test Coverage. Repository has no test framework or test files installed.
- **P2-2:** Flat Cart Presentation. Cart does not group items by seller as outlined in the prototype brief.
- **P2-3:** Static Order Tracking Page. `/track-order` lacks an interactive input form for order number lookup.

### P3 (Informational)
- **P3-1:** Dead storage keys `ogura.addresses` and `ogura.reviews` defined in `src/lib/storage.ts`.
- **P3-2:** Fake pincode SLA calculation based on sixth digit of pincode string.

---

## 46. Backend Readiness Scorecard

| Domain | Current State | Mocked? | Backend Dependency | Client Authority? | Security Risk? | Readiness |
|:---|:---|:---|:---|:---|:---|:---|
| **Catalog** | Complete in-memory catalog (311 items) | Yes | High | No | Low | **PARTIALLY READY** |
| **Search** | Working autocomplete & query engine | Yes | Medium | No | Low | **PARTIALLY READY** |
| **Product (PDP)** | Rich multi-angle gallery, variant picker | Yes | High | No | Low | **PARTIALLY READY** |
| **Cart** | Client-side array in localStorage | Yes | High | **YES** | High | **NOT READY** |
| **Checkout** | 5-step mock flow with client totals | Yes | **CRITICAL** | **YES** | **CRITICAL** | **NOT READY** |
| **Authentication** | Mock session in localStorage | Yes | **CRITICAL** | **YES** | **CRITICAL** | **NOT READY** |
| **Buyer Account** | Overview, profile, orders, addresses | Yes | High | **YES** | High | **NOT READY** |
| **Orders** | Stored in client localStorage | Yes | **CRITICAL** | **YES** | **CRITICAL** | **NOT READY** |
| **Wishlist** | Client array in localStorage | Yes | Medium | No | Low | **PARTIALLY READY** |
| **Reviews** | Procedural generator | Yes | Medium | No | Low | **PARTIALLY READY** |
| **Seller** | Hardcoded dashboard & static slices | Yes | High | **YES** | **CRITICAL** | **NOT READY** |
| **Admin** | Unprotected shell reading local orders | Yes | High | **YES** | **CRITICAL** | **NOT READY** |
| **Media** | Google Drive thumbnail proxy | Yes | High | No | Medium | **NOT READY** |
| **Payments** | Mock radio button | Yes | **CRITICAL** | **YES** | **CRITICAL** | **NOT READY** |
| **Shipping** | Conflicting client rules | Yes | High | **YES** | High | **NOT READY** |
| **Inventory** | Static un-decremented numbers | Yes | **CRITICAL** | **YES** | High | **NOT READY** |
| **Authorization** | Missing route guards | Yes | **CRITICAL** | **YES** | **CRITICAL** | **NOT READY** |
| **Error Handling** | Route boundaries & empty states | No | Low | No | Low | **READY** |
| **Testing** | Zero automated tests | N/A | High | N/A | Medium | **NOT READY** |

---

## 47. Extraction Summary

TOTAL ROUTES: 47  
TOTAL IMPORTANT COMPONENTS: 11  
TOTAL REPOSITORIES: 6  
TOTAL REPOSITORY METHODS: 23  
TOTAL DATA SOURCES: 10  
TOTAL LOCAL STORAGE KEYS: 8 (plus 2 dead keys)  
TOTAL ACTUAL NETWORK CALLS: 0  
TOTAL IMPLIED BACKEND CAPABILITIES: 31  
TOTAL CLIENT-AUTHORITY FINDINGS: 7  
TOTAL SECURITY FINDINGS: 5  
TOTAL FRONTEND CONTRADICTIONS: 4  
TOTAL BROKEN/MISSING REFERENCES: 4  
TOTAL MOCK SYSTEMS: 9  

P0 COUNT: 5  
P1 COUNT: 4  
P2 COUNT: 3  
P3 COUNT: 2  

UI/UX CHANGES MADE: 0  
TAXONOMY CHANGES MADE: 0  
SOURCE CODE FILES MODIFIED: 0  

---
---

# PART II: FINAL FRONTEND RE-VALIDATION & BACKEND CONTRACT SPECIFICATION

## 48. Re-Validation of Previous Frontend Fixes

Three critical frontend fixes were audited directly against the workspace source code:

| Fix Item | Component / File | Verification Criteria | Observed Code Evidence | Result |
|---|---|---|---|---|
| **A. Cart State Immutability & Quantity Clamping** | `src/state/store.ts:88-112` | 1. State lines array and object updated immutably.<br>2. Quantities clamped between 1 and 10.<br>3. Non-integer inputs sanitized. | `const safeQty = Math.max(1, Math.min(10, Math.floor(quantity) || 1));`<br>`lines = state.cart.lines.map(l => l.variantId === variantId ? { ...l, quantity: Math.min(10, l.quantity + safeQty) } : l);`<br>No in-place object mutation detected. | **PASS** |
| **B. Profile Form Hydration Sync** | `src/routes/account.profile.tsx:20-27` | 1. Local state synchronizes when external store finishes hydration from localStorage.<br>2. Profile fields do not stay blank after reload. | `useEffect(() => { setForm({ name: profile.name, email: profile.email, phone: profile.phone }); }, [profile.name, profile.email, profile.phone]);`<br>Synchronizes cleanly on hydration. | **PASS** |
| **C. Saved Address Draft Rendering** | `src/routes/account.addresses.tsx:31-35` | 1. Blank or unpopulated checkout drafts do not appear as saved address cards.<br>2. Mandatory fields verified. | `const hasDraftAddress = Boolean(draftAddress?.fullName?.trim() && draftAddress?.line1?.trim());`<br>`const list = hasDraftAddress && draftAddress ? [draftAddress] : [];`<br>Empty drafts are strictly filtered out. | **PASS** |

---

## 49. Comprehensive Issue Register & Classification

Targeted forensic scan of all remaining frontend issues and architectural assumptions:

| ID | Issue Description | Source Location | Classification | Current Impact & Backend Repercussions |
|---|---|---|---|---|
| **ISSUE-01** | Conflicting shipping rates between Cart (₹149), Checkout (₹99/₹249), and Mock Repo (₹99) | `src/routes/cart.tsx:33`<br>`src/routes/checkout.tsx:48`<br>`src/repositories/mock/index.ts:104` | **PRODUCT DECISION REQUIRED** | Client displays conflicting quotes; backend must establish canonical shipping tariff engine. |
| **ISSUE-02** | Merchandising inserts and PDP link to nonexistent `/made-to-order/request` | `src/data/mockMerchandising.ts:37, 43`<br>`src/routes/product.$productSlug.tsx:389` | **PRODUCT DECISION REQUIRED** / **UI/UX DECISION REQUIRED** | Clicking CTA routes to 404. Requires architect decision on form vs PLP vs concierge destination. |
| **ISSUE-03** | Cart presentation is flat list; prototype plan notes grouping by seller | `src/routes/cart.tsx:58-110`<br>`.lovable/plan/...:22` | **UI/UX DECISION REQUIRED** | Frontend displays flat cart. Backend multi-seller split orders require sub-order tracking regardless of UI grouping. |
| **ISSUE-04** | Client calculates subtotal, discounts, shipping, and grand total | `src/routes/checkout.tsx:44-55`<br>`src/routes/cart.tsx:28-35` | **BACKEND DEPENDENCY** | Client authority over currency math is completely unverified; backend must calculate all checkout quotes. |
| **ISSUE-05** | Orders created client-side with random `DEMO-OG-XXXX` ID and local status | `src/repositories/mock/index.ts:106`<br>`src/routes/checkout.tsx:95` | **BACKEND DEPENDENCY** | Order authority resides in client state; backend PostgreSQL must own sequence numbers and state transitions. |
| **ISSUE-06** | Authentication is purely simulated via `localStorage.ogura.session` | `src/state/store.ts:182`<br>`src/routes/account.profile.tsx:35` | **BACKEND DEPENDENCY** | Zero cryptographic security or identity proof; backend must implement OTP/JWT auth service. |
| **ISSUE-07** | Seller and Admin route protection relies solely on client state check | `src/routes/seller.tsx:11`<br>`src/routes/admin.tsx:11` | **BACKEND DEPENDENCY** | Any client can load admin/seller shells; backend must enforce server-side RBAC and Postgres RLS. |
| **ISSUE-08** | Inventory availability derived from static modulo calculations in memory | `src/routes/product.$productSlug.tsx:92`<br>`src/components/commerce/ProductCard.tsx:47` | **BACKEND DEPENDENCY** | No concurrent reservation or atomic decrement; backend must maintain real inventory ledger with lock holds. |
| **ISSUE-09** | Product media repository coupled to external Google Drive URLs | `src/repositories/mock/productMediaRepository.ts:1-74`<br>`src/data/generated/productMedia.ts` | **BACKEND DEPENDENCY** | URLs point to temporary Google Drive exports; backend must host originals on owned S3/Cloudflare R2 storage + CDN. |
| **ISSUE-10** | Unused declared localStorage keys `KEYS.addresses` and `KEYS.reviews` | `src/lib/storage.ts:30-31` | **TECHNICAL DEBT** | Keys declared in storage registry but unused across code. Harmless non-blocking debt. |
| **ISSUE-11** | Customer reviews procedurally generated in client memory | `src/data/mockReviews.ts:37`<br>`src/routes/product.$productSlug.tsx:100` | **BACKEND DEPENDENCY** | Reviews do not persist and have no buyer verification; backend must own review submissions and ratings. |
| **ISSUE-12** | Pincode delivery estimate is synthetic text without carrier API | `src/routes/product.$productSlug.tsx:405` | **BACKEND DEPENDENCY** | Pincode input checks 6 digits locally; backend must integrate courier serviceability API (e.g. Shiprocket/Delhivery). |
| **ISSUE-13** | Customer order cancellation and returns flow missing from frontend | `src/routes/account.orders.tsx`<br>`src/routes/returns.tsx` | **PRODUCT DECISION REQUIRED** / **BACKEND DEPENDENCY** | Returns page is static policy text; no interactive return request flow exists in customer order history. |
| **ISSUE-14** | Seller order fulfillment lacks tracking number / AWB entry | `src/routes/seller.orders.tsx:38` | **BACKEND DEPENDENCY** | Seller order actions are static displays; backend must provide shipment label generation and AWB entry RPC. |
| **ISSUE-15** | Seller payouts are hardcoded read-only metrics | `src/routes/seller.payouts.tsx:15-45` | **BACKEND DEPENDENCY** | Payout records are mock constants; backend must manage seller commission accounting, escrow, and payouts. |

---

## 50. Backend Endpoint Inventory (BE-001 through BE-036)

This is the complete, canonical backend contract inventory extracted from the OGURA frontend application.

---

### BE-001 — List Products with Filtering, Facets & Sorting (PLP Engine)
- **Frontend location:** `src/components/plp/PlpEngine.tsx:75-102`, `src/repositories/mock/index.ts:14-16`
- **Frontend trigger:** Navigating to `/shop`, `/new-in`, `/women/$categorySlug`, `/women/$categorySlug/$subcategorySlug`, `/occasions/$occasionSlug`, `/collections/$collectionSlug`, `/brand/$brandSlug`, `/designer/$designerSlug`, `/made-to-order`.
- **Current implementation:** Mock repository `mockCatalogRepository.listProducts(query)` running in-memory array filters with 150–300ms simulated latency.
- **Operation:** `GET` / `RPC`
- **Entity:** `Product`, `ProductVariant`, `Brand`, `Designer`, `Category`
- **Input:**
  ```json
  {
    "category": "clothing",
    "subcategory": "dresses-and-jumpsuits",
    "brand": "studio-amala",
    "designer": "ananya-verma",
    "occasion": "evening-cocktail",
    "collection": "under-3000",
    "priceRange": [1500, 5000],
    "colors": ["Ivory", "Crimson"],
    "sizes": ["S", "M"],
    "inStockOnly": true,
    "madeToOrder": false,
    "query": "silk",
    "sort": "price-asc",
    "batch": 1,
    "pageSize": 24
  }
  ```
- **Output:**
  ```json
  {
    "products": [
      {
        "id": "prod_01",
        "slug": "ivory-raw-silk-kurta",
        "title": "Ivory Raw Silk Kurta",
        "brandName": "Studio Amala",
        "brandSlug": "studio-amala",
        "category": "ethnicwear",
        "subcategory": "kurtas",
        "price": 2499,
        "compareAtPrice": 3299,
        "primaryImage": "https://cdn.ogura.in/images/prod_01_1.webp",
        "secondaryImage": "https://cdn.ogura.in/images/prod_01_2.webp",
        "inStock": true,
        "isLowStock": false,
        "madeToOrder": false,
        "rating": 4.8,
        "reviewCount": 12
      }
    ],
    "total": 311,
    "batch": 1,
    "pageSize": 24,
    "facets": {
      "brands": [{ "slug": "studio-amala", "name": "Studio Amala", "count": 28 }],
      "categories": [{ "slug": "clothing", "count": 140 }],
      "sizes": ["XS", "S", "M", "L", "XL"],
      "colors": ["Black", "Ivory", "Wine", "Indigo"],
      "priceBounds": { "min": 1111, "max": 15000 }
    }
  }
  ```
- **Frontend authority:** Frontend determines batch size (24) and active query parameters in URL.
- **Backend authority required:** PostgreSQL must execute indexed queries, compute aggregation facets, enforce active/published status, and return paginated slices.
- **Authentication required:** NO
- **Authorization required:** `PUBLIC`
- **Ownership:** Platform Public Catalog
- **State transition:** N/A
- **Validation:** Validate query types, price ranges (min >= 0, max >= min), sanitize search string, limit page size (max 48).
- **Financial impact:** LOW (Display only)
- **Concurrency concern:** NONE
- **External provider:** None (PostgreSQL / Elasticsearch / Typesense)
- **Dependencies:** `Product`, `ProductVariant`, `Brand`
- **Open question:** Facet count caching strategy under high traffic.

---

### BE-002 — Get Product Detail by Slug (PDP)
- **Frontend location:** `src/routes/product.$productSlug.tsx:48-60`, `src/repositories/mock/index.ts:18-20`
- **Frontend trigger:** Navigating to `/product/$productSlug`.
- **Current implementation:** `mockCatalogRepository.getProductBySlug(slug)` finding item in static 311-product array.
- **Operation:** `GET`
- **Entity:** `Product`, `ProductVariant`, `Brand`, `Designer`, `ProductMedia`
- **Input:** `{ "slug": "silk-organza-saree" }`
- **Output:**
  ```json
  {
    "product": {
      "id": "prod_01",
      "slug": "silk-organza-saree",
      "title": "Silk Organza Saree",
      "description": "Handcrafted pure silk organza...",
      "brandId": "brand_01",
      "brandName": "Label Raas",
      "brandSlug": "label-raas",
      "designerId": "des_01",
      "designerName": "Mira Rajput",
      "designerSlug": "mira-rajput",
      "category": "ethnicwear",
      "subcategory": "sarees",
      "price": 4999,
      "compareAtPrice": 6500,
      "composition": "100% Silk Organza",
      "careInstructions": "Dry clean only",
      "origin": "Varanasi, India",
      "madeToOrder": false,
      "customizable": true,
      "rating": 4.9,
      "reviewCount": 8
    },
    "variants": [
      { "id": "var_01", "sku": "RAAS-SO-IVR-FREE", "size": "Free Size", "color": "Ivory", "price": 4999, "inStock": true, "inventoryQuantity": 4 }
    ],
    "media": [
      { "imageId": "img_01", "url": "https://cdn.ogura.in/media/01.webp", "role": "PRIMARY", "isPrimary": true }
    ],
    "designer": { "id": "des_01", "name": "Mira Rajput", "story": "Studio in Jaipur..." }
  }
  ```
- **Frontend authority:** Frontend selects active size and color in React state.
- **Backend authority required:** Server validates product active state, loads all valid SKUs/variants, and provides authoritative price points.
- **Authentication required:** NO
- **Authorization required:** `PUBLIC`
- **Ownership:** Public Catalog / Seller
- **State transition:** N/A
- **Validation:** Slug must exist and product must have `status = 'published'`.
- **Financial impact:** LOW (Display only)
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `Product`, `ProductVariant`, `ProductMedia`
- **Open question:** Should unlisted draft products be viewable with a seller preview token?

---

### BE-003 — Full-Text Catalog Autocomplete & Quick Search
- **Frontend location:** `src/components/layout/SearchOverlay.tsx:42-55`, `src/repositories/mock/index.ts:22-24`
- **Frontend trigger:** User types >= 2 characters in header search bar.
- **Current implementation:** In-memory regex match on title, brand, category, subcategory.
- **Operation:** `GET`
- **Entity:** `Product`, `Brand`, `Designer`
- **Input:** `{ "query": "chikankari", "limit": 6 }`
- **Output:**
  ```json
  {
    "products": [{ "id": "prod_12", "title": "Chikankari Anarkali", "slug": "chikankari-anarkali", "price": 3899, "thumbnail": "https://cdn.ogura.in/..." }],
    "brands": [{ "slug": "lucknowi-ateliers", "name": "Lucknowi Ateliers" }],
    "designers": [{ "slug": "shabana-azmi", "name": "Shabana Azmi" }]
  }
  ```
- **Frontend authority:** Frontend manages input debounce and search history in `localStorage.ogura.searchHistory`.
- **Backend authority required:** Sub-50ms database search index matching product titles, brand names, and tags.
- **Authentication required:** NO
- **Authorization required:** `PUBLIC`
- **Ownership:** Public Catalog
- **State transition:** N/A
- **Validation:** Query length sanitized, stripped of SQL injection characters.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** None (pg_trgm / Meilisearch / Elasticsearch)
- **Dependencies:** Catalog indexes
- **Open question:** None.

---

### BE-004 — List Brands & Get Brand Details
- **Frontend location:** `src/routes/brands.tsx:35`, `src/routes/brand.$brandSlug.tsx:28`, `src/data/mockBrands.ts`
- **Frontend trigger:** User opens `/brands` index or clicks brand badge on card/PDP.
- **Current implementation:** Static JSON array `mockBrands`.
- **Operation:** `GET`
- **Entity:** `Brand`
- **Input:** `{ "slug"?: "studio-amala" }`
- **Output:**
  ```json
  {
    "id": "brand_01",
    "slug": "studio-amala",
    "name": "Studio Amala",
    "city": "Jaipur",
    "state": "Rajasthan",
    "story": "Contemporary craft studio exploring block print...",
    "logoUrl": "https://cdn.ogura.in/brands/amala.webp",
    "styleCount": 28
  }
  ```
- **Frontend authority:** None.
- **Backend authority required:** Brand metadata persistence in PostgreSQL.
- **Authentication required:** NO
- **Authorization required:** `PUBLIC`
- **Ownership:** Brand / Platform
- **State transition:** N/A
- **Validation:** Slug format validation.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `Brand`
- **Open question:** None.

---

### BE-005 — List Designers & Get Designer Details
- **Frontend location:** `src/routes/designers.tsx:35`, `src/routes/designer.$designerSlug.tsx:28`, `src/data/mockDesigners.ts`
- **Frontend trigger:** Navigating to `/designers` or `/designer/$designerSlug`.
- **Current implementation:** Static JSON array `mockDesigners`.
- **Operation:** `GET`
- **Entity:** `Designer`, `Brand`
- **Input:** `{ "slug"?: "ananya-verma" }`
- **Output:** Designer bio, studio location, philosophy, associated brand IDs, product style count.
- **Frontend authority:** None.
- **Backend authority required:** Designer table in PostgreSQL.
- **Authentication required:** NO
- **Authorization required:** `PUBLIC`
- **Ownership:** Designer Profile
- **State transition:** N/A
- **Validation:** Slug validation.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `Designer`
- **Open question:** None.

---

### BE-006 — List Collections & Curations
- **Frontend location:** `src/routes/collections.index.tsx:28`, `src/routes/collections.$collectionSlug.tsx:26`, `src/data/mockCollections.ts`
- **Frontend trigger:** Navigating to `/collections` or price/editorial curations (e.g. `/collections/under-2000`).
- **Current implementation:** Static `mockCollections` array with criteria predicates.
- **Operation:** `GET`
- **Entity:** `Collection`, `CollectionRule`
- **Input:** `{ "slug"?: "under-3000" }`
- **Output:** Collection metadata, title, banner image, criteria rules (e.g. price <= 2999).
- **Frontend authority:** None.
- **Backend authority required:** Dynamic rule evaluation or manual curation table.
- **Authentication required:** NO
- **Authorization required:** `PUBLIC`
- **Ownership:** Merchandising Admin
- **State transition:** N/A
- **Validation:** Slug validation.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `Collection`
- **Open question:** Automated vs manual curation lists.

---

### BE-007 — List Occasions & Occasion Curations
- **Frontend location:** `src/routes/occasions.tsx:25`, `src/routes/occasion.$occasionSlug.tsx:28`, `src/data/mockOccasions.ts`
- **Frontend trigger:** Navigating to `/occasions` or `/occasion/$occasionSlug`.
- **Current implementation:** Static `mockOccasions` array.
- **Operation:** `GET`
- **Entity:** `Occasion`
- **Input:** `{ "slug"?: "festive" }`
- **Output:** Occasion metadata, title, aesthetic guide, matching tag keywords.
- **Frontend authority:** None.
- **Backend authority required:** PostgreSQL occasion registry.
- **Authentication required:** NO
- **Authorization required:** `PUBLIC`
- **Ownership:** Merchandising Admin
- **State transition:** N/A
- **Validation:** Slug validation.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `Occasion`
- **Open question:** None.

---

### BE-008 — Merchandising Banners & Editorial Inserts
- **Frontend location:** `src/data/mockMerchandising.ts:1-110`, `src/components/plp/PlpEngine.tsx:142-160`
- **Frontend trigger:** PLP rendering editorial cards after product index 12 and 36.
- **Current implementation:** Static mapping by category in `src/data/mockMerchandising.ts`.
- **Operation:** `GET`
- **Entity:** `MerchandisingInsert`
- **Input:** `{ "categorySlug": "ethnicwear" }`
- **Output:**
  ```json
  {
    "banner": "A New Language of Festive",
    "chips": ["sarees", "lehengas", "sets"],
    "insert12": { "eyebrow": "Craft", "title": "Detail, up close", "description": "...", "ctaText": "See festive edit", "ctaHref": "/occasion/festive" },
    "insert36": { "eyebrow": "Service", "title": "Made to Order", "description": "...", "ctaText": "Start a request", "ctaHref": "/made-to-order/request" }
  }
  ```
- **Frontend authority:** Frontend inserts card into grid without consuming a product slot.
- **Backend authority required:** CMS / Merchandising slot engine returning active campaign content.
- **Authentication required:** NO
- **Authorization required:** `PUBLIC`
- **Ownership:** Merchandising Admin
- **State transition:** N/A
- **Validation:** Valid category slug.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** Merchandising tables
- **Open question:** Resolving dead MTO links (`/made-to-order/request`) via CMS control.

---

### BE-009 — Customer Sign In / OTP Request & Verification
- **Frontend location:** `src/routes/account.profile.tsx:34-40`, `src/state/store.ts:182-185`
- **Frontend trigger:** Customer enters phone/email and clicks "Save details" / Sign In.
- **Current implementation:** Client calls `signIn({ name, email, phone, signedIn: true })` writing directly to `localStorage.ogura.session`.
- **Operation:** `RPC` / `ACTION`
- **Entity:** `User`, `CustomerProfile`, `AuthSession`
- **Input:** `{ "phone": "+919876543210", "otp"?: "123456" }`
- **Output:**
  ```json
  {
    "user": { "id": "usr_99", "phone": "+919876543210", "createdAt": "2026-09-14T00:00:00Z" },
    "profile": { "name": "Aarav Sharma", "email": "aarav@example.com", "phone": "+919876543210" },
    "sessionToken": "jwt_token_here",
    "expiresAt": "2026-10-14T00:00:00Z"
  }
  ```
- **Frontend authority:** Frontend currently manufactures authenticated state from unverified text input.
- **Backend authority required:** Server MUST generate OTP, dispatch via SMS gateway, verify OTP against rate limit, create/update User record, and issue cryptographically signed JWT/httpOnly cookie.
- **Authentication required:** NO (Entry point)
- **Authorization required:** `PUBLIC`
- **Ownership:** Customer Identity
- **State transition:** `UNAUTHENTICATED → AUTHENTICATED`
- **Validation:** Valid 10-digit Indian phone number (`/^[6-9]\d{9}$/`), 6-digit numeric OTP, rate limit 3 attempts per 5 minutes.
- **Financial impact:** LOW (SMS cost)
- **Concurrency concern:** NONE
- **External provider:** SMS / WhatsApp OTP Provider (e.g. Twilio / Gupshup / Fast2SMS)
- **Dependencies:** User auth tables
- **Open question:** Email OTP fallback vs SMS only.

---

### BE-010 — Customer Sign Out / Invalidate Session
- **Frontend location:** `src/routes/account.profile.tsx:45-51`, `src/state/store.ts:187-190`
- **Frontend trigger:** Customer clicks "Sign out" on profile page.
- **Current implementation:** Overwrites `KEYS.session` in localStorage with `GUEST` object.
- **Operation:** `ACTION` / `RPC`
- **Entity:** `AuthSession`
- **Input:** None (Session identified by Bearer token or httpOnly cookie)
- **Output:** `{ "success": true }`
- **Frontend authority:** Clears local state and localStorage.
- **Backend authority required:** Revoke session token and refresh token in database session store.
- **Authentication required:** YES
- **Authorization required:** `CUSTOMER`
- **Ownership:** Current User
- **State transition:** `AUTHENTICATED → TERMINATED`
- **Validation:** Valid session token.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** Session store
- **Open question:** None.

---

### BE-011 — Get / Update Customer Profile
- **Frontend location:** `src/routes/account.profile.tsx:21-40`, `src/routes/account.index.tsx:21`
- **Frontend trigger:** Loading account dashboard or editing name/email.
- **Current implementation:** Reads and writes `localStorage.ogura.session`.
- **Operation:** `GET` / `UPDATE`
- **Entity:** `CustomerProfile`
- **Input:** `{ "name": "Aarav Sharma", "email": "aarav@example.com" }`
- **Output:** Authoritative profile record.
- **Frontend authority:** Client currently controls identity fields.
- **Backend authority required:** Validate email format, enforce phone uniqueness, update PostgreSQL profile table.
- **Authentication required:** YES
- **Authorization required:** `CUSTOMER` (Own account only via `auth.uid() = user_id`)
- **Ownership:** Current User
- **State transition:** N/A
- **Validation:** Valid email regex, name length 1–100 characters.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `CustomerProfile`
- **Open question:** None.

---

### BE-012 — List, Add & Delete Customer Saved Addresses
- **Frontend location:** `src/routes/account.addresses.tsx:31-75`
- **Frontend trigger:** Customer navigates to `/account/addresses` or adds delivery address.
- **Current implementation:** Local React state array merged with `checkoutDraft?.address`.
- **Operation:** `GET` / `CREATE` / `DELETE`
- **Entity:** `CustomerAddress`
- **Input:**
  ```json
  {
    "fullName": "Priya Sen",
    "phone": "9876543210",
    "line1": "Flat 402, Lotus Towers",
    "line2": "Indiranagar",
    "city": "Bengaluru",
    "state": "Karnataka",
    "pincode": "560038",
    "isDefault": true
  }
  ```
- **Output:** Array of persistent `CustomerAddress` records.
- **Frontend authority:** Client holds array in memory.
- **Backend authority required:** Persistent PostgreSQL table with `user_id` foreign key and default address constraint.
- **Authentication required:** YES
- **Authorization required:** `CUSTOMER` (Own records only)
- **Ownership:** Current User
- **State transition:** N/A
- **Validation:** 6-digit Indian pincode (`/^\d{6}$/`), phone format, mandatory street address.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `CustomerAddress`
- **Open question:** Pincode city/state auto-lookup integration.

---

### BE-013 — Get Customer Wishlist & Toggle Product
- **Frontend location:** `src/state/store.ts:137-144`, `src/routes/wishlist.tsx:22`, `src/routes/account.wishlist.tsx:22`
- **Frontend trigger:** Customer clicks heart icon on product card or PDP.
- **Current implementation:** Array of string IDs in `localStorage.ogura.wishlist`.
- **Operation:** `GET` / `RPC` (`toggleWishlist`)
- **Entity:** `WishlistItem`
- **Input:** `{ "productId": "prod_01" }`
- **Output:** `{ "wishlist": ["prod_01", "prod_05"], "added": true }`
- **Frontend authority:** Frontend toggles IDs locally.
- **Backend authority required:** Database table `wishlist_items (user_id, product_id, created_at)` with unique constraint.
- **Authentication required:** YES (For persistence across devices; anonymous guest wishlist merges upon login)
- **Authorization required:** `CUSTOMER`
- **Ownership:** Current User
- **State transition:** N/A
- **Validation:** Product ID must exist and be active.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `WishlistItem`, `Product`
- **Open question:** Guest wishlist migration on login.

---

### BE-014 — Synchronize & Fetch Customer Cart
- **Frontend location:** `src/state/store.ts:88-128`, `src/routes/cart.tsx:22-45`
- **Frontend trigger:** Adding SKU to cart, updating quantity (1–10), removing item.
- **Current implementation:** Local JSON object `{ lines: [] }` in `localStorage.ogura.cart`.
- **Operation:** `GET` / `UPDATE` / `RPC`
- **Entity:** `Cart`, `CartLine`
- **Input:**
  ```json
  {
    "action": "ADD_LINE",
    "variantId": "var_01",
    "quantity": 1
  }
  ```
- **Output:**
  ```json
  {
    "cartId": "cart_88",
    "lines": [
      {
        "id": "line_01",
        "productId": "prod_01",
        "variantId": "var_01",
        "title": "Silk Organza Saree",
        "size": "Free Size",
        "color": "Ivory",
        "price": 4999,
        "quantity": 1,
        "lineTotal": 4999,
        "inStock": true,
        "availableQuantity": 4
      }
    ],
    "subtotal": 4999,
    "itemCount": 1
  }
  ```
- **Frontend authority:** Frontend creates line objects with `Date.now()` IDs and computes subtotal.
- **Backend authority required:** Server validates real stock per SKU, returns fresh current prices (ignoring stale client prices), and persists cart in database/Redis.
- **Authentication required:** OPTIONAL (Session cookie for guests, `user_id` for logged-in users)
- **Authorization required:** `CUSTOMER` / `PUBLIC` (Guest cart)
- **Ownership:** Current User / Session
- **State transition:** `ACTIVE → CHECKOUT → CONVERTED`
- **Validation:** Maximum 10 items per line, variant must exist and belong to active product.
- **Financial impact:** HIGH (Determines checkout subtotal)
- **Concurrency concern:** NONE at cart stage (Inventory reservation occurs at checkout)
- **External provider:** None
- **Dependencies:** `Cart`, `CartLine`, `ProductVariant`
- **Open question:** Cart expiration window (e.g. 30 days for logged in, 7 days for guests).

---

### BE-015 — Check Pincode Delivery Serviceability & ETA
- **Frontend location:** `src/routes/product.$productSlug.tsx:396-418`, `src/routes/shipping.tsx:16-33`
- **Frontend trigger:** Customer enters 6-digit pincode on PDP and clicks "Check".
- **Current implementation:** Mock string lookup returning "Delivers in 4–6 days to {pincode}" after 250ms delay.
- **Operation:** `GET` / `RPC`
- **Entity:** `LogisticsPartner`, `PincodeServiceability`
- **Input:** `{ "pincode": "560001", "productId": "prod_01" }`
- **Output:**
  ```json
  {
    "serviceable": true,
    "pincode": "560001",
    "city": "Bengaluru",
    "state": "Karnataka",
    "standardEtaDays": [4, 7],
    "expressAvailable": true,
    "expressEtaDays": [2, 4],
    "estimatedDeliveryDate": "2026-09-20"
  }
  ```
- **Frontend authority:** Frontend manages input state and displays response message.
- **Backend authority required:** Logistics partner serviceability matrix query based on origin seller pincode and destination pincode.
- **Authentication required:** NO
- **Authorization required:** `PUBLIC`
- **Ownership:** Logistics Partner
- **State transition:** N/A
- **Validation:** Pincode must be 6 digits.
- **Financial impact:** LOW
- **Concurrency concern:** NONE
- **External provider:** Shiprocket / Delhivery / Bluedart API
- **Dependencies:** Seller pickup pincode database
- **Open question:** Fallback ETA when courier API is down.

---

### BE-016 — Validate Checkout Draft & Generate Authoritative Financial Quote
- **Frontend location:** `src/routes/checkout.tsx:44-55, 80-92`, `src/repositories/mock/index.ts:82` (`validateDraft`)
- **Frontend trigger:** Transitioning between checkout steps or selecting delivery method.
- **Current implementation:** Client-side JavaScript computes `subtotal = sum(price * qty)`, `shipping = subtotal >= 2999 ? 0 : 99`, `total = subtotal + shipping`.
- **Operation:** `RPC` / `ACTION`
- **Entity:** `CheckoutQuote`, `OrderDraft`
- **Input:**
  ```json
  {
    "items": [{ "variantId": "var_01", "quantity": 1 }],
    "deliveryMethod": "standard",
    "address": {
      "fullName": "Priya Sen",
      "phone": "9876543210",
      "line1": "Flat 402, Lotus Towers",
      "city": "Bengaluru",
      "state": "Karnataka",
      "pincode": "560038"
    },
    "couponCode": ""
  }
  ```
- **Output:**
  ```json
  {
    "quoteId": "quote_77192",
    "validUntil": "2026-09-14T23:45:00Z",
    "subtotal": 4999,
    "discount": 0,
    "shippingFee": 0,
    "taxAmount": 0,
    "totalPayable": 4999,
    "currency": "INR",
    "inventoryReserved": true,
    "errors": {}
  }
  ```
- **Frontend authority:** Client currently computes all currency figures and asserts validity.
- **Backend authority required:** Backend MUST calculate subtotal from active database prices, apply canonical shipping rule, validate coupon validity, calculate GST if applicable, and temporarily reserve inventory lock (e.g. 15-minute lock).
- **Authentication required:** OPTIONAL (Can be guest or authenticated)
- **Authorization required:** `PUBLIC` / `CUSTOMER`
- **Ownership:** Checkout Session
- **State transition:** `DRAFT → QUOTED_AND_HELD`
- **Validation:** Address completeness, phone regex, SKU availability > 0, coupon validity.
- **Financial impact:** **CRITICAL** (Governs exact charge to customer)
- **Concurrency concern:** **REQUIRED** (Must verify stock availability before holding)
- **External provider:** None
- **Dependencies:** `ProductVariant`, `Inventory`, `Coupon`
- **Open question:** Does subtotal >= ₹2,999 waive Express shipping or only Standard shipping? (Conflict F-01).

---

### BE-017 — Initiate Payment Order with Gateway
- **Frontend location:** `src/routes/checkout.tsx:94-100`
- **Frontend trigger:** Customer clicks "Complete order" at final checkout step.
- **Current implementation:** Bypassed completely; calls `repositories.checkout.createMockOrder` immediately.
- **Operation:** `ACTION` / `RPC`
- **Entity:** `PaymentIntent`, `GatewayOrder`
- **Input:**
  ```json
  {
    "quoteId": "quote_77192",
    "paymentMethod": "upi"
  }
  ```
- **Output:**
  ```json
  {
    "gatewayOrderId": "order_Rzp1029384",
    "keyId": "rzp_test_12345",
    "amount": 499900,
    "currency": "INR",
    "customer": { "name": "Priya Sen", "email": "priya@example.com", "contact": "9876543210" }
  }
  ```
- **Frontend authority:** None.
- **Backend authority required:** Server communicates with payment gateway API using private API keys to create an immutable payment order.
- **Authentication required:** OPTIONAL (Guest or logged-in)
- **Authorization required:** `CUSTOMER` / `PUBLIC`
- **Ownership:** Payment Service
- **State transition:** `QUOTE → PAYMENT_PENDING`
- **Validation:** Quote must not be expired, amount must be in paise (> 0).
- **Financial impact:** **CRITICAL** (Initializes real money transaction)
- **Concurrency concern:** REQUIRED
- **External provider:** Razorpay / Cashfree / Stripe
- **Dependencies:** Payment gateway SDK
- **Open question:** Gateway selection (Razorpay candidate vs alternative).

---

### BE-018 — Verify Payment Signature & Authoritatively Commit Order
- **Frontend location:** Downstream of payment modal completion; verified via webhook/callback.
- **Frontend trigger:** Gateway returns `razorpay_payment_id`, `razorpay_order_id`, `razorpay_signature`.
- **Current implementation:** Client fabricates `DEMO-OG-XXXX` ID, sets `status: "placed"`, and calls `saveOrder()`.
- **Operation:** `ACTION` / `WEBHOOK`
- **Entity:** `Order`, `PaymentTransaction`, `Inventory`
- **Input:**
  ```json
  {
    "gatewayOrderId": "order_Rzp1029384",
    "gatewayPaymentId": "pay_Rzp554433",
    "gatewaySignature": "9f83ab...signature"
  }
  ```
- **Output:**
  ```json
  {
    "orderNumber": "OG-2026-9812",
    "status": "placed",
    "total": 4999,
    "createdAt": "2026-09-14T23:35:00Z"
  }
  ```
- **Frontend authority:** Frontend currently manufactures order records in localStorage.
- **Backend authority required:** Server MUST verify HMAC SHA256 signature using webhook secret, atomically deduct stock from `Inventory`, create `orders` and `order_items` records in PostgreSQL, mark quote consumed, and clear cart.
- **Authentication required:** NO (Webhook uses signature header; client callback passes token)
- **Authorization required:** `SYSTEM` / `CUSTOMER`
- **Ownership:** Order Management
- **State transition:** `PAYMENT_PENDING → PLACED (CONFIRMED)`
- **Validation:** Cryptographic signature verification, idempotent execution (duplicate webhook must not double-create order).
- **Financial impact:** **CRITICAL** (Reconciles real money)
- **Concurrency concern:** **REQUIRED** (Atomic inventory decrement inside transaction)
- **External provider:** Payment Gateway Webhook
- **Dependencies:** `orders`, `order_items`, `payments`, `inventory`
- **Open question:** Webhook retry handling and idempotency keys.

---

### BE-019 — Get Order Detail by Order ID
- **Frontend location:** `src/routes/order.success.$orderId.tsx:21-35`, `src/repositories/mock/index.ts:68-70`
- **Frontend trigger:** Navigating to `/order/success/$orderId` or viewing order details from history.
- **Current implementation:** `mockAccountRepository.getOrder(orderNumber)` finding record in `localStorage.ogura.orders`.
- **Operation:** `GET`
- **Entity:** `Order`, `OrderItem`, `Shipment`
- **Input:** `{ "orderId": "OG-2026-9812" }`
- **Output:**
  ```json
  {
    "orderNumber": "OG-2026-9812",
    "createdAt": 1757890500000,
    "status": "placed",
    "items": [
      {
        "productId": "prod_01",
        "productSlug": "silk-organza-saree",
        "variantId": "var_01",
        "title": "Silk Organza Saree",
        "brandName": "Label Raas",
        "size": "Free Size",
        "color": "Ivory",
        "quantity": 1,
        "price": 4999
      }
    ],
    "subtotal": 4999,
    "shipping": 0,
    "total": 4999,
    "address": { "fullName": "Priya Sen", "line1": "...", "city": "Bengaluru", "pincode": "560038" },
    "paymentMethod": "upi",
    "estimatedDelivery": "2026-09-20"
  }
  ```
- **Frontend authority:** None.
- **Backend authority required:** PostgreSQL query with customer ownership verification (guest orders viewable via signed token).
- **Authentication required:** OPTIONAL (Signed token or user login)
- **Authorization required:** `CUSTOMER` (Own order) / `GUEST_WITH_TOKEN` / `ADMIN`
- **Ownership:** Order Record
- **State transition:** N/A
- **Validation:** Order ID must exist.
- **Financial impact:** LOW
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `orders`, `order_items`
- **Open question:** Guest order access token security on success page.

---

### BE-020 — List Customer Order History
- **Frontend location:** `src/routes/account.orders.tsx:20-45`, `src/repositories/mock/index.ts:64-66`
- **Frontend trigger:** Customer visits `/account/orders`.
- **Current implementation:** Reads `localStorage.ogura.orders`.
- **Operation:** `GET`
- **Entity:** `Order`
- **Input:** User session context (`auth.uid()`)
- **Output:** Array of `OrderSummary` records sorted by `created_at DESC`.
- **Frontend authority:** None.
- **Backend authority required:** Query PostgreSQL `orders` table filtered by `user_id`.
- **Authentication required:** YES
- **Authorization required:** `CUSTOMER` (`auth.uid() = user_id`)
- **Ownership:** Current User
- **State transition:** N/A
- **Validation:** None.
- **Financial impact:** LOW
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `orders`
- **Open question:** None.

---

### BE-021 — Track Order by Pincode & Order Number
- **Frontend location:** `src/routes/track-order.tsx:30-55`
- **Frontend trigger:** Customer enters order number and email/phone on `/track-order`.
- **Current implementation:** Static UI placeholder form.
- **Operation:** `GET` / `RPC`
- **Entity:** `Shipment`, `LogisticsEvent`
- **Input:** `{ "orderNumber": "OG-2026-9812", "phoneOrPincode": "560038" }`
- **Output:**
  ```json
  {
    "orderNumber": "OG-2026-9812",
    "status": "in_transit",
    "carrier": "Delhivery",
    "awb": "DEL99281726",
    "estimatedDelivery": "2026-09-20",
    "timeline": [
      { "status": "Order Placed", "timestamp": "2026-09-14T10:00:00Z", "completed": true },
      { "status": "Dispatched from Studio", "timestamp": "2026-09-15T14:30:00Z", "completed": true },
      { "status": "In Transit (Bengaluru Hub)", "timestamp": "2026-09-16T08:00:00Z", "completed": true },
      { "status": "Out for Delivery", "timestamp": null, "completed": false }
    ]
  }
  ```
- **Frontend authority:** None.
- **Backend authority required:** Logistics partner webhook synchronization and shipment status query.
- **Authentication required:** NO (Public lookup with order number + phone/pincode verification)
- **Authorization required:** `PUBLIC`
- **Ownership:** Shipment
- **State transition:** N/A
- **Validation:** Order number and phone/pincode must match database record.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** Logistics API (Shiprocket / Delhivery)
- **Dependencies:** `shipments`, `logistics_events`
- **Open question:** Frequency of webhook vs polling courier API.

---

### BE-022 — Submit Made-to-Order (MTO) Request
- **Frontend location:** `src/data/mockMerchandising.ts:37, 43`, `src/routes/product.$productSlug.tsx:389`
- **Frontend trigger:** User clicks "Start a request" from MTO banner or PDP.
- **Current implementation:** Route is missing (404). Merchandising references `/made-to-order/request`.
- **Operation:** `CREATE`
- **Entity:** `MTORequest`
- **Input:**
  ```json
  {
    "productId": "prod_01",
    "variantId": "var_01",
    "intent": "footwear",
    "customerName": "Rhea Kapoor",
    "customerPhone": "9876543210",
    "customerEmail": "rhea@example.com",
    "measurements": { "bust": "34", "waist": "28", "hips": "38", "height": "5ft 6in" },
    "notes": "Need deeper neckline and delivery before Oct 15",
    "targetDate": "2026-10-15"
  }
  ```
- **Output:**
  ```json
  {
    "requestId": "mto_8829",
    "referenceNumber": "MTO-OG-4412",
    "status": "submitted",
    "createdAt": "2026-09-14T23:35:00Z"
  }
  ```
- **Frontend authority:** Missing in frontend.
- **Backend authority required:** Insert into `mto_requests` table, trigger notification to seller atelier, generate reference number.
- **Authentication required:** OPTIONAL (Can capture contact details from guest)
- **Authorization required:** `PUBLIC` / `CUSTOMER`
- **Ownership:** Customer / Assigned Seller Atelier
- **State transition:** `NULL → SUBMITTED`
- **Validation:** Valid phone, name, product ID.
- **Financial impact:** HIGH (Eventual high-value bespoke order)
- **Concurrency concern:** NONE
- **External provider:** Atelier notification (WhatsApp / Email)
- **Dependencies:** `Product`, `Seller`, `mto_requests`
- **Open question:** Route destination decision (Finding F-02).

---

### BE-023 — Get Made-to-Order Request Status
- **Frontend location:** Account or customer tracking view.
- **Operation:** `GET`
- **Entity:** `MTORequest`
- **Input:** `{ "requestId": "mto_8829" }`
- **Output:** Status (`submitted`, `atelier_review`, `quote_issued`, `in_crafting`, `dispatched`), bespoke price quote, atelier notes.
- **Frontend authority:** None.
- **Backend authority required:** PostgreSQL query with access control.
- **Authentication required:** YES (Or signed reference lookup)
- **Authorization required:** `CUSTOMER` / `SELLER` / `ADMIN`
- **Ownership:** Customer & Seller
- **State transition:** N/A
- **Validation:** Valid request ID.
- **Financial impact:** HIGH
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `mto_requests`
- **Open question:** None.

---

### BE-024 — Get Seller Dashboard Overview Metrics
- **Frontend location:** `src/routes/seller.index.tsx:21-45`
- **Frontend trigger:** Seller visits `/seller`.
- **Current implementation:** Hardcoded static figures in component (`totalSales: ₹4,82,900`, `activeStyles: 28`, `pendingFulfillment: 6`, `nextPayout: ₹1,12,400`).
- **Operation:** `GET`
- **Entity:** `SellerProfile`, `SellerMetric`
- **Input:** Seller session context (`auth.uid() → seller_id`)
- **Output:**
  ```json
  {
    "sellerId": "seller_01",
    "brandName": "Studio Amala",
    "totalSales": 482900,
    "activeStyles": 28,
    "pendingFulfillment": 6,
    "nextPayoutDate": "2026-09-21",
    "nextPayoutAmount": 112400
  }
  ```
- **Frontend authority:** Hardcoded static numbers.
- **Backend authority required:** Real-time aggregation of seller's fulfilled order lines and ledger balance.
- **Authentication required:** YES
- **Authorization required:** `SELLER` (Role check + `seller_id` matching)
- **Ownership:** Current Seller
- **State transition:** N/A
- **Validation:** User must have `seller` role.
- **Financial impact:** HIGH
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `orders`, `order_items`, `payouts`
- **Open question:** None.

---

### BE-025 — List Seller Products & Inventory Levels
- **Frontend location:** `src/routes/seller.products.tsx:25-50`
- **Frontend trigger:** Seller visits `/seller/products`.
- **Current implementation:** Filters `mockProducts` array in memory by brand name.
- **Operation:** `GET`
- **Entity:** `Product`, `ProductVariant`, `Inventory`
- **Input:** Seller session context (`seller_id`), `page?: number`
- **Output:**
  ```json
  {
    "products": [
      {
        "id": "prod_01",
        "title": "Ivory Raw Silk Kurta",
        "slug": "ivory-raw-silk-kurta",
        "sku": "AMA-RSK-01",
        "price": 2499,
        "variantCount": 4,
        "stockOnHand": 18,
        "status": "published"
      }
    ],
    "total": 28
  }
  ```
- **Frontend authority:** None.
- **Backend authority required:** PostgreSQL query filtered strictly by `seller_id` via RLS.
- **Authentication required:** YES
- **Authorization required:** `SELLER` (Tenancy enforcement)
- **Ownership:** Seller Catalog
- **State transition:** N/A
- **Validation:** Seller owns product styles.
- **Financial impact:** MEDIUM
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `Product`, `ProductVariant`
- **Open question:** None.

---

### BE-026 — List Seller Orders & Sub-Orders
- **Frontend location:** `src/routes/seller.orders.tsx:22-48`
- **Frontend trigger:** Seller visits `/seller/orders`.
- **Current implementation:** Hardcoded static slice of 3 mock orders.
- **Operation:** `GET`
- **Entity:** `OrderItem`, `SellerSubOrder`
- **Input:** Seller session context (`seller_id`), `status?: string`
- **Output:**
  ```json
  {
    "orders": [
      {
        "orderNumber": "OG-2026-9812",
        "lineItemId": "item_441",
        "createdAt": "2026-09-14T10:00:00Z",
        "customerCity": "Bengaluru",
        "sku": "AMA-RSK-01-M",
        "title": "Ivory Raw Silk Kurta",
        "size": "M",
        "quantity": 1,
        "payoutPrice": 1999,
        "status": "pending_pickup"
      }
    ]
  }
  ```
- **Frontend authority:** None.
- **Backend authority required:** Query `order_items` joined with `orders` filtered strictly by `seller_id`.
- **Authentication required:** YES
- **Authorization required:** `SELLER`
- **Ownership:** Seller Orders
- **State transition:** N/A
- **Validation:** Seller can only see line items belonging to their atelier.
- **Financial impact:** HIGH
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `order_items`, `orders`
- **Open question:** Hiding customer PII (e.g. phone/address) from seller per privacy policy.

---

### BE-027 — Update Seller Order Fulfillment Status
- **Frontend location:** `src/routes/seller.orders.tsx:40`
- **Frontend trigger:** Seller marks line item as "Ready for pickup" or "Dispatched".
- **Current implementation:** Static button without event handler.
- **Operation:** `UPDATE` / `RPC`
- **Entity:** `OrderItem`, `Shipment`
- **Input:**
  ```json
  {
    "lineItemId": "item_441",
    "status": "ready_to_ship",
    "pickupPincode": "302001",
    "packageWeightKg": 0.8
  }
  ```
- **Output:** `{ "success": true, "newStatus": "ready_to_ship", "awb": "DEL991823" }`
- **Frontend authority:** None.
- **Backend authority required:** Update sub-order state machine, notify courier partner to schedule pickup, emit notification to customer.
- **Authentication required:** YES
- **Authorization required:** `SELLER`
- **Ownership:** Current Seller
- **State transition:** `PLACED → READY_FOR_PICKUP → DISPATCHED`
- **Validation:** Seller owns line item; transition must be legally permitted in state machine.
- **Financial impact:** MEDIUM
- **Concurrency concern:** NONE
- **External provider:** Courier API (Shiprocket / Delhivery)
- **Dependencies:** `order_items`, `shipments`
- **Open question:** Automatic AWB generation vs manual entry.

---

### BE-028 — Get Seller Payout History & Statements
- **Frontend location:** `src/routes/seller.payouts.tsx:21-45`
- **Frontend trigger:** Seller visits `/seller/payouts`.
- **Current implementation:** Hardcoded static array of past payout dates and amounts.
- **Operation:** `GET`
- **Entity:** `PayoutStatement`, `PayoutTransaction`
- **Input:** Seller session context (`seller_id`)
- **Output:**
  ```json
  {
    "pendingBalance": 112400,
    "nextPayoutDate": "2026-09-21",
    "statements": [
      {
        "id": "pay_stmt_10",
        "period": "1 Sep – 7 Sep 2026",
        "grossSales": 142000,
        "commission": 28400,
        "logisticsDeductions": 1200,
        "netPaid": 112400,
        "utrNumber": "CMS99281726351",
        "paidAt": "2026-09-08T11:00:00Z"
      }
    ]
  }
  ```
- **Frontend authority:** None.
- **Backend authority required:** Ledger reconciliation table calculation in PostgreSQL.
- **Authentication required:** YES
- **Authorization required:** `SELLER`
- **Ownership:** Current Seller
- **State transition:** N/A
- **Validation:** Access restricted to seller owner.
- **Financial impact:** **CRITICAL** (Financial accounting records)
- **Concurrency concern:** NONE
- **External provider:** Bank Payout API (RazorpayX / Cashfree Payouts / Bank NEFT)
- **Dependencies:** `payouts`, `seller_accounts`
- **Open question:** Payout cadence (weekly on Mondays vs bi-weekly).

---

### BE-029 — Get Admin Platform Overview Metrics
- **Frontend location:** `src/routes/admin.index.tsx:20-45`
- **Frontend trigger:** Admin opens `/admin`.
- **Current implementation:** Hardcoded static figures (`GMV: ₹42,90,000`, `Orders: 1,420`, `Styles: 311`, `Designers: 42`).
- **Operation:** `GET`
- **Entity:** `PlatformMetric`
- **Input:** Admin session context (`role = 'admin'`)
- **Output:** Real-time platform aggregates (total GMV, order volume, live inventory, active sellers).
- **Frontend authority:** None.
- **Backend authority required:** PostgreSQL analytic query.
- **Authentication required:** YES
- **Authorization required:** `ADMIN`
- **Ownership:** Platform Admin
- **State transition:** N/A
- **Validation:** User must have verified `admin` claim in JWT.
- **Financial impact:** HIGH
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** Analytics views
- **Open question:** Cached analytics materialized views vs live queries.

---

### BE-030 — Admin Catalog Master Listing & Moderation
- **Frontend location:** `src/routes/admin.catalog.tsx:22-50`
- **Frontend trigger:** Admin visits `/admin/catalog`.
- **Current implementation:** Renders table from static `mockProducts` array.
- **Operation:** `GET` / `UPDATE`
- **Entity:** `Product`
- **Input:** `{ "page": 1, "status": "all" }` or `{ "productId": "prod_01", "status": "suspended" }`
- **Output:** Paginated master catalog list or mutation confirmation.
- **Frontend authority:** None.
- **Backend authority required:** Global product catalog query bypassing seller tenancy filters.
- **Authentication required:** YES
- **Authorization required:** `ADMIN`
- **Ownership:** Platform Admin
- **State transition:** `DRAFT ↔ PUBLISHED ↔ SUSPENDED`
- **Validation:** Admin role verification.
- **Financial impact:** HIGH (Affects platform merchandise)
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `Product`
- **Open question:** Audit logging of admin catalog alterations.

---

### BE-031 — Admin Master Orders Ledger
- **Frontend location:** `src/routes/admin.orders.tsx:22-50`
- **Frontend trigger:** Admin visits `/admin/orders`.
- **Current implementation:** Reads all orders from `localStorage.ogura.orders`.
- **Operation:** `GET`
- **Entity:** `Order`, `OrderItem`, `PaymentTransaction`
- **Input:** `{ "page": 1, "status"?: "placed", "dateRange"?: "30d" }`
- **Output:** Master list of all platform orders with buyer and seller details.
- **Frontend authority:** Currently reads localStorage.
- **Backend authority required:** PostgreSQL master query on `orders` table.
- **Authentication required:** YES
- **Authorization required:** `ADMIN`
- **Ownership:** Platform Admin
- **State transition:** N/A
- **Validation:** Admin role verification.
- **Financial impact:** **CRITICAL**
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** `orders`
- **Open question:** Export to CSV functionality for finance team.

---

### BE-032 — Admin Merchandising Slot Control
- **Frontend location:** `src/routes/admin.merchandising.tsx:20-45`
- **Frontend trigger:** Admin visits `/admin/merchandising`.
- **Current implementation:** Static summary cards of slots.
- **Operation:** `GET` / `UPDATE`
- **Entity:** `MerchandisingSlot`, `Campaign`
- **Input:** `{ "slotKey": "plp.ethnicwear.insert36", "active": true, "campaignId": "camp_02" }`
- **Output:** Updated slot configuration.
- **Frontend authority:** None.
- **Backend authority required:** PostgreSQL table storing homepage hero banners and PLP editorial inserts.
- **Authentication required:** YES
- **Authorization required:** `ADMIN`
- **Ownership:** Platform Admin
- **State transition:** N/A
- **Validation:** Valid slot key and campaign reference.
- **Financial impact:** LOW
- **Concurrency concern:** NONE
- **External provider:** None
- **Dependencies:** Merchandising tables
- **Open question:** None.

---

### BE-033 — Get Product Media Manifest & Optimized Asset URLs
- **Frontend location:** `src/repositories/mock/productMediaRepository.ts:33-60`, `src/components/media/CatalogProductImage.tsx:4`
- **Frontend trigger:** Any card or gallery rendering an image.
- **Current implementation:** Synchronous memory lookup in `src/data/generated/productMedia.json`.
- **Operation:** `GET`
- **Entity:** `MediaAsset`, `ProductMedia`
- **Input:** `{ "productId": "prod_01" }`
- **Output:**
  ```json
  {
    "images": [
      {
        "imageId": "img_01",
        "role": "PRIMARY",
        "isPrimary": true,
        "cdnUrl": "https://cdn.ogura.in/catalog/prod_01/primary.webp",
        "thumbnailUrl": "https://cdn.ogura.in/catalog/prod_01/primary_thumb.webp",
        "aspectRatio": "3:4",
        "alt": "Ivory Raw Silk Kurta front angle"
      }
    ]
  }
  ```
- **Frontend authority:** None.
- **Backend authority required:** Database query on `media_assets` returning cloud storage URLs behind CDN.
- **Authentication required:** NO
- **Authorization required:** `PUBLIC`
- **Ownership:** Catalog Media
- **State transition:** N/A
- **Validation:** Valid product ID.
- **Financial impact:** LOW (CDN bandwidth)
- **Concurrency concern:** NONE
- **External provider:** Cloudflare R2 / AWS S3 + Cloudflare Images / Imgix
- **Dependencies:** Media tables
- **Open question:** Media migration timeline from Google Drive (Finding F-09).

---

### BE-034 — Log Missing / Broken Media Asset (Quality Monitoring)
- **Frontend location:** `src/repositories/mock/productMediaRepository.ts:23-27` (`markImageFailed`)
- **Frontend trigger:** Image fails to load on client (`img.onError`).
- **Current implementation:** Calls `markImageFailed()`, logs `console.warn`, sets local Set.
- **Operation:** `ACTION` / `LOG`
- **Entity:** `MediaErrorLog`
- **Input:** `{ "imageId": "img_01", "productId": "prod_01", "url": "https://..." }`
- **Output:** `{ "recorded": true }`
- **Frontend authority:** Frontend logs to browser console.
- **Backend authority required:** Sentry / Datadog / PostgreSQL error log for catalog quality gating.
- **Authentication required:** NO
- **Authorization required:** `PUBLIC`
- **Ownership:** System Quality Monitoring
- **State transition:** N/A
- **Validation:** Rate limited logging endpoint.
- **Financial impact:** NONE
- **Concurrency concern:** NONE
- **External provider:** Sentry / Cloudwatch
- **Dependencies:** None
- **Open question:** None.

---

### BE-035 — Dispatch Order Confirmation Notifications (Email / SMS / WhatsApp)
- **Frontend location:** Triggered immediately after payment verification (`BE-018`).
- **Frontend trigger:** Order status transition to `placed`.
- **Current implementation:** Absent; success page merely displays order number.
- **Operation:** `SYSTEM` / `EVENT`
- **Entity:** `NotificationQueue`
- **Input:** `{ "orderId": "OG-2026-9812" }`
- **Output:** `{ "notificationId": "notif_99", "status": "queued" }`
- **Frontend authority:** None.
- **Backend authority required:** Transactional notification engine sending order confirmation email and WhatsApp/SMS notification to buyer.
- **Authentication required:** SYSTEM
- **Authorization required:** `SYSTEM`
- **Ownership:** Notification Service
- **State transition:** N/A
- **Validation:** Verified order ID.
- **Financial impact:** LOW
- **Concurrency concern:** NONE
- **External provider:** Resend / SendGrid (Email) + Gupshup / Twilio (WhatsApp/SMS)
- **Dependencies:** `orders`, `notifications`
- **Open question:** WhatsApp template pre-approval by Meta.

---

### BE-036 — Expire & Release Inventory Reservations (Background Cron)
- **Frontend location:** Downstream of expired checkout quotes (`BE-016`).
- **Frontend trigger:** Periodic background timer (every 1 minute).
- **Current implementation:** Absent in frontend.
- **Operation:** `SYSTEM` / `CRON`
- **Entity:** `InventoryReservation`
- **Input:** `{ "cutoffTime": "now() - interval '15 minutes'" }`
- **Output:** `{ "releasedReservations": 14 }`
- **Frontend authority:** None.
- **Backend authority required:** Scheduled background worker finding unpaid checkout quotes older than 15 minutes and atomically returning held quantities to available inventory pool.
- **Authentication required:** SYSTEM
- **Authorization required:** `SYSTEM`
- **Ownership:** Inventory Service
- **State transition:** `HELD → EXPIRED (RELEASED)`
- **Validation:** Only release reservations with `payment_status = 'pending'`.
- **Financial impact:** HIGH (Restores product availability for sale)
- **Concurrency concern:** **REQUIRED** (Atomic inventory increment inside transaction)
- **External provider:** Cron Scheduler (e.g. Supabase pg_cron / AWS EventBridge)
- **Dependencies:** `inventory`, `checkout_quotes`
- **Open question:** Hold duration (10 minutes vs 15 minutes).

---

## 51. Frontend Repository Mapping

Complete mapping of all 6 frontend repositories and their methods:

| Repository Interface | Method Name | Correesponding Backend Endpoint | Entity | Input | Output | Auth Required | Authorization | Backend Authority Required |
|---|---|---|---|---|---|---|---|---|
| `CatalogRepository` | `listProducts` | `BE-001` | `Product` | `CatalogQuery` | `Product[]` | NO | `PUBLIC` | Database filtering, facets, pagination. |
| `CatalogRepository` | `getProductBySlug` | `BE-002` | `Product` | `slug: string` | `Product \| null` | NO | `PUBLIC` | Authoritative product details and status. |
| `CatalogRepository` | `searchProducts` | `BE-003` | `Product` | `query: string` | `Product[]` | NO | `PUBLIC` | Database full-text search. |
| `CartRepository` | `getCart` | `BE-014` | `Cart` | None | `Cart` | OPTIONAL | `CUSTOMER` / `PUBLIC` | Authoritative line items and validated prices. |
| `CartRepository` | `addLine` | `BE-014` | `CartLine` | `(productId, variantId, qty)` | `Cart` | OPTIONAL | `CUSTOMER` / `PUBLIC` | Stock check, price validation, persistence. |
| `CartRepository` | `updateQuantity` | `BE-014` | `CartLine` | `(lineId, qty)` | `Cart` | OPTIONAL | `CUSTOMER` / `PUBLIC` | Stock clamp, line recalculation. |
| `CartRepository` | `removeLine` | `BE-014` | `CartLine` | `lineId: string` | `Cart` | OPTIONAL | `CUSTOMER` / `PUBLIC` | Line item deletion. |
| `CartRepository` | `clear` | `BE-014` | `Cart` | None | `Cart` | OPTIONAL | `CUSTOMER` / `PUBLIC` | Cart purge. |
| `WishlistRepository` | `getWishlist` | `BE-013` | `WishlistItem` | None | `string[]` | YES | `CUSTOMER` | User wishlist query from database. |
| `WishlistRepository` | `toggle` | `BE-013` | `WishlistItem` | `productId: string` | `string[]` | YES | `CUSTOMER` | Atomic insert / delete toggle. |
| `AccountRepository` | `getProfile` | `BE-011` | `Profile` | None | `Profile` | YES | `CUSTOMER` | User profile query from database. |
| `AccountRepository` | `updateProfile` | `BE-011` | `Profile` | `Partial<Profile>` | `Profile` | YES | `CUSTOMER` | Database profile update. |
| `AccountRepository` | `listOrders` | `BE-020` | `Order` | None | `Order[]` | YES | `CUSTOMER` | User orders query from database. |
| `AccountRepository` | `getOrder` | `BE-019` | `Order` | `orderNumber: string` | `Order \| null` | YES | `CUSTOMER` | Single order detail query. |
| `CheckoutRepository` | `getDraft` | `BE-016` | `CheckoutDraft` | None | `CheckoutDraft` | OPTIONAL | `CUSTOMER` / `PUBLIC` | Saved checkout draft query. |
| `CheckoutRepository` | `saveDraft` | `BE-016` | `CheckoutDraft` | `CheckoutDraft` | `void` | OPTIONAL | `CUSTOMER` / `PUBLIC` | Checkout state persistence. |
| `CheckoutRepository` | `validateDraft` | `BE-016` | `CheckoutDraft` | `CheckoutDraft` | `Record<string, string>` | OPTIONAL | `CUSTOMER` / `PUBLIC` | Server address and stock validation. |
| `CheckoutRepository` | `createMockOrder` | `BE-017` / `BE-018` | `Order` | `(draft, address)` | `Order` | OPTIONAL | `CUSTOMER` / `PUBLIC` | Replaced by payment verification and order commit. |
| `ProductMediaRepository` | `getProductMedia` | `BE-033` | `ProductMedia` | `productId: string` | `ProductMediaRecord` | NO | `PUBLIC` | Database media query. |
| `ProductMediaRepository` | `getProductGallery` | `BE-033` | `ProductMedia` | `productId: string` | `ProductImageRecord[]` | NO | `PUBLIC` | Gallery image array query. |
| `ProductMediaRepository` | `getPrimaryImage` | `BE-033` | `ProductMedia` | `productId: string` | `ProductImageRecord` | NO | `PUBLIC` | Primary image query. |
| `ProductMediaRepository` | `getSecondaryImage` | `BE-033` | `ProductMedia` | `productId: string` | `ProductImageRecord` | NO | `PUBLIC` | Secondary angle query. |
| `ProductMediaRepository` | `markImageFailed` | `BE-034` | `MediaErrorLog` | `imageRecord` | `void` | NO | `PUBLIC` | Server telemetry logging. |

---

## 52. Local Storage Mapping & Migration Plan

All 10 storage keys declared in `src/lib/storage.ts`:

| Storage Key | Purpose | Read Locations | Write Locations | Data Shape | Current Authority | Target Backend Entity | Survives Migration? | Migration Strategy |
|---|---|---|---|---|---|---|---|---|
| `ogura.cart` | Store customer cart lines | `store.ts:54` | `store.ts:102, 112, 119, 126` | `{ lines: CartLine[] }` | Client | `Cart`, `CartLine` | **NO** | Migrate to database cart table on login; guest cart stored in cookie session. |
| `ogura.buyNow` | Store instant buy-now context | `store.ts:55` | `store.ts:132` | `CartLine \| null` | Client | `CheckoutQuote` | **NO** | Ephemeral server session quote. |
| `ogura.wishlist` | Store saved product IDs | `store.ts:56` | `store.ts:142` | `string[]` | Client | `WishlistItem` | **NO** | Replaced by database `wishlist_items` table linked to `user_id`. |
| `ogura.recentlyViewed` | Recent products rail on PDP | `store.ts:57` | `store.ts:151` | `string[]` (max 12) | Client | None / Local | **YES** | Keep in client `localStorage` for privacy and instant local rendering. |
| `ogura.searchHistory` | Recent queries in search bar | `store.ts:58` | `store.ts:161, 166` | `string[]` (max 8) | Client | None / Local | **YES** | Keep in client `localStorage`. |
| `ogura.checkoutDraft` | Form fields during checkout | `store.ts:59`, `account.addresses.tsx:32` | `store.ts:173`, `checkout.tsx:83` | `CheckoutDraft` | Client | `CheckoutSession` | **PARTIALLY** | Keep local draft for form recovery, but server holds authoritative quote. |
| `ogura.session` | User profile and login state | `store.ts:60`, `account.profile.tsx:21` | `store.ts:184, 189` | `Profile` | Client | `User`, `CustomerProfile` | **NO** | Replaced by secure httpOnly JWT session cookies. |
| `ogura.orders` | Placed orders history | `store.ts:61`, `admin.orders.tsx:22` | `store.ts:179` | `Order[]` | Client | `Order`, `OrderItem` | **NO** | Replaced by PostgreSQL `orders` table. Client never stores authoritative orders. |
| `ogura.addresses` | Declared address key | None (Unused) | None (Unused) | Declared only | None | `CustomerAddress` | **NO** | Dead key. New backend address table will be used. |
| `ogura.reviews` | Declared review key | None (Unused) | None (Unused) | Declared only | None | `ProductReview` | **NO** | Dead key. Replaced by PostgreSQL `reviews` table. |

---

## 53. State Machine Specifications

Every state machine required by the backend:

### 1. Order State Machine
- **Entity:** `Order`
- **States:** `draft` → `placed` → `confirmed` → `in_crafting` → `ready_for_pickup` → `dispatched` → `in_transit` → `out_for_delivery` → `delivered` (Terminal) / `cancelled` (Terminal) / `returned` (Terminal)
- **Trigger:** Payment verification (`placed`), Atelier acceptance (`confirmed`), Dispatch update (`dispatched`), Delivery confirmation (`delivered`).
- **Current frontend behavior:** Jumps directly to `placed` on mock checkout completion. No subsequent transitions possible.
- **Expected backend authority:** Strict server-side transition validator. Only specific actors can execute specific transitions (e.g. Customer can only cancel during `placed` stage before `confirmed`; Courier transitions `dispatched` → `delivered`).
- **Invalid transitions:** `delivered → placed`, `cancelled → dispatched`, `dispatched → cancelled`.

### 2. Cart State Machine
- **Entity:** `Cart`
- **States:** `active` → `checkout_initiated` → `locked_for_payment` → `converted` (Terminal) / `abandoned` (Terminal)
- **Trigger:** Adding items, proceeding to checkout, completing order, or inactivity.
- **Current frontend behavior:** Pure array mutations in localStorage.
- **Expected backend authority:** Redis/Postgres TTL for cart lifecycle.

### 3. Payment State Machine
- **Entity:** `PaymentTransaction`
- **States:** `initiated` → `pending` → `authorized` → `captured` (Terminal) / `failed` (Terminal) / `refunded` (Terminal)
- **Trigger:** Gateway order creation, customer pin entry, webhook callback.
- **Current frontend behavior:** Completely mocked via radio button.
- **Expected backend authority:** Payment gateway webhook signature verification.

### 4. Inventory State Machine
- **Entity:** `InventoryItem`
- **States:** `available` → `held_in_checkout` → `committed` → `dispatched` / `released` (Back to `available`)
- **Trigger:** Step 4 in checkout holds item for 15 minutes; payment confirmation commits item; timeout releases item.
- **Current frontend behavior:** Static modulo logic in memory (`product.id % 7 !== 0`).
- **Expected backend authority:** Atomic `SELECT FOR UPDATE` or Redis lock during checkout; background auto-release cron.

### 5. Authentication State Machine
- **Entity:** `AuthSession`
- **States:** `anonymous` → `otp_sent` → `authenticated` → `expired` / `logged_out`
- **Trigger:** User enters phone, submits valid OTP, clicks sign out.
- **Current frontend behavior:** Client flips boolean `signedIn: true` in localStorage.
- **Expected backend authority:** Cryptographic JWT token issuance and server revocation list.

### 6. Made-to-Order (MTO) State Machine
- **Entity:** `MTORequest`
- **States:** `submitted` → `atelier_review` → `quote_provided` → `customer_accepted` → `in_crafting` → `dispatched` → `delivered` / `declined`
- **Trigger:** Customer submission, atelier review, bespoke quotation, customer checkout.
- **Current frontend behavior:** **STATE MACHINE INCOMPLETE IN FRONTEND** (Route is missing; returns 404).
- **Expected backend authority:** Dedicated bespoke workflow tracking customer measurements and atelier approvals.

### 7. Seller Sub-Order State Machine
- **Entity:** `SellerSubOrder`
- **States:** `pending_atelier_acceptance` → `accepted` → `in_crafting` → `ready_for_pickup` → `picked_up` → `delivered`
- **Trigger:** Multi-seller split order routing to individual seller atelier.
- **Current frontend behavior:** Static mock rows in `src/routes/seller.orders.tsx`.
- **Expected backend authority:** Independent fulfillment tracking per seller for split shipments.

### 8. Seller Payout State Machine
- **Entity:** `PayoutStatement`
- **States:** `accruing` → `hold_period` → `statement_generated` → `payout_initiated` → `paid` (Terminal) / `failed`
- **Trigger:** Order delivery + return window expiration (e.g. 7-day hold) → weekly settlement run.
- **Current frontend behavior:** Static numbers in `src/routes/seller.payouts.tsx`.
- **Expected backend authority:** Automated financial accounting engine calculating commission, deductions, and banking UTR.

---

## 54. Data Entities Map

Comprehensive inventory of all 23 database entities required to support the frontend:

| Entity Name | Primary Fields Observed | Relationships | Owner | Reader | Mutator | Sensitive Fields | Financial Fields | State Fields |
|---|---|---|---|---|---|---|---|---|
| `User` | `id`, `phone`, `email`, `role`, `createdAt` | HasOne `Profile`, HasMany `Order`, HasMany `Address` | System | Self, Admin | System | `phone`, `email` | None | `status` |
| `CustomerProfile` | `id`, `userId`, `name`, `email`, `phone`, `avatarUrl` | BelongsTo `User` | User | Self, Admin | Self, Admin | `phone`, `email` | None | None |
| `CustomerAddress` | `id`, `userId`, `fullName`, `phone`, `line1`, `line2`, `city`, `state`, `pincode`, `isDefault` | BelongsTo `User` | User | Self, Admin | Self | `phone`, `line1` | None | `isDefault` |
| `Brand` | `id`, `slug`, `name`, `city`, `state`, `story`, `logoUrl`, `isActive` | HasMany `Product`, HasMany `Designer` | Brand | Public | Admin, Brand | None | None | `isActive` |
| `Designer` | `id`, `slug`, `name`, `story`, `philosophy`, `brandId`, `avatarUrl` | BelongsTo `Brand`, HasMany `Product` | Designer | Public | Admin, Designer | None | None | `isActive` |
| `Category` | `id`, `slug`, `name`, `description`, `sortOrder` | HasMany `Subcategory`, HasMany `Product` | Platform | Public | Admin | None | None | None |
| `Subcategory` | `id`, `slug`, `categoryId`, `name`, `sortOrder` | BelongsTo `Category`, HasMany `Product` | Platform | Public | Admin | None | None | None |
| `Product` | `id`, `slug`, `title`, `description`, `brandId`, `designerId`, `categoryId`, `subcategoryId`, `price`, `compareAtPrice`, `composition`, `careInstructions`, `origin`, `madeToOrder`, `customizable`, `rating`, `reviewCount`, `status` | BelongsTo `Brand`, HasMany `ProductVariant`, HasMany `MediaAsset` | Seller / Brand | Public | Seller, Admin | None | `price`, `compareAtPrice` | `status` |
| `ProductVariant` | `id`, `productId`, `sku`, `size`, `color`, `price`, `compareAtPrice`, `barcode`, `weightGrams` | BelongsTo `Product`, HasOne `InventoryItem` | Seller | Public | Seller, Admin | None | `price`, `compareAtPrice` | `inStock` |
| `InventoryItem` | `id`, `variantId`, `quantityOnHand`, `quantityReserved`, `safetyStock` | BelongsTo `ProductVariant` | System | Seller, Admin | System, Seller | `quantityOnHand` | None | `lowStockAlert` |
| `InventoryReservation`| `id`, `variantId`, `quantity`, `quoteId`, `expiresAt`, `status` | BelongsTo `ProductVariant`, BelongsTo `CheckoutQuote` | System | System | System | None | None | `status` |
| `Cart` | `id`, `userId`, `sessionId`, `subtotal`, `updatedAt` | HasMany `CartLine` | User / Session | Self | Self | None | `subtotal` | None |
| `CartLine` | `id`, `cartId`, `productId`, `variantId`, `quantity`, `addedAt` | BelongsTo `Cart`, BelongsTo `ProductVariant` | User / Session | Self | Self | None | None | None |
| `WishlistItem` | `id`, `userId`, `productId`, `createdAt` | BelongsTo `User`, BelongsTo `Product` | User | Self | Self | None | None | None |
| `CheckoutQuote` | `id`, `userId`, `subtotal`, `shippingFee`, `discountAmount`, `taxAmount`, `totalPayable`, `expiresAt`, `status` | HasMany `CheckoutQuoteItem` | System | Self, Admin | System | None | `subtotal`, `shippingFee`, `totalPayable` | `status` |
| `Order` | `id`, `orderNumber`, `userId`, `customerName`, `customerPhone`, `customerEmail`, `deliveryAddressId`, `deliveryMethod`, `subtotal`, `shippingFee`, `discountAmount`, `totalAmount`, `paymentMethod`, `status`, `createdAt` | HasMany `OrderItem`, HasOne `PaymentTransaction`, HasMany `Shipment` | User | Self, Admin | System, Admin | `customerPhone`, `customerEmail` | `subtotal`, `shippingFee`, `totalAmount` | `status` |
| `OrderItem` | `id`, `orderId`, `sellerId`, `productId`, `variantId`, `title`, `brandName`, `size`, `color`, `unitPrice`, `quantity`, `lineTotal`, `sellerPayoutAmount`, `status` | BelongsTo `Order`, BelongsTo `ProductVariant`, BelongsTo `Seller` | Seller / Platform | Self, Seller, Admin | System, Seller, Admin | None | `unitPrice`, `lineTotal`, `sellerPayoutAmount` | `status` |
| `PaymentTransaction` | `id`, `orderId`, `gateway`, `gatewayOrderId`, `gatewayPaymentId`, `amount`, `currency`, `status`, `rawResponse`, `createdAt` | BelongsTo `Order` | System | Admin | System | `rawResponse` | `amount` | `status` |
| `Shipment` | `id`, `orderId`, `sellerId`, `carrier`, `trackingNumber`, `awb`, `status`, `estimatedDelivery`, `shippedAt`, `deliveredAt` | BelongsTo `Order`, BelongsTo `Seller` | Logistics | Self, Seller, Admin | System, Logistics | None | None | `status` |
| `Seller` | `id`, `brandId`, `businessName`, `gstin`, `pan`, `bankAccountNumber`, `bankIfsc`, `pickupPincode`, `commissionRate`, `status` | HasMany `Product`, HasMany `OrderItem`, HasMany `PayoutStatement` | Platform | Seller, Admin | Admin, Seller | `gstin`, `pan`, `bankAccountNumber` | `commissionRate` | `status` |
| `PayoutStatement` | `id`, `sellerId`, `periodStart`, `periodEnd`, `grossSales`, `commissionDeducted`, `logisticsDeducted`, `netAmount`, `utrNumber`, `status`, `paidAt` | BelongsTo `Seller` | Platform | Seller, Admin | Admin, System | `utrNumber` | `grossSales`, `commissionDeducted`, `netAmount` | `status` |
| `ProductReview` | `id`, `productId`, `userId`, `rating`, `title`, `body`, `isVerifiedPurchase`, `status`, `createdAt` | BelongsTo `Product`, BelongsTo `User` | User | Public | Admin, User | None | None | `status` |
| `MTORequest` | `id`, `referenceNumber`, `userId`, `productId`, `variantId`, `sellerId`, `customerName`, `customerPhone`, `measurements`, `notes`, `targetDate`, `status`, `quotePrice`, `createdAt` | BelongsTo `Product`, BelongsTo `Seller` | Customer & Seller | Self, Seller, Admin | Customer, Seller, Admin | `customerPhone`, `measurements` | `quotePrice` | `status` |

---

## 55. Financial Data & Authority Map

Every financial figure calculated, stored, or passed in the frontend:

| Financial Field | Frontend Location | Current Calculation Logic | Target Backend Authority | Unresolved Business Decision |
|---|---|---|---|---|
| **Product Price** | `products.ts`, `product.$productSlug.tsx` | Deterministically generated in mock array (₹1,111 – ₹15,000) | Immutable PostgreSQL `products.price` | None |
| **Compare at Price (MRP)** | `products.ts`, `product.$productSlug.tsx` | Procedurally generated MRP strictly greater than price | Immutable PostgreSQL `products.compare_at_price` | None |
| **Variant Price** | `variants.ts`, `ProductCard.tsx` | Equal to product price | PostgreSQL `product_variants.price` | None |
| **Cart Subtotal** | `src/routes/cart.tsx:29` | `lines.reduce((sum, l) => sum + product.price * l.quantity, 0)` | Recalculated server-side using current SKU prices | None |
| **Shipping Fee** | `cart.tsx:33`<br>`checkout.tsx:48`<br>`repositories/mock/index.ts:104` | **CONFLICTING:**<br>Cart: ₹149 if subtotal < ₹2,999<br>Checkout: ₹99 standard / ₹249 express<br>Mock: ₹99 flat | Calculated by server shipping tariff engine | **BLOCKED: Canonical shipping policy undefined (F-01)** |
| **Discounts / Coupons** | `checkout.tsx:22, 185` | Field exists in draft (`coupon: ""`); no calculation | Server validates coupon code, minimum spend, expiry | Coupon policy & rules |
| **Taxes (GST)** | `shipping.tsx`, `checkout.tsx` | Displayed as "Inclusive of all taxes" | Computed server-side per HSN code (e.g. 5% / 12% GST) | Tax breakdown display requirement |
| **Grand Total** | `cart.tsx:34`<br>`checkout.tsx:49` | `subtotal + shipping` | Authoritative quote generated by backend | Dependent on shipping decision |
| **Payment Amount** | `checkout.tsx:95` | Passes client `total` to mock order | Backend passes authoritative amount in paise to gateway | None |
| **Seller Line Payout** | `seller.payouts.tsx:18` | Static mock calculation (`price * 0.8`) | `item_price - (commission + GST + courier fee)` | Master commission schedule (%) |
| **Platform Commission** | Implied in seller routes | Not explicitly calculated | Platform fee deducted before seller ledger credit | Default commission % per category |
| **Refund Amount** | `returns.tsx` | Static policy text | Server-managed refund via payment gateway API | Return fee / freight deduction policy |

---

## 56. Security & Authority Map (Client → Server Trust Boundary)

This matrix defines the strict security boundary for backend engineers. The backend MUST NEVER trust client-supplied data in the fields below:

| Field Name | Frontend Sends? | Backend Trusts? | Backend Recalculates? | Backend Verifies? | Backend Ignores? | Rationale |
|---|---|---|---|---|---|---|
| `product.price` | YES (in cart/checkout state) | **NO** | **YES** | YES | YES | Client can modify DOM / localStorage to claim ₹1 price. Server must fetch price from PostgreSQL. |
| `item.quantity` | YES | **NO** | NO | **YES** | NO | Server must clamp integer 1..10 and verify against real inventory. |
| `shippingFee` | YES | **NO** | **YES** | YES | YES | Client cannot choose its own shipping rate. Server must evaluate subtotal against canonical rules. |
| `discountAmount` | YES | **NO** | **YES** | YES | YES | Server must authoritatively validate coupon codes. |
| `totalPayable` | YES | **NO** | **YES** | YES | YES | Server computes final charge passed to Razorpay. |
| `orderNumber` | YES (currently `DEMO-OG-XXXX`) | **NO** | **YES** | NO | **YES** | Client-generated order IDs discarded; server assigns sequence numbers (`OG-2026-XXXX`). |
| `orderStatus` | YES (currently sends `"placed"`) | **NO** | **YES** | NO | **YES** | Server state machine strictly dictates status progression upon payment verification. |
| `userId` | YES (in session draft) | **NO** | NO | **YES** | NO | Identity derived solely from verified JWT/session cookie (`auth.uid()`). |
| `userRole` | YES (checks `role = 'admin'` in UI) | **NO** | NO | **YES** | NO | Privileges checked via server JWT claims and database RLS. |
| `inventoryAvailability` | YES | **NO** | **YES** | **YES** | YES | Client-side modulo checks ignored; server checks actual database stock ledger. |
| `paymentStatus` | YES | **NO** | **YES** | **YES** | YES | Payment validity proved solely by gateway webhook HMAC SHA256 signature. |
| `payoutAmount` | YES (in seller views) | **NO** | **YES** | YES | YES | Ledger balance calculated server-side from settled transactions. |

---

## 57. External Services & Integrations

All external third-party integrations referenced by the OGURA frontend or implied by commerce operations:

| Service / Provider | Domain / Purpose | Frontend Evidence | Required Backend Integration | Webhook / Callback Required | Architectural Status |
|---|---|---|---|---|---|
| **Payment Gateway** (Candidate: Razorpay / Cashfree) | Process UPI, Cards, Netbanking | Radio buttons in `checkout.tsx:23` | Server-to-server API to create order; verify payment signatures | **YES** (`payment.captured`, `payment.failed`) | Candidate identified; needs final gateway selection. |
| **Media Storage & CDN** (Candidate: Cloudflare R2 / AWS S3) | Host catalog photography & thumbnails | Google Drive URLs in `productMediaRepository.ts` | Storage bucket with automated WebP compression and CDN distribution | NO | Immediate backend migration required from Google Drive. |
| **SMS / WhatsApp Gateway** (Candidate: Gupshup / Twilio) | Customer OTP auth & order status alerts | Phone input in `account.profile.tsx:31` | API to send 6-digit OTP and WhatsApp notification templates | **YES** (Delivery receipts) | Required for production authentication. |
| **Logistics / Courier API** (Candidate: Shiprocket / Delhivery) | Serviceability, live ETA, AWB tracking | Pincode input in `product.$productSlug.tsx:396` | Check delivery pincode, generate shipping labels, pull tracking events | **YES** (Status webhooks: Dispatched, In Transit, Delivered) | Required for real fulfillment. |
| **Transactional Email** (Candidate: Resend / SendGrid) | Order confirmation receipts, invoices | Email input in `checkout.tsx:18` | HTML email template delivery engine | NO | Standard commerce infrastructure. |

---

## 58. Frontend Conflicts & Open Contracts

| Conflict ID | Summary of Conflict | Exact Evidence in Code | Direct Impact on Backend | Architectural Decision Required |
|---|---|---|---|---|
| **CONF-01** | **Shipping Tariff Policy Mismatch** | `cart.tsx:33` (₹149 < ₹2,999)<br>`checkout.tsx:48` (₹99 standard / ₹249 express)<br>`repositories/mock/index.ts:104` (₹99 flat) | Backend cannot write shipping tariff engine until rate and threshold rules are canonically frozen. | Architect must specify: standard fee (₹99 vs ₹149), express fee (₹249), and if ₹2,999 threshold waives express. |
| **CONF-02** | **Nonexistent `/made-to-order/request` Route** | `mockMerchandising.ts:37, 43`<br>`product.$productSlug.tsx:389` | CTAs currently 404 in frontend. Backend cannot know whether to expect an intake form or concierge redirect. | Architect must specify destination: form route vs PLP redirect vs concierge link. |
| **CONF-03** | **Multi-Seller Cart Presentation Discrepancy** | `cart.tsx:58-110` (renders flat list)<br>`.lovable/plan/...:22` (specifies seller grouping) | Pure UI/UX issue, but affects whether orders are presented as one package or split shipments during checkout. | Architect must confirm whether frontend cart UI will be refactored to grouped presentation in Phase 2. |
| **CONF-04** | **Tax Calculation Ambiguity** | `checkout.tsx` displays total without tax line; `shipping.tsx` notes "inclusive of taxes" | Backend needs to know whether GST is inclusive in catalog price or calculated on top. | Confirm Indian GST inclusive catalog pricing model. |

---

## 59. Backend Handoff Summary & Readiness Assessment

# BACKEND HANDOFF STATUS: READY FOR CONTRACT FREEZE

The frontend forensic extraction, re-validation, and endpoint specification is 100% complete. All data touchpoints, state transitions, security boundaries, and financial fields have been reverse-engineered and mapped into unambiguous backend specifications.

### Summary Metrics:
- **Known Backend Operations Identified:** **36** (`BE-001` through `BE-036`)
- **Frontend Repositories Mapped:** **6** (Catalog, Cart, Wishlist, Account, Checkout, Media — 23 total methods)
- **Database Entities Identified:** **23** (From `User` and `CustomerProfile` to `Order`, `InventoryReservation`, and `MTORequest`)
- **State Machines Specified:** **8** (Order, Cart, Payment, Inventory, Auth, MTO, Seller Order, Payout)
- **Security Boundaries Identified:** **12** (Client → Server Trust Boundary rules)
- **Financial Operations Mapped:** **12** (All pricing, tax, shipping, discount, and commission rules)
- **External Integrations Identified:** **5** (Payments, Media Storage, SMS/OTP, Logistics, Email)

### Product Decisions Blocking Backend:
1. **Canonical Shipping Tariff (CONF-01):** Final rates for standard, express, and free shipping threshold.
2. **Made-to-Order Request Flow (CONF-02):** Destination and intake mechanism for `/made-to-order/request`.

### Frontend Defects Remaining:
- Zero unclassified frontend defects. All remaining non-blocking items are classified as Backend Dependencies, Product Decisions, UI/UX Locks, or Technical Debt.
  
