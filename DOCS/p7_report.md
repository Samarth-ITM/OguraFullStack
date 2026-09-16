# OGURA P7 IMPLEMENTATION REPORT

## 1. Status

PASS

## 2. Financial Decisions Verified

Authoritative inspection of P1 schema, P6 migration, and PRD commerce invariants confirmed:

1. **Shipping Tariff & Free-Shipping Threshold Basis:**
   - **Threshold:** Gross merchandise subtotal $\ge ₹2,999$ (299,900 paise).
   - **Tariff Rule:**
     - If $\text{subtotal\_paise} \ge 299900$, $\text{shipping\_fee\_paise} = 0$ (Free).
     - If $\text{subtotal\_paise} < 299900$, $\text{shipping\_fee\_paise} = 9900$ (₹99.00 Standard Shipping).
   - **Authoritative Evidence:** P1 migration line 543: `Standard shipping = ₹99 (9900 paise) below ₹2,999 (299900 paise); free ≥ ₹2,999. Multi-seller: Charged ONCE at the parent order level.` Also matches frontend `checkout.tsx` (`subtotal >= 2999 ? 0 : 99`) and mock repository contract.

2. **Customer-Facing `tax_paise` Treatment:**
   - **Catalog Prices:** `product_variants.price_paise` is strictly tax-inclusive (GST inclusive MRP/selling price).
   - **Customer Billing:** No additional incremental tax is charged to the customer at checkout ($\text{tax\_paise} = 0$).
   - **Authoritative Evidence:** Customer invoice total equals product catalog prices plus shipping. Seller-level commission GST, statutory TCS 1%, and TDS 1% (Sec 194-O) deductions are accounted for inside `seller_sub_orders` during P8 post-order settlement, never double-charged to the customer.

3. **Discount Model:**
   - **MVP Model:** No active promotion/coupon engine exists in the P1-P6 schema.
   - **Treatment:** $\text{discount\_paise} = 0$. No coupon tables or arbitrary discounts invented.

## 3. Files Changed

1. `supabase/migrations/20260915000006_ogura_p7_checkout_authoritative_quote.sql` (P7 checkout & quote engine migration)
2. `supabase/tests/p7_checkout_quote_test.sql` (P7 automated acceptance test suite covering Assertions A through T)
3. `DOCS/p7_report.md` (P7 formal implementation and acceptance certification)

*(Zero modifications to P1–P6 migrations, zero frontend UI code changes, zero package/dependency modifications).*

## 4. Migration

`20260915000006_ogura_p7_checkout_authoritative_quote.sql`

## 5. Functions/RPCs

| Function | Purpose | Authority |
|---|---|---|
| `enforce_quote_immutability()` | Trigger function on `checkout_quotes` strictly preventing DELETE operations and preventing UPDATE to any financial columns (`subtotal_paise`, `discount_paise`, `shipping_fee_paise`, `tax_paise`, `total_payable_paise`, `user_id`) | Trigger (`BEFORE UPDATE OR DELETE`) |
| `create_checkout_quote(p_address_id UUID, p_custom_address JSONB)` | Server-authoritative checkout quote creation: validates cart, computes prices, resolves address, cancels old pending quotes, inserts quote, and atomically reserves inventory via P6 | `authenticated` (Customer) |
| `get_checkout_quote(p_quote_id UUID)` | Retrieves authoritative checkout quote and line item details; eagerly expires and releases stale pending quotes | `authenticated` (Quote Owner or Admin) |
| `cancel_checkout_quote(p_quote_id UUID)` | Cancels a pending quote and releases its reserved inventory back to availability via P6 | `authenticated` (Quote Owner or Admin) |

## 6. Quote Calculation

Calculated exclusively server-side using 64-bit integer paise (`BIGINT`):

$$\text{subtotal\_paise} = \sum_{i \in \text{cart\_lines}} (\text{quantity}_i \times \text{product\_variants.price\_paise}_i)$$

$$\text{discount\_paise} = 0$$

$$\text{shipping\_fee\_paise} = \begin{cases} 0 & \text{if } \text{subtotal\_paise} \ge 299900 \\ 9900 & \text{if } \text{subtotal\_paise} < 299900 \end{cases}$$

$$\text{tax\_paise} = 0$$

$$\text{total\_payable\_paise} = \text{subtotal\_paise} - \text{discount\_paise} + \text{shipping\_fee\_paise} + \text{tax\_paise}$$

Enforced by database table check constraint:
`chk_quote_total CHECK (total_payable_paise = subtotal_paise - discount_paise + shipping_fee_paise + tax_paise)`

## 7. Atomic Quote + Reservation

P7 orchestrates quote creation and P6 inventory reservation inside a single PostgreSQL transaction:

```
[Customer invokes create_checkout_quote]
                   │
                   ▼
       Validate Cart & Address
                   │
                   ▼
  Calculate Authoritative Pricing (Paise)
                   │
                   ▼
   Insert checkout_quotes (status: 'pending', TTL: 15m)
                   │
                   ▼
   Call P6 reserve_inventory_for_quote(quote_id, items)
       ├─ Row locks acquired on inventory_items (variant_id ASC)
       ├─ Stock availability checked (on_hand - reserved >= requested)
       └─ inventory_reservations inserted (status: 'held', quote_id: quote_id)
                   │
         ┌─────────┴─────────┐
         ▼                   ▼
     [Success]           [Failure] (e.g. Insufficient Inventory)
         │                   │
         ▼                   ▼
 Transaction Commit    Transaction Rollback (PostgreSQL MVCC)
   Quote + Holds         Neither Quote nor Reservation Persists
    are ACTIVE          (Zero Orphan Holds / Zero Ghost Quotes)
```

Because PostgreSQL rolls back all uncommitted DML upon an unhandled exception:
1. If reservation fails, the `checkout_quotes` insert is rolled back.
2. If quote creation fails, no reservation rows are inserted.
3. The P1 foreign key `inventory_reservations.quote_id REFERENCES checkout_quotes(id) NOT NULL` is preserved without any detachment.

## 8. Multi-Seller Behavior

- **Cart Aggregation:** Products from different sellers (e.g., Seller A + Seller B) are aggregated into **one unified parent checkout quote**.
- **Unified Shipping:** A single parent-level shipping fee is evaluated against the aggregate subtotal:
  - If $\sum \text{subtotal} \ge ₹2,999 \implies ₹0$ shipping.
  - If $\sum \text{subtotal} < ₹2,999 \implies ₹99$ shipping (once for the entire order, **never ₹99 per seller**).
- **Seller Sub-Orders:** Separation of line items into seller-specific fulfillment slices is deferred to Phase 8 (`orders` and `seller_sub_orders`).

## 9. Security

- **Customer Identity:** Resolved strictly from `auth.uid()`. Frontends cannot submit arbitrary `user_id` or `customer_id`.
- **Cart Tenancy:** The cart is queried via `WHERE user_id = auth.uid()`. Customer A cannot inspect, modify, or quote Customer B's cart.
- **Address Ownership:** `customer_addresses` is validated via `WHERE id = p_address_id AND user_id = auth.uid()`. Customer A cannot checkout to Customer B's address.
- **Client Manipulation Blocked:** `create_checkout_quote` accepts zero financial arguments (`p_subtotal`, `p_price`, `p_shipping`, `p_tax` do not exist). All numbers are queried from authoritative tables.
- **Row Level Security (RLS):** `checkout_quotes` permits `SELECT` only for `user_id = auth.uid()` or admin roles. Direct client `INSERT`, `UPDATE`, and `DELETE` are denied by RLS.
- **Database Immutability Trigger:** `trg_enforce_quote_immutability` strictly prohibits DELETE and prevents any UPDATE from altering `subtotal_paise`, `discount_paise`, `shipping_fee_paise`, `tax_paise`, `total_payable_paise`, or `user_id`.

## 10. Acceptance Results

Executed against `ogura_dev` via `supabase/tests/p7_checkout_quote_test.sql`:

| Test | Description | Result |
|---|---|---|
| **A** | Single seller checkout (correct pricing, subtotal, ₹99 shipping, total, P6 reservation held) | **PASS** |
| **B** | Multi-seller checkout (items from Seller A + Seller B grouped in single parent quote, single shipping charge) | **PASS** |
| **C** | ₹2,999 boundary test ($< ₹2,999 \implies ₹99$, $\ge ₹2,999 \implies ₹0$ free shipping) | **PASS** |
| **D–I** | Financial manipulation resistance (client cannot supply fake prices, subtotal, shipping, discount, tax, total) | **PASS** |
| **J** | Cart ownership isolation (Customer A cannot checkout Customer B's cart) | **PASS** |
| **K** | Address ownership isolation (Customer A cannot checkout Customer B's address) | **PASS** |
| **L** | Insufficient inventory rejection (rejected cleanly when requested quantity exceeds available stock) | **PASS** |
| **M** | Atomic rollback verification (when reservation fails, zero orphan quotes or reservations exist) | **PASS** |
| **N** | Quote persistence (database records match authoritative formula output) | **PASS** |
| **O** | Quote immutability (direct update to financial columns blocked by trigger) | **PASS** |
| **P** | Quote expiry lifecycle (quote expired after 15m; reservations released) | **PASS** |
| **Q** | Multi-buyer concurrency integration (P6 row locking protects concurrent checkout attempts) | **PASS** |
| **R** | RLS tenancy isolation (Bob cannot view or access Alice's quotes) | **PASS** |
| **S** | Financial invariants ($\text{subtotal}, \text{shipping}, \text{total} \ge 0$, check constraint satisfied) | **PASS** |
| **T** | P1–P6 regression suite (Cart, Catalog visibility, Seller lifecycle, P6 inventory engine intact) | **PASS** |

## 11. External Provider Usage

- External APIs called: **0**
- Credentials added: **0**
- Third-party packages added: **0**

## 12. P1-P6 Integrity

**PASS**
- Migrations `00` through `05` remain 100% untouched.
- Clean database installation from `00` to `06` verified and passed all tests.
- `npx tsc --noEmit`: 0 errors.
- `npm run build`: Clean production build.

## 13. Known Limitations

- Real payment gateway interaction (Razorpay order creation, payment signature verification, payment webhooks) belongs to Phase 8 (Order Placement & Razorpay Payment Engine).
- Seller sub-order splitting and commission accounting belong to Phase 8.

## 14. Final Checklist

- [x] Authoritative server-side pricing
- [x] Integer paise
- [x] Cart ownership
- [x] Address ownership
- [x] P6 reservation integration
- [x] Atomic quote + reservation
- [x] Shipping rule (₹99 below ₹2,999; ₹0 at/above ₹2,999)
- [x] Multi-seller shipping once
- [x] Discount handling (0 paise in MVP)
- [x] Tax handling (0 paise incremental customer tax)
- [x] Quote persistence
- [x] Quote immutability
- [x] Quote expiry
- [x] Client manipulation blocked
- [x] RLS isolation
- [x] Financial invariants
- [x] P1-P6 preserved
- [x] No payment
- [x] No external APIs
- [x] No credentials
- [x] Comprehensive P7 acceptance passed

============================================================

### P7 READY FOR P8
