# OGURA P5 DEFECT REPAIR & FORENSIC AUDIT REPORT

**Patch Phase:** Post-P10 Forward Corrective Migration  
**File Created:** `supabase/migrations/20260916000000_ogura_p5_media_primary_rpc_fix.sql`  
**Timestamp:** 2026-09-16T04:44:00+05:30  
**Status:** REPAIRED & VERIFIED (Defect #1 and Defect #2 100% Repaired)  

---

## 1. Executive Summary

During the Phase 11 Real-Backend Integration Audit, two SQLSTATE `42703` (`column does not exist`) defects were identified in locked Phase 5 RPC functions:
1. **Defect #1 (Media Primary Image Predicate):** `public.get_customer_cart()` and `public.get_customer_wishlist()` queried `ma.is_primary = true`, but `public.media_assets` uses `ma.slot_role = 'primary'::public.media_slot_role`.
2. **Defect #2 (Product Variant Stock Column):** `public.get_customer_cart()` referenced `pv.stock_quantity`, but `public.product_variants` does not contain a `stock_quantity` column. Authoritative inventory is maintained exclusively in `public.inventory_items`.

### Governing Invariants:
- **P1–P10 historical migrations (`20260915000000*` through `20260915000009*`) remain 100% untouched and historically immutable.**
- **Both defects were repaired via a single forward migration:** `supabase/migrations/20260916000000_ogura_p5_media_primary_rpc_fix.sql`.
- **Zero schema alterations were made to `product_variants`:** No duplicate inventory columns were added; single source of truth in `public.inventory_items` was preserved.
- **Zero frontend UI/UX, route, or taxonomy changes were introduced.**

---

## 2. Forensic Analysis of Defect #1 & Repair

### Defect:
Both `public.get_customer_cart()` and `public.get_customer_wishlist()` in locked migration `20260915000004_ogura_p5_customer_cart_wishlist_addresses.sql` queried:
```sql
SELECT asset_url FROM public.media_assets ma
WHERE ma.product_id = p.id AND ma.is_primary = true
LIMIT 1
```

### Forensic Schema Audit:
- Inspected `\d public.media_assets`:
  The table designates primary imagery via:
  `slot_role USER-DEFINED (public.media_slot_role) NOT NULL DEFAULT 'primary'::media_slot_role`
  with constraint `WHERE slot_role = 'primary'::media_slot_role`.
- The table does **not** contain a column named `is_primary`.

### Forward Repair:
Updated `primary_image_url` subquery in both RPCs:
```sql
SELECT asset_url FROM public.media_assets ma
WHERE ma.product_id = p.id AND ma.slot_role = 'primary'::public.media_slot_role
LIMIT 1
```

---

## 3. Forensic Analysis of Defect #2 & Repair

### Defect:
In locked migration `20260915000004_ogura_p5_customer_cart_wishlist_addresses.sql`, line 230:
```sql
'stock_quantity', pv.stock_quantity
```
where `pv` is `public.product_variants`.

### Forensic Schema Audit:
- Inspected `\d public.product_variants`:
  Columns: `id`, `product_id`, `sku`, `size`, `color`, `price_paise`, `compare_at_price_paise`, `is_active`, `color_hex`, `created_at`, `updated_at`.
  Column `stock_quantity` does **not** exist on `public.product_variants`.
- Authoritative inventory authority: `public.inventory_items`:
  `variant_id UUID NOT NULL UNIQUE REFERENCES product_variants(id)`
  `quantity_on_hand INTEGER NOT NULL DEFAULT 0`
  `quantity_reserved INTEGER NOT NULL DEFAULT 0`
- Available stock definition established in Phase 3 (`get_public_product_by_slug`) and Phase 6 (`get_variant_available_stock`):
  Available = `GREATEST(COALESCE(ii.quantity_on_hand, 0) - COALESCE(ii.quantity_reserved, 0), 0)`
- Made-To-Order (MTO) convention established in Phase 6:
  MTO products (`p.is_made_to_order = true`) represent virtual infinite capacity without requiring physical stock, returning `999999`.

### Forward Repair:
Joined `inventory_items` in `public.get_customer_cart()`:
```sql
LEFT JOIN public.inventory_items ii ON ii.variant_id = cl.variant_id
```
and computed `stock_quantity`:
```sql
'stock_quantity', CASE
    WHEN p.is_made_to_order IS TRUE THEN 999999
    ELSE GREATEST(COALESCE(ii.quantity_on_hand, 0) - COALESCE(ii.quantity_reserved, 0), 0)
END
```

---

## 4. Verification & Test Suite Execution

### 4.1 Targeted P5 Assertions Suite (`supabase/tests/p5_defect2_stock_quantity_test.sql`)
10 out of 10 targeted assertions executed and passed:
1. **TEST I (Unauthenticated Access):** `get_customer_cart()` without `auth.uid()` raises SQLSTATE `42501`. -> **PASS**
2. **TEST F (Empty Cart):** Successfully returns `items_count: 0`, `lines: []` for user without a cart. -> **PASS**
3. **TEST A (Normal Stocked Variant):** On-hand = 15, Reserved = 0 -> `stock_quantity = 15`, `primary_image_url` resolved. -> **PASS**
4. **TEST B (Partially Reserved Inventory):** On-hand = 15, Reserved = 4 -> `stock_quantity = 11`. -> **PASS**
5. **TEST C (Zero Available Inventory):** On-hand = 5, Reserved = 5 -> `stock_quantity = 0`. -> **PASS**
6. **TEST D (Variant Without Inventory Row):**
   - Non-MTO without inventory row -> `stock_quantity = 0`. -> **PASS**
   - MTO variant without inventory row -> `stock_quantity = 999999`, `is_made_to_order = true`. -> **PASS**
7. **TEST E (Multi-Variant Cart):** Every line in multi-item cart independently returns exact available stock. -> **PASS**
8. **TEST G (Customer Wishlist):** `get_customer_wishlist()` succeeds, returning items with valid `primary_image_url`. -> **PASS**
9. **TEST H (Ownership Isolation):** Customer B calling `get_customer_cart()` cannot view Customer A's cart items. -> **PASS**
10. **TEST J (Cart Mutation Invariants):** `add_to_customer_cart`, `update_cart_line_quantity`, line removal at quantity 0 verified. -> **PASS**

### 4.2 Clean Database Migration Replay
- Created ephemeral fresh database `ogura_clean_test`.
- Applied all migrations strictly in chronological sequence:
  - `20260915000000` through `20260915000009` (P1–P10 historical migrations)
  - `20260916000000_ogura_p5_media_primary_rpc_fix.sql` (Forward corrective patch)
- Result: **All 11 migrations applied cleanly with 0 errors.**
- Ran targeted test suite against clean database: **10 / 10 PASS**.

### 4.3 Full Phase Regression Suites
- **P5 Base Suite (`p5_customer_cart_wishlist_addresses_test.sql`):** **PASS**
- **P4 KYC & Lifecycle Suite (`p4_seller_onboarding_kyc_test.sql`):** **PASS**
- **TypeScript Static Verification (`npx tsc --noEmit`):** **PASS (0 errors)**
- **Production Bundle Build (`npm run build`):** **PASS (Built in 188ms)**

---

## 5. Environment Verification Distinction

| Verification Tier | Transport Layer | Test Count | Result |
| :--- | :--- | :--- | :--- |
| **Local PostgreSQL** | Direct `psql` Unix socket | 10 Targeted, 4 Regression suites | **PASS (100%)** |
| **Local HTTP Server** | `http://127.0.0.1:54321` (Python dev server + `psycopg2`) | 17 Real Backend operations | **PASS (17/17, 100%)** |
| **Production Lovable Cloud** | Remote HTTPS Supabase Project | Pending Live Deployment | **Ready for Migration Apply** |

---

## 6. Conclusion & Status

Both Defect #1 and Defect #2 in locked Phase 5 RPCs are completely repaired via forward migration `20260916000000_ogura_p5_media_primary_rpc_fix.sql`.
Historical migrations P1–P10 were not modified.
The blocker on Phase 11 certification is resolved.
