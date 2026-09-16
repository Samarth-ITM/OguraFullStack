# OGURA — P5 IMPLEMENTATION REPORT
## CUSTOMER CART, WISHLIST & PERSISTENT ADDRESSES FOUNDATION

### 1. P5 Status
**P5 ACCEPTED**
All P5 backend foundation capabilities have been implemented, verified under comprehensive tenant/isolation testing, proven on clean database reproduction from P1 through P5, and certified with complete TypeScript and Vite build passes.

---

### 2. Tables Added / Modified
- **`public.customer_addresses`** (Enhanced):
  - Retained schema established in P1 (`id`, `user_id`, `full_name`, `phone`, `line1`, `line2`, `city`, `state`, `pincode`, `country`, `is_default`, `is_active`, `created_at`, `updated_at`).
  - Added unique partial index and automatic default lifecycle maintenance triggers.
- **`public.carts`** (Enhanced):
  - Retained P1 schema (`id`, `user_id`, `session_id`, `created_at`, `updated_at`).
  - Strict partial unique constraint enforcing at most one active cart per authenticated customer (`WHERE user_id IS NOT NULL`).
- **`public.cart_lines`** (Enhanced):
  - Retained P1 schema (`id`, `cart_id`, `variant_id`, `quantity`, `created_at`, `updated_at`).
  - Unique constraint `uq_cart_lines_cart_variant (cart_id, variant_id)` preventing duplicate variant rows.
  - Positive bounded check constraint `quantity >= 1 AND quantity <= 10`.
- **`public.customer_wishlist`** (Enhanced):
  - Retained P1 schema (`id`, `user_id`, `product_id`, `created_at`).
  - Unique constraint `uq_customer_wishlist_user_product (user_id, product_id)` preventing duplicate entries.

---

### 3. Constraints
- `uq_customer_single_default_address`: Partial unique index on `customer_addresses (user_id) WHERE is_default = true AND is_active = true`.
- `uq_carts_active_user`: Partial unique index on `carts (user_id) WHERE user_id IS NOT NULL`.
- `uq_cart_lines_cart_variant`: Unique constraint on `cart_lines (cart_id, variant_id)`.
- `chk_cart_line_quantity`: Check constraint `quantity >= 1 AND quantity <= 10` on `cart_lines`.
- `uq_customer_wishlist_user_product`: Unique constraint on `customer_wishlist (user_id, product_id)`.
- Foreign key constraints:
  - `cart_lines.cart_id` REFERENCES `carts(id)` ON DELETE CASCADE.
  - `cart_lines.variant_id` REFERENCES `product_variants(id)` ON DELETE CASCADE.
  - `customer_wishlist.user_id` REFERENCES `profiles(id)` ON DELETE CASCADE.
  - `customer_wishlist.product_id` REFERENCES `products(id)` ON DELETE CASCADE.

---

### 4. RLS Policies
- **`customer_addresses`**:
  - `p_addresses_customer_select`: Customer can view own addresses (`user_id = auth.uid()`), or `admin_support`.
  - `p_addresses_customer_insert`: Customer can insert own address (`user_id = auth.uid()`).
  - `p_addresses_customer_update`: Customer can update own address (`user_id = auth.uid()`), with check `user_id = auth.uid()`.
  - `p_addresses_customer_delete`: Customer can delete own address (`user_id = auth.uid()`).
- **`carts`**:
  - `p_carts_owner_select`: Authenticated customer can view own cart (`user_id = auth.uid()`), or session-bound guest cart.
  - `p_carts_owner_insert`: Customer can insert own cart.
  - `p_carts_owner_update`: Customer can update own cart.
  - `p_carts_owner_delete`: Customer can delete own cart.
- **`cart_lines`**:
  - `p_cart_lines_owner_select`: Line accessible only if parent cart is accessible by user.
  - `p_cart_lines_owner_insert`: Line insertable only into user's own cart.
  - `p_cart_lines_owner_update`: Line mutable only within user's own cart.
  - `p_cart_lines_owner_delete`: Line deletable only from user's own cart.
- **`customer_wishlist`**:
  - `p_wishlist_customer_select`: Customer can view own wishlist items (`user_id = auth.uid()`).
  - `p_wishlist_customer_insert`: Customer can add to own wishlist (`user_id = auth.uid()`).
  - `p_wishlist_customer_delete`: Customer can remove from own wishlist (`user_id = auth.uid()`).

---

### 5. RPCs / Functions
- `maintain_customer_default_address_before()`: BEFORE INSERT OR UPDATE trigger function enforcing user identity derivation from `auth.uid()` and pre-demoting existing active default before setting new default to avoid unique partial index collision.
- `maintain_customer_default_address_after()`: AFTER UPDATE OR DELETE trigger function promoting the most recently updated active address if the active default is deactivated or deleted.
- `set_default_customer_address(p_address_id UUID)`: Explicit atomic RPC for a customer to switch default address.
- `get_or_create_customer_cart()`: Idempotently retrieves or creates the authenticated customer's persistent cart.
- `get_customer_cart()`: Returns dynamic cart projection with live catalog prices from `product_variants.price_paise` (no secondary price store), brand metadata, line quantities, and dynamic subtotal.
- `add_to_customer_cart(p_variant_id UUID, p_quantity INTEGER)`: Upserts a cart item, validating positive quantity and clamping/rejecting > 10.
- `update_cart_line_quantity(p_line_id UUID, p_quantity INTEGER)`: Updates line quantity; deletes line if quantity <= 0.
- `remove_cart_line(p_line_id UUID)`: Removes a line from caller's cart.
- `clear_customer_cart()`: Clears all items in caller's cart.
- `merge_guest_cart(p_session_id VARCHAR)`: Merges guest cart lines into authenticated customer cart (`LEAST(10, existing + guest)`) and deletes guest cart.
- `toggle_wishlist_item(p_product_id UUID)`: Toggles wishlist state atomically for caller (`is_wishlisted` boolean return).
- `get_customer_wishlist()`: Returns full wishlist array with live product and brand information.

---

### 6. Cart Behavior
- **Identity Enforcement:** Authenticated cart is strictly bound to `auth.uid()`. Client cannot pass arbitrary `user_id`.
- **Pricing Authority:** Cart lines store only `(cart_id, variant_id, quantity)`. No static prices are stored in `cart_lines`. Every read query projects prices live from `product_variants.price_paise`. Catalog remains the single source of truth.
- **Quantity Invariants:** Checked at database level (`quantity BETWEEN 1 AND 10`). Calling `add_to_customer_cart` when item already exists increments quantity up to 10.

---

### 7. Guest Merge Behavior
- When an anonymous user logs in, frontend invokes `merge_guest_cart(session_id)`.
- If a variant exists in both guest cart and customer cart, quantities are summed with a ceiling of 10 (`LEAST(10, c.quantity + g.quantity)`).
- If a variant exists only in guest cart, it is re-assigned to the customer's cart.
- Upon completion, the guest cart is deleted (`DELETE FROM carts WHERE id = v_guest_cart_id`).
- Subsequent or repeated calls with the same `session_id` are no-ops (idempotent).

---

### 8. Address Behavior
- Fully private customer data.
- Enforces customer ownership via `user_id = auth.uid()`.
- Supports soft deactivation (`is_active = false`) and hard deletion.
- Sellers and anonymous users have zero access.

---

### 9. Default Address Invariant
- At database storage level, `uq_customer_single_default_address` strictly guarantees at most ONE active default address per customer.
- Automated triggers:
  - First active address created by a customer automatically becomes default.
  - Adding or promoting an address to default demotes all other active addresses for that customer.
  - Deactivating or deleting the active default automatically promotes the most recently updated active address.
  - Deactivating an address automatically clears its `is_default` flag.

---

### 10. Security Boundaries
- **Customer A vs Customer B:** Full isolation. RLS prevents reading, updating, or deleting another customer's cart, cart lines, wishlist, or addresses.
- **Seller Isolation:** Sellers cannot read or modify any customer cart, wishlist, or address records.
- **Anonymous Isolation:** Anonymous users cannot read any customer cart, wishlist, or address records.
- **Admin Boundaries:** Regular admin roles cannot read customer addresses or carts; only explicit `admin_support` can access addresses for customer service resolution.

---

### 11. P3 Regression Result
- **PASS**: Universal visibility checks preserved.
- Live products of active sellers remain visible to public/anon.
- Suspending a seller immediately hides their products from public visibility.
- Verified in Test L (`p5_customer_cart_wishlist_addresses_test.sql`).

---

### 12. Focused Test Result
Executed `supabase/tests/p5_customer_cart_wishlist_addresses_test.sql`:
- Assertion A & B (Customer Identity Isolation & Cart Ownership): **PASS**
- Assertion C & D (Cart Duplicate Prevention & Quantity Constraints): **PASS**
- Assertion E & F (Guest Cart Merge & Idempotency): **PASS**
- Assertion G & H (Wishlist Ownership & Duplicate Prevention): **PASS**
- Assertion I & J (Address Ownership & Single-Default Invariant): **PASS**
- Assertion K & L (Seller/Public Isolation & P3 Visibility Preservation): **PASS**
- Total Exit Code: `0` (Zero errors, zero assertion failures).

---

### 13. Clean Migration Reproduction
- Created clean temporary database `ogura_clean_p5`.
- Applied migrations in sequence:
  1. `20260915000000_ogura_p1_database_foundation.sql` (PASS)
  2. `20260915000001_ogura_p2_auth_identity_rls.sql` (PASS)
  3. `20260915000002_ogura_p3_catalog_taxonomy_visibility.sql` (PASS)
  4. `20260915000003_ogura_p4_seller_onboarding_kyc_payout_gate.sql` (PASS)
  5. `20260915000004_ogura_p5_customer_cart_wishlist_addresses.sql` (PASS)
- Ran `supabase/tests/p5_customer_cart_wishlist_addresses_test.sql` against `ogura_clean_p5`: **100% PASS** (all assertions A through L passed).
- Dropped `ogura_clean_p5`.

---

### 14. TypeScript Result
- Executed `npx tsc --noEmit`.
- Result: **0 errors**.

---

### 15. Build Result
- Executed `npm run build`.
- Client and Nitro SSR server bundle built successfully in 171ms.
- Result: **0 errors**.

---

### 16. External APIs Used
- **ZERO**: No Razorpay, email, SMS, or external APIs called.

---

### 17. Credentials Used
- **ZERO**: No production or sandbox external credentials consumed.

---

### 18. Explicit Limitations
- Cart does not compute order tax, shipping, or commission (deferred to P7/P8).
- Checkout, payment, inventory reservation, and order creation are not implemented (strictly out of scope for P5).
- Frontend UI/UX is completely frozen as per Section 1 instructions.

---

### 19. Exact Files Changed
- `supabase/migrations/20260915000004_ogura_p5_customer_cart_wishlist_addresses.sql` (NEW)
- `supabase/tests/p5_customer_cart_wishlist_addresses_test.sql` (NEW)
- `DOCS/p5_report.md` (NEW)
- Zero frontend files changed. Zero historical reports modified.
