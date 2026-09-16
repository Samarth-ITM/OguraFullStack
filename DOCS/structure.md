# OGURA — Codebase File & Architecture Structure
**Version:** 1.0  
**Date:** 2026-09-15  
**Location:** `/DOCS/structure.md`  
**Repository:** `.` (repository root)

---

## 1. Architectural Architecture & Folder Map

```text
OguraMVP/
├── DOCS/                        # Technical documentation, forensic findings & backend contracts
├── public/                      # Static web assets served at root (/favicon.png, /robots.txt)
├── src/
│   ├── assets/                  # Bundled visual assets, campaign photography & imagery
│   ├── components/              # React UI components organized by domain
│   │   ├── commerce/            # E-commerce widgets (Cart drawer, Product cards, Rails)
│   │   ├── layout/              # Storefront shell (Header, Footer, MobileNav, SearchOverlay)
│   │   ├── media/               # Image rendering, aspect-ratio containers & placeholders
│   │   ├── plp/                 # Catalog listing engine, facets, filters & editorial cards
│   │   ├── ui/                  # Base Radix UI & Shadcn primitive components
│   │   └── ui-og/               # Ogura-tailored luxury design primitives (OgButton, OgInput)
│   ├── config/                  # Global application flags and navigation hierarchies
│   ├── data/                    # Master catalog datasets, generated models & mock content
│   │   └── generated/           # Parsed workbook outputs (311 styles, 1,463 variants)
│   ├── domain/                  # TypeScript domain entity and contract interfaces
│   ├── hooks/                   # Custom shared React hooks
│   ├── lib/                     # Utilities (storage, formatting, error reporting, cn helper)
│   ├── repositories/            # Data access abstraction layer
│   │   ├── contracts/           # Repository TypeScript interfaces
│   │   └── mock/                # In-memory mock implementations simulating network latency
│   ├── routes/                  # TanStack Start file-based routing tree (47 active routes)
│   ├── state/                   # Client state stores (React external store & UI context)
│   ├── router.tsx               # TanStack Router initialization & query client integration
│   ├── routeTree.gen.ts         # Automatically generated route hierarchy manifest
│   ├── server.ts                # Nitro SSR server handler entry point
│   ├── start.ts                 # TanStack Start client hydration entry point
│   └── styles.css               # Tailwind CSS v4 design tokens and global luxury stylesheet
├── .lovable/                    # Lovable platform project configuration & build specifications
├── components.json              # Shadcn component registry configuration
├── eslint.config.js             # Flat ESLint configuration with Prettier rules
├── package.json                 # Package metadata, dependencies and build scripts
├── tsconfig.json                # TypeScript compiler configuration (strict typing)
└── vite.config.ts               # Vite bundler, TanStack router plugin & Nitro configuration
```

---

## 2. Root Configuration & Project Files

| File Path | Description / Role |
|---|---|
| `AGENTS.md` | Lovable environment governance instructions warning against destructive git history rewrites. |
| `README.md` | Standard project readme outlining project origin, tech stack overview, and local development start instructions. |
| `package.json` | Project manifest defining dependencies (`@tanstack/react-start`, `@tanstack/react-router`, `react@19`, `tailwindcss@4`, `radix-ui`), scripts (`dev`, `build`, `preview`, `lint`, `format`), and overrides. |
| `package-lock.json` | Lockfile recording pinned dependency versions for deterministic npm installations. |
| `bun.lock` | Bun binary lockfile for local Bun package execution. |
| `bunfig.toml` | Configuration options for the Bun JavaScript runtime and package manager. |
| `tsconfig.json` | TypeScript configuration specifying `ESNext` target, bundler module resolution, path aliases (`@/*` -> `./src/*`), and strict type checking. |
| `vite.config.ts` | Vite bundler setup integrating `@tanstack/router-plugin`, `@tanstack/react-start`, and `@tailwindcss/vite`. |
| `eslint.config.js` | ESLint 9 flat configuration setting up React hooks rules, TypeScript parsing, and formatting rules. |
| `components.json` | Shadcn CLI configuration mapping UI primitives to `src/components/ui` with Tailwind CSS v4 variables. |
| `.gitignore` | Defines files ignored by Git (node_modules, `.output`, `.wrangler`, `.env`, temporary cache files). |
| `.prettierrc` | Prettier formatting configuration (single quotes, semicolons, print width). |
| `.prettierignore` | Specifies files excluded from automated Prettier runs. |

---

## 3. Documentation Directory (`/DOCS`)

| File Path | Description / Role |
|---|---|
| `DOCS/frontend.md` | Forensic analysis document (Sections 1–47) plus Part II (Sections 48–59) documenting complete technical architecture, 36 backend operations (`BE-001`–`BE-036`), state machines, and trust boundaries. |
| `DOCS/report.md` | Master Unified Executive and Backend Contract Report detailing verified fixes, 15 classified issues, financial authority maps, entity schemas, and readiness handoff. |
| `DOCS/structure.md` | This file: complete catalog and brief explanation of every file in the repository. |

---

## 4. Public Assets (`/public`)

| File Path | Description / Role |
|---|---|
| `public/favicon.png` | Storefront favicon icon displayed in browser tabs. |
| `public/robots.txt` | Standard search engine crawler instructions disallowing prototype internal routes from indexation. |

---

## 5. Core Framework & Bootstrap (`/src`)

| File Path | Description / Role |
|---|---|
| `src/start.ts` | Client-side hydration bootstrap for TanStack Start; mounts the router into DOM. |
| `src/server.ts` | Server-side rendering (SSR) entry point wrapping the TanStack Start handler for Nitro SSR. |
| `src/router.tsx` | Router factory creating TanStack Router instance with React Query client and default preload behaviors. |
| `src/routeTree.gen.ts` | Auto-generated route tree generated by `@tanstack/router-plugin` mapping all 47 files under `src/routes/`. |
| `src/styles.css` | Core stylesheet defining Tailwind CSS v4 `@theme` tokens (colors: `charcoal`, `wine`, `rose`, `sand`, `surface`, `border`; fonts: Cormorant Garamond and Manrope; custom utility classes). |

---

## 6. Global Configuration (`src/config/`)

| File Path | Description / Role |
|---|---|
| `src/config/appMode.ts` | Central prototype feature flags (`mock: true`, `frontendOnly: true`, `payments: false`, `uploads: false`, `auth: false`). |
| `src/config/navigation.ts` | Master navigation registry defining primary menu links (`PRIMARY_NAV`), shop-by-price bands, four-column footer links, and mobile bottom nav items. |

---

## 7. Domain Layer (`src/domain/`)

| File Path | Description / Role |
|---|---|
| `src/domain/catalog.ts` | TypeScript domain types for the public catalog: `Product`, `ProductVariant`, `Brand`, `Designer`, `Collection`, `Category`, `CatalogQuery`, and facet filters. |
| `src/domain/commerce.ts` | TypeScript commerce models: `Cart`, `CartLine`, `Address`, `CheckoutDraft`, `Order`, `OrderItem`, and `Profile`. |

---

## 8. Client State Management (`src/state/`)

| File Path | Description / Role |
|---|---|
| `src/state/store.ts` | Core external state store using React `useSyncExternalStore`. Manages cart lines, buy-now context, wishlist IDs, recently viewed styles, search history, checkout draft, profile, and orders with `localStorage` persistence. |
| `src/state/ui.tsx` | UI React Context managing transient presentation state: cart drawer open/close, mobile menu drawer, search overlay, and currency/locale settings. |

---

## 9. Data Repositories (`src/repositories/`)

| File Path | Description / Role |
|---|---|
| `src/repositories/index.ts` | Single entry point exporting active repository instances consumed throughout UI components and route loaders. |
| `src/repositories/contracts/index.ts` | Formal TypeScript repository interfaces: `CatalogRepository`, `CartRepository`, `WishlistRepository`, `AccountRepository`, `CheckoutRepository`. |
| `src/repositories/mock/index.ts` | In-memory mock implementations of all repository contracts operating against static catalog data and `localStorage`. |
| `src/repositories/mock/catalog.ts` | Mock catalog querying algorithms for multi-facet filtering, sorting, price range clamping, and pagination. |
| `src/repositories/mock/latency.ts` | Simulated network delay helper (`withLatency`) adding 150–300ms delay to mock promises to verify loading states. |
| `src/repositories/mock/productMediaRepository.ts` | Product photography data access layer; manages multi-angle galleries, primary/secondary thumbnails, and broken image telemetry logging. |

---

## 10. Data & Mock Catalogs (`src/data/`)

| File Path | Description / Role |
|---|---|
| `src/data/taxonomy.ts` | Master taxonomy definition declaring primary departments (`clothing`, `ethnicwear`, `footwear`, `accessories`), subcategories, size curves, and color lists. |
| `src/data/mediaSlots.ts` | Media slot definitions and aspect ratio targets for catalog images across desktop and mobile viewports. |
| `src/data/mockBrands.ts` | Static dataset containing 28 independent Indian craft ateliers and brands with story copy, origin city, and logos. |
| `src/data/mockDesigners.ts` | Static dataset containing 42 Indian designers with biographies, philosophies, and affiliated brand studio IDs. |
| `src/data/mockCollections.ts` | Curated collections (e.g. `under-2000`, `under-3000`, `festive-edit`, `handcrafted-silks`) with rule predicates. |
| `src/data/mockOccasions.ts` | Curated occasion edits (e.g. `festive`, `cocktail`, `day-wedding`, `vacation-resort`) with style keyword tags. |
| `src/data/mockHomepage.ts` | Structured content for all 15 homepage sections (hero carousel, brand rails, curations, testimonials, launchpad). |
| `src/data/mockMerchandising.ts` | Category banner copy and PLP editorial insert cards (slot 12 and slot 36 craft/service callouts). |
| `src/data/mockReviews.ts` | Procedural review generator synthesizing verified buyer ratings, titles, and body text for PDP mock reviews. |
| `src/data/generated/products.ts` | Generated TypeScript array containing all 311 master product style records compiled from the master workbook. |
| `src/data/generated/variants.ts` | Generated TypeScript array containing all 1,463 individual SKU variants with sizes, colors, and prices. |
| `src/data/generated/brands.ts` | Generated brand lookups and slug-to-ID mappings. |
| `src/data/generated/homepageMedia.ts` | Static mapping of homepage editorial images, campaign tiles, and desktop/mobile banners. |
| `src/data/generated/productMedia.json` | Manifest JSON associating each product ID with multi-angle image records and URLs. |
| `src/data/generated/productMedia.ts` | TypeScript interface wrapper and typed export for `productMedia.json`. |

---

## 11. Utilities & Shared Hooks (`src/lib/`, `src/hooks/`)

| File Path | Description / Role |
|---|---|
| `src/lib/storage.ts` | Safe browser `localStorage` read/write wrapper with JSON serialization, error fallback, and key constants (`KEYS`). |
| `src/lib/format.ts` | Currency and date formatting helpers (`formatINR` converting numbers to `₹X,XXX`, date string formatting). |
| `src/lib/utils.ts` | Standard Tailwind CSS class merge utility combining `clsx` and `tailwind-merge` (`cn(...)`). |
| `src/lib/error-capture.ts` | Global uncaught client-side exception and unhandled promise rejection listener. |
| `src/lib/error-page.ts` | Fallback error boundary layout rendering styled user-facing error dialogs. |
| `src/lib/lovable-error-reporting.ts` | Lovable environment telemetry reporting boundary for fatal render errors. |
| `src/hooks/use-mobile.tsx` | Responsive breakpoint hook querying `(max-width: 768px)` to trigger mobile UI adaptations. |

---

## 12. UI Components (`src/components/`)

### A. Ogura Design Primitives (`src/components/ui-og/`)
| File Path | Description / Role |
|---|---|
| `src/components/ui-og/primitives.tsx` | Custom luxury storefront primitives: `OgButton` (with primary, secondary, quiet variants), `OgLinkButton`, `OgInput`, `Eyebrow`, `SectionHeading`, and `EmptyState`. |

### B. Commerce Widgets (`src/components/commerce/`)
| File Path | Description / Role |
|---|---|
| `src/components/commerce/CartDrawer.tsx` | Slide-over cart drawer showing line items, quantity increment/decrement, free shipping progress bar, and checkout CTA. |
| `src/components/commerce/ProductCard.tsx` | Storefront product card featuring dual-image hover preview, badge hierarchy (New In, Low Stock, Handcrafted), price comparison, and Quick Add variant drawer. |
| `src/components/commerce/ProductRail.tsx` | Horizontal scrollable product rail used across homepage and PDP recommendations with smooth scroll triggers. |
| `src/components/commerce/RecentlyViewedRail.tsx` | Displays customer's locally tracked recently viewed products stored in `localStorage.ogura.recentlyViewed`. |
| `src/components/commerce/TrustBadges.tsx` | Trust and value proposition banner (Authentic Ateliers, Considered Luxury, Nationwide Delivery, Secure Payments). |

### C. Layout & Shell (`src/components/layout/`)
| File Path | Description / Role |
|---|---|
| `src/components/layout/Header.tsx` | Sticky transparent-to-solid storefront header with logo, primary navigation menu, desktop action icons (search, wishlist, account, cart), and mega-menus. |
| `src/components/layout/Footer.tsx` | 4-column storefront footer with brand narrative, newsletter signup, shop links, company information, and copyright notice. |
| `src/components/layout/MobileNav.tsx` | Mobile slide-out drawer navigation and bottom sticky navigation bar (Home, Shop, Wishlist, Bag, Account). |
| `src/components/layout/SearchOverlay.tsx` | Full-screen interactive search overlay with instant debounced autocomplete, recent search chips, and quick result links. |
| `src/components/layout/StaticPage.tsx` | Reusable layout shell for informational and legal content pages with hero header, breadcrumbs, and accordion sections. |

### D. Media & Images (`src/components/media/`)
| File Path | Description / Role |
|---|---|
| `src/components/media/CatalogProductImage.tsx` | Aspect-ratio constrained image component with lazy loading, WebP fallback, skeleton loader, and error fallback. |
| `src/components/media/Placeholder.tsx` | Local SVG placeholder generator rendering dark editorial wine-to-charcoal gradients when photography is unavailable. |
| `src/components/media/slots.tsx` | Slot container enforcing strict 3:4 portrait ratios and layout stability to prevent cumulative layout shifts (CLS). |

### E. Product Listing Engine (`src/components/plp/`)
| File Path | Description / Role |
|---|---|
| `src/components/plp/PlpEngine.tsx` | Core product listing engine powering all category, subcategory, search, and collection pages with 24-style batching and sorting. |
| `src/components/plp/FilterPanel.tsx` | Multi-facet filter sidebar and mobile filter drawer (Category, Price Range, Sizes, Colors, Brands, In-Stock, Made-to-Order). |
| `src/components/plp/EditorialInsert.tsx` | Editorial campaign cards injected after product cards 12 and 36 without displacing product grid slots. |
| `src/components/plp/usePlpQuery.ts` | Custom hook synchronizing URL search parameters with filter state, active sorting, pagination batches, and scroll position. |

### F. Base Shadcn / Radix Primitives (`src/components/ui/`)
Standard Radix UI and Shadcn foundational primitives tailored with Ogura Tailwind styling:
- `accordion.tsx`: Collapsible accordion sections (used on PDP details and FAQ pages).
- `alert-dialog.tsx`: Modal confirmation alerts.
- `alert.tsx`: Inline notification banners.
- `aspect-ratio.tsx`: Container maintaining fixed aspect ratios.
- `avatar.tsx`: User profile picture avatar.
- `badge.tsx`: Visual tag pills for categories and stock status.
- `breadcrumb.tsx`: Hierarchical breadcrumb navigation links.
- `button.tsx`: Base Radix button primitive.
- `calendar.tsx`: Date selection calendar.
- `card.tsx`: Base card container component.
- `carousel.tsx`: Embla carousel implementation for hero galleries.
- `chart.tsx`: Base charting primitives.
- `checkbox.tsx`: Form checkbox inputs for filters.
- `collapsible.tsx`: Expandable/collapsible content wrapper.
- `command.tsx`: Command palette primitive backing search autocomplete.
- `context-menu.tsx`: Desktop right-click contextual menus.
- `dialog.tsx`: Accessible modal dialog containers.
- `drawer.tsx`: Mobile slide-up drawer primitive (Vaul).
- `dropdown-menu.tsx`: Floating dropdown menus.
- `form.tsx`: React Hook Form integration components.
- `hover-card.tsx`: Informational hover tooltips.
- `input-otp.tsx`: One-time password (OTP) segmented input boxes.
- `input.tsx`: Text input field component.
- `label.tsx`: Form input labels.
- `menubar.tsx`: Desktop top-level menubar.
- `navigation-menu.tsx`: Accessible navigation bar with hover panels.
- `pagination.tsx`: Numeric page pagination controls.
- `popover.tsx`: Floating popover content containers.
- `progress.tsx`: Linear progress indicators (free shipping bar).
- `radio-group.tsx`: Radio button selector for checkout delivery and payment methods.
- `resizable.tsx`: Split pane resizable containers.
- `scroll-area.tsx`: Custom styled scrollbar container.
- `select.tsx`: Custom dropdown selector (PLP sort options).
- `separator.tsx`: Visual dividing rules.
- `sheet.tsx`: Slide-over sheet containers (Cart drawer, Mobile filters).
- `sidebar.tsx`: Collapsible application sidebar.
- `skeleton.tsx`: Animated pulsing skeleton placeholder for loading states.
- `slider.tsx`: Dual-thumb range slider for PLP price filtering.
- `sonner.tsx`: Toast notification provider and triggers.
- `switch.tsx`: Toggle switches (e.g. "In Stock Only").
- `table.tsx`: Data tables used in Seller and Admin dashboards.
- `tabs.tsx`: Tabbed navigation interfaces (PDP details/sizing/shipping tabs).
- `textarea.tsx`: Multi-line text inputs.
- `toggle-group.tsx`: Multi-button toggle bars (Size and Color selectors).
- `toggle.tsx`: Single toggle button.
- `tooltip.tsx`: Floating hover tooltips.

---

## 13. Application Routes (`src/routes/`)

Every route in the 47-route TanStack Start application:

### A. Root & Shell
| File Path | Route ID / URL | Description / Role |
|---|---|---|
| `src/routes/__root.tsx` | `/` (Root Layout) | Root application shell: loads fonts, injects global styles, mounts `QueryClientProvider`, `UiProvider`, `Header`, `Footer`, `MobileNav`, `CartDrawer`, and triggers client store `hydrate()`. |
| `src/routes/index.tsx` | `/` (Homepage) | Storefront homepage rendering all 15 editorial sections: Hero banners, Curated rails, Brand spotlights, Designer features, Price edits, and Newsletter. |

### B. Catalog & Discovery
| File Path | Route ID / URL | Description / Role |
|---|---|---|
| `src/routes/shop.tsx` | `/shop` | Master catalog storefront displaying all 311 styles with full filtering, sorting, and infinite pagination. |
| `src/routes/new-in.tsx` | `/new-in` | New arrivals catalog filtering for newly introduced styles across all categories. |
| `src/routes/women.$categorySlug.tsx` | `/women/$categorySlug` | Department PLP displaying products filtered by primary category (`clothing`, `ethnicwear`, `footwear`, `accessories`). |
| `src/routes/women.$categorySlug.$subcategorySlug.tsx` | `/women/$categorySlug/$subcategorySlug` | Subcategory PLP (e.g. `/women/clothing/dresses`, `/women/ethnicwear/sarees`). |
| `src/routes/product.$productSlug.tsx` | `/product/$productSlug` | Product Detail Page (PDP): 12-section layout, multi-angle gallery, variant selector, delivery estimator, designer bio, and mock reviews. |
| `src/routes/search.tsx` | `/search` | Dedicated search results page rendering filtered product listings matching keyword queries. |
| `src/routes/brands.tsx` | `/brands` | Directory index listing all 28 partner brands with origin cities and atelier narratives. |
| `src/routes/brand.$brandSlug.tsx` | `/brand/$brandSlug` | Brand atelier profile page showing brand heritage, founder story, and curated styles. |
| `src/routes/designers.tsx` | `/designers` | Directory index listing all 42 featured Indian designers. |
| `src/routes/designer.$designerSlug.tsx` | `/designer/$designerSlug` | Designer profile page showing creative biography, studio location, and curated designer styles. |
| `src/routes/collections.index.tsx` | `/collections` | Index listing curated thematic collections (price bands, seasonal curations, craft stories). |
| `src/routes/collections.$collectionSlug.tsx` | `/collections/$collectionSlug` | Collection PLP displaying styles matching specific curation criteria (e.g. `/collections/under-3000`). |
| `src/routes/occasions.tsx` | `/occasions` | Directory index of curated occasion dressing guides. |
| `src/routes/occasion.$occasionSlug.tsx` | `/occasion/$occasionSlug` | Occasion PLP (e.g. `/occasion/festive`, `/occasion/cocktail`) displaying styles tagged for the event. |
| `src/routes/made-to-order.tsx` | `/made-to-order` | Catalog listing featuring pieces crafted bespoke on demand (`madeToOrder: true`). |
| `src/routes/launchpad.tsx` | `/launchpad` | Editorial discovery page highlighting emerging new Indian designers and debut collections. |

### C. Commerce & Checkout
| File Path | Route ID / URL | Description / Role |
|---|---|---|
| `src/routes/cart.tsx` | `/cart` | Full cart page displaying line items, quantity adjusters, free delivery threshold banner, and order summary. |
| `src/routes/checkout.tsx` | `/checkout` | 5-step mock checkout flow: Contact info, Shipping address, Delivery method, Payment method selection, and Order review. |
| `src/routes/order.success.$orderId.tsx` | `/order/success/$orderId` | Order confirmation screen displaying simulated order number (`DEMO-OG-XXXX`), items purchased, and prototype notice. |
| `src/routes/wishlist.tsx` | `/wishlist` | Standalone customer wishlist page rendering saved products with Quick Add functionality. |
| `src/routes/track-order.tsx` | `/track-order` | Order tracking page accepting order number and phone/email to render shipment status and milestone timeline. |

### D. Customer Account
| File Path | Route ID / URL | Description / Role |
|---|---|---|
| `src/routes/account.tsx` | `/account` (Layout) | Account section layout with tabbed navigation (Overview, Profile, Orders, Addresses, Wishlist). |
| `src/routes/account.index.tsx` | `/account` (Overview) | Account overview dashboard showing recent orders, profile summary, and quick links. |
| `src/routes/account.profile.tsx` | `/account/profile` | Customer profile management page allowing local edits to name, email, and phone, with simulated sign-in/out. |
| `src/routes/account.orders.tsx` | `/account/orders` | Customer order history listing all previously placed orders stored in `localStorage`. |
| `src/routes/account.addresses.tsx` | `/account/addresses` | Delivery address book allowing customers to save and delete delivery destinations. |
| `src/routes/account.wishlist.tsx` | `/account/wishlist` | Wishlist view embedded inside the account dashboard hierarchy. |

### E. Seller Atelier Portal
| File Path | Route ID / URL | Description / Role |
|---|---|---|
| `src/routes/seller.tsx` | `/seller` (Layout) | Seller portal layout with client role check and navigation header (Dashboard, Products, Orders, Payouts). |
| `src/routes/seller.index.tsx` | `/seller` (Dashboard) | Seller overview metrics: gross sales, active styles, pending fulfillment count, and upcoming payout balance. |
| `src/routes/seller.products.tsx` | `/seller/products` | Seller catalog management listing styles, SKUs, inventory counts, and active statuses. |
| `src/routes/seller.orders.tsx` | `/seller/orders` | Seller order fulfillment table listing sub-orders and customer destinations. |
| `src/routes/seller.payouts.tsx` | `/seller/payouts` | Seller financial settlement view displaying past statements, deductions, and banking details. |
| `src/routes/seller-program.tsx` | `/seller-program` | Informational landing page for brands and ateliers seeking to join the OGURA marketplace. |

### F. Admin Control Plane
| File Path | Route ID / URL | Description / Role |
|---|---|---|
| `src/routes/admin.tsx` | `/admin` (Layout) | Admin portal layout with navigation header (Dashboard, Master Catalog, Master Orders, Merchandising). |
| `src/routes/admin.index.tsx` | `/admin` (Dashboard) | Platform-wide operational metrics: GMV, total order count, total active styles, and registered designers. |
| `src/routes/admin.catalog.tsx` | `/admin/catalog` | Master platform catalog moderation table showing all styles across all brands. |
| `src/routes/admin.orders.tsx` | `/admin/orders` | Master platform order ledger listing all orders placed across all customers. |
| `src/routes/admin.merchandising.tsx` | `/admin/merchandising` | Control panel for managing homepage campaigns and PLP editorial insert slots. |

### G. Informational & Legal
| File Path | Route ID / URL | Description / Role |
|---|---|---|
| `src/routes/about.tsx` | `/about` | Brand heritage and manifesto page explaining the OGURA marketplace philosophy. |
| `src/routes/careers.tsx` | `/careers` | Careers page detailing open positions and company culture. |
| `src/routes/contact.tsx` | `/contact` | Customer support contact details, concierge hours, and direct communication links. |
| `src/routes/gift-card.tsx` | `/gift-card` | Gift card purchase and balance check informational page. |
| `src/routes/help.tsx` | `/help` | Frequently asked questions (FAQs) covering ordering, sizing, shipping, and payments. |
| `src/routes/join-as-designer.tsx` | `/join-as-designer` | Onboarding application form and requirements for independent designers. |
| `src/routes/privacy.tsx` | `/privacy` | Privacy policy detailing data collection, cookies, and customer rights. |
| `src/routes/returns.tsx` | `/returns` | Returns and exchange policy outlining eligibility windows and reverse logistics terms. |
| `src/routes/shipping.tsx` | `/shipping` | Shipping policy page detailing standard delivery, express shipping, and made-to-order timelines. |
| `src/routes/stores.tsx` | `/stores` | Studio locations, offline partner ateliers, and showroom addresses. |
| `src/routes/terms.tsx` | `/terms` | Commercial terms and conditions governing marketplace purchases. |

---

## 14. Static Assets (`src/assets/`)

| File Path | Description / Role |
|---|---|
| `src/assets/ogura-wordmark.png.asset.json` | Asset metadata definition for the primary OGURA logo wordmark. |
| `src/assets/home/hero-desktop.jpg` | High-resolution editorial photography for desktop hero banner. |
| `src/assets/home/hero-mobile.jpg` | Vertical portrait crop editorial photography for mobile hero banner. |
| `src/assets/home/campaign-festive.jpg` | Editorial image for festive season campaign spotlight. |
| `src/assets/home/editorial-look.jpg` | Editorial mood photography showcasing designer styling. |
| `src/assets/home/tile-celebrity-fashion.jpg` | Visual tile for celebrity curation grid. |
| `src/assets/home/tile-designer-curations.jpg` | Visual tile for independent designer edit. |
| `src/assets/home/tile-festive-edit.jpg` | Visual tile for festive occasion dressing. |
| `src/assets/home/tile-instagram-boutiques.jpg` | Visual tile highlighting boutique ateliers. |
| `src/assets/home/tile-made-to-order.jpg` | Visual tile representing bespoke craftsmanship. |
| `src/assets/home/tile-pinterest-finds.jpg` | Visual tile for trending editorial aesthetics. |
