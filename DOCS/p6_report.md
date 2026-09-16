# OGURA P6 IMPLEMENTATION REPORT

## 1. Status

PASS

## 2. Files Changed

1. `supabase/migrations/20260915000005_ogura_p6_inventory_reservation.sql` (P6 backend reservation engine migration)
2. `supabase/tests/p6_inventory_reservation_test.sql` (P6 automated acceptance test suite covering Assertions A through S)
3. `DOCS/p6_report.md` (P6 formal implementation and acceptance certification)

*(Zero modifications to P1–P5 migrations, zero frontend UI code changes, zero package/dependency modifications).*

## 3. Migration

`20260915000005_ogura_p6_inventory_reservation.sql`

## 4. Functions/RPCs

| Function | Purpose | Authority |
|---|---|---|
| `get_variant_available_stock(p_variant_id UUID)` | Returns genuinely purchasable stock (`quantity_on_hand - quantity_reserved` or 999999 for MTO) | `authenticated`, `anon` (Read-only `SECURITY DEFINER`) |
| `create_inventory_reservation(p_quote_id UUID, p_variant_id UUID, p_quantity INTEGER)` | Concurrency-safe atomic reservation with row lock, quote ownership validation, and quantity guard [1..10] | `authenticated` (Quote Owner or Admin) |
| `reserve_inventory_for_quote(p_quote_id UUID, p_items JSONB)` | Atomic multi-item batch reservation with deterministic `variant_id ASC` ordering to prevent deadlocks | `authenticated` (Quote Owner or Admin) |
| `release_inventory_reservation(p_reservation_id UUID)` | Restores reserved inventory and marks status `released`; strictly idempotent for already released/expired | `authenticated` (Quote Owner or Admin) |
| `release_quote_reservations(p_quote_id UUID)` | Batch releases all active reservations belonging to a quote | `authenticated` (Quote Owner or Admin) |
| `expire_inventory_reservation(p_reservation_id UUID)` | Restores reserved stock if `status = 'held'` and `expires_at < now()`, sets status `expired`; idempotent | `authenticated` (Background Worker / User / Admin) |
| `expire_stale_reservations(p_batch_limit INTEGER)` | Batch background sweep for expired reservations using `FOR UPDATE SKIP LOCKED` | `authenticated` (Cron / Worker / Admin) |
| `consume_inventory_reservation(p_reservation_id UUID)` | Transitions held reservation to `committed` (sold), atomically deducting `quantity_on_hand` and `quantity_reserved`; validates expiration under lock | `authenticated` (Payment / Order Workflow / Admin) |
| `consume_quote_reservations(p_quote_id UUID)` | Atomically consumes all held reservations for an approved checkout quote in `variant_id ASC` order | `authenticated` (Payment / Order Workflow / Admin) |

## 5. Reservation State Machine

```
               [create_inventory_reservation]
                           │
                           ▼
                       ┌───────┐
                       │ held  │ (Active reservation; 15-min TTL bound to quote)
                       └───────┘
                        /  │  \
                       /   │   \
[release_reservation] /    │    \ [consume_reservation]
                     /     │     \
                    ▼      │      ▼
          ┌──────────┐     │    ┌───────────┐
          │ released │     │    │ committed │ (Terminal: permanently sold)
          └──────────┘     │    └───────────┘
                           ▼
                      ┌─────────┐
                      │ expired │ (Terminal: TTL elapsed, stock returned)
                      └─────────┘
```

| Transition | Allowed Previous State | New State | Actor / Authority | Side Effects |
|---|---|---|---|---|
| Creation | *(none)* | `held` | Quote Owner / Admin | Increments `quantity_reserved`; binds 15-min TTL; writes `reservation_created` audit row |
| Release | `held` | `released` | Quote Owner / Admin | Decrements `quantity_reserved`; restores available stock; writes `reservation_released` audit row |
| Expiration | `held` (if `expires_at < now()`) | `expired` | Background Worker / System / User | Decrements `quantity_reserved`; restores available stock; writes `reservation_expired` audit row |
| Consumption | `held` (if `expires_at >= now()`) | `committed` | Payment / Order Authority | Permanently decrements `quantity_on_hand` AND `quantity_reserved`; writes `reservation_consumed` audit row |
| Duplicate Release | `released` / `expired` | `released` / `expired` | Any | Idempotent no-op; returns `true`; zero inventory modification |
| Duplicate Expiry | `expired` / `released` | `expired` / `released` | Any | Idempotent no-op; returns `false`; zero inventory modification |
| Duplicate Consumption | `committed` | `committed` | Payment / Order Authority | Idempotent no-op; returns `true`; zero inventory modification |
| Released → Committed | `released` | *Forbidden* | Any | Throws exception `42501` / `55000`; blocks consumption |
| Expired → Committed | `expired` | *Forbidden* | Any | Throws exception `55000`; blocks consumption |
| Committed → Released | `committed` | *Forbidden* | Any | Throws exception `55000`; prevents restoring sold stock |

## 6. Inventory Invariants

1. **Purchasable Available Stock:**
   $$\text{available\_stock} = \max(0, \text{quantity\_on_hand} - \text{quantity\_reserved})$$
   (For Made-to-Order items, returns 999999 as physical stock is not constrained).
2. **Database Check Constraint:**
   `chk_inventory_reserved_le_on_hand CHECK (quantity_on_hand >= quantity_reserved)`
   `quantity_on_hand >= 0` and `quantity_reserved >= 0`.
3. **Atomic Multi-Item Ordering:**
   Multi-item reservations sort lines by `variant_id ASC` before locking, eliminating transaction deadlocks.
4. **Permanent Deduction on Consumption:**
   When transitioning from `held` to `committed`:
   $$\text{quantity\_on_hand} \leftarrow \text{quantity\_on_hand} - \text{quantity}$$
   $$\text{quantity\_reserved} \leftarrow \text{quantity\_reserved} - \text{quantity}$$
   Total available stock remains unchanged (it was already withheld during reservation creation).
5. **No Double-Spending / No Negative Stock:**
   Direct updates are forbidden via RLS; mutations occur exclusively through database functions with explicit row locks.

## 7. Concurrency Model

- **Row-Level Mutual Exclusion:** When reserving physical stock, `inventory_items` is selected with `SELECT ... FROM public.inventory_items WHERE variant_id = p_variant_id FOR UPDATE`.
- **Serialization:** Any concurrent reservation attempts on the same SKU queue behind the lock. The second transaction observes the updated `quantity_reserved` and immediately fails with `insufficient_inventory` (`55000`) if requested quantity exceeds available stock.
- **Deadlock Immunity:** Multi-item reservations and quote-level consumptions sort items by `variant_id ASC` before acquiring row locks, ensuring a strict global lock acquisition hierarchy.
- **Race Condition Prevention:** In `consume_inventory_reservation`, the reservation row is locked with `FOR UPDATE OF ir`. The function validates `ir.expires_at >= CURRENT_TIMESTAMP` under lock. If the reservation expired milliseconds prior, consumption is strictly rejected even if the background cleanup worker has not yet transitioned the status to `'expired'`.

## 8. Expiry

- **Authoritative TTL:** Reservations are bound to checkout quote validity (15 minutes). `expires_at` is set directly to `v_quote_expires_at`.
- **Eager Check on Consumption:** `consume_inventory_reservation` actively rejects any reservation where `expires_at < CURRENT_TIMESTAMP`.
- **Asynchronous Worker:** `expire_stale_reservations(p_batch_limit)` sweeps expired rows using `FOR UPDATE SKIP LOCKED` without blocking active checkout operations.
- **Idempotency:** Calling `expire_inventory_reservation` on an already expired or released reservation returns `false` safely with zero changes to `inventory_items` and zero duplicate audit log entries.

## 9. Security

- **Quote & Customer Ownership:** Reservations require a valid `checkout_quotes.id`. `create_inventory_reservation` verifies `auth.uid() = checkout_quotes.user_id` unless the caller possesses `admin_catalog` or `admin_super`. Customer A cannot create, release, or view reservations under Customer B's quote.
- **Row Level Security (RLS):**
  - Table `inventory_reservations` enforces policy `p_reservations_customer_select`: customers may only read rows where `quote_id IN (SELECT id FROM checkout_quotes WHERE user_id = auth.uid())`.
  - Direct client `INSERT`, `UPDATE`, and `DELETE` on `inventory_reservations`, `inventory_items`, and `inventory_audit_log` are blocked. All writes go through `SECURITY DEFINER` procedures.
- **Audit Immutability:** Table `inventory_audit_log` is protected by trigger `trg_immutable_inventory_audit` prohibiting all UPDATE and DELETE operations. All mutations create immutable entries logging `variant_id`, `change_type`, `quantity_delta`, `quantity_on_hand_after`, `quantity_reserved_after`, `reference_id`, and `actor_id`.

## 10. Acceptance Results

Executed against `ogura_dev` via `supabase/tests/p6_inventory_reservation_test.sql`:

| Test | Description | Result |
|---|---|---|
| **A** | Basic reservation (10 stock, request 3 -> available becomes 7) | **PASS** |
| **B** | Insufficient stock (2 available, request 3 -> rejected, stock unchanged) | **PASS** |
| **C** | Exact stock (3 available, request 3 -> available becomes 0) | **PASS** |
| **D** | Oversell prevention (3 stock, concurrent 2 + 2 -> second rejected) | **PASS** |
| **E** | 100 buyers / 1 item concurrency simulation (100 attempts -> 1 success, 99 rejected) | **PASS** |
| **F** | Quantity boundaries (0, -1, 11 rejected; 1, 10 accepted) | **PASS** |
| **G** | Ownership isolation (Customer A cannot reserve against Customer B quote) | **PASS** |
| **H** | Active reservation release (returns reserved inventory to available stock) | **PASS** |
| **I** | Duplicate release idempotency (second release is safe no-op, no double release) | **PASS** |
| **J** | Expiration of stale reservation (restores reserved stock to available) | **PASS** |
| **K** | Duplicate expiry idempotency (second expiry is safe no-op, returns false) | **PASS** |
| **L** | Expired reservation consumption rejection (blocks order confirmation on expired hold) | **PASS** |
| **M** | Valid reservation consumption (permanently decrements on_hand and reserved stock) | **PASS** |
| **N** | Duplicate consumption idempotency (second call is safe no-op, stock not deducted twice) | **PASS** |
| **O** | Release consumed reservation protection (committed reservations cannot be released) | **PASS** |
| **P** | Payment/expiry race condition mutual exclusion (under lock, expired hold is rejected) | **PASS** |
| **Q** | Audit trail immutability and event recording | **PASS** |
| **R** | RLS tenancy isolation (customers cannot read other customer reservations or modify tables) | **PASS** |
| **S** | P1–P5 regression suite (P5 Cart, P3 Catalog visibility, P4 Seller lifecycle intact) | **PASS** |

## 11. 100-Buyer Test

- Target variant: Single physical unit (`quantity_on_hand = 1`, `quantity_reserved = 0`).
- Attempted reservations: **100**
- Successful reservations: **1**
- Failed reservations: **99**
- Final physical inventory state:
  - `quantity_on_hand`: 1
  - `quantity_reserved`: 1
  - `available_stock`: 0
- Overselling: **0 units**
- Audit log records created: **1** (`reservation_created`)

## 12. External Provider Usage

- External APIs called: **0**
- Credentials added: **0**
- Third-party packages added: **0**

## 13. P1-P5 Integrity

**PASS**
- Migrations `00` through `04` remain unchanged.
- `npx tsc --noEmit` passed with 0 errors.
- `npm run build` compiled without warnings or errors.
- Cart, product visibility, seller onboarding, KYC gating, and customer address lifecycles remain operational.

## 14. Known Limitations

- Real payment confirmation webhook orchestration belongs to Phase 8 (Order Placement & Razorpay Payment Engine). Phase 6 establishes the database-level lock and state transition contract (`consume_inventory_reservation` and `consume_quote_reservations`).
- Background cron orchestration for `expire_stale_reservations` relies on `pg_cron` or Supabase Edge Function scheduled invokes in production deployment.

## 15. Final Checklist

- [x] Atomic reservation implemented
- [x] Existing quote_id relationship preserved
- [x] Concurrency-safe
- [x] Oversell prevented
- [x] 100-buyer test passed
- [x] Quantity validation [1..10]
- [x] Reservation ownership enforced
- [x] Release implemented
- [x] Expiry implemented
- [x] Idempotent expiry
- [x] Consumption implemented
- [x] Idempotent consumption
- [x] Expired reservation cannot be consumed
- [x] Audit trail immutable and logged
- [x] RLS/security preserved
- [x] P1-P5 unchanged
- [x] No frontend changes
- [x] No external APIs
- [x] No credentials
- [x] P6 acceptance suite passed

============================================================

### P6 READY FOR P7
