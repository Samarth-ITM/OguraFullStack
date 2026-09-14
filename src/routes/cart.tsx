import { createFileRoute, Link } from "@tanstack/react-router";
import { Minus, Plus } from "lucide-react";
import { productById, variantsByProduct } from "@/repositories/mock/catalog";
import { removeCartLine, updateCartQuantity, useOguraState } from "@/state/store";
import { formatINR } from "@/lib/format";
import { CatalogProductThumb } from "@/components/media/CatalogProductImage";
import { EmptyState, Eyebrow, OgLinkButton } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/cart")({
  head: () => ({
    meta: [
      { title: "Your bag — OGURA" },
      { name: "description", content: "Review the pieces in your OGURA bag before checkout." },
      { property: "og:title", content: "Your bag — OGURA" },
      { property: "og:description", content: "Review your selected pieces." },
    ],
  }),
  component: CartPage,
});

export function useCartRows() {
  const lines = useOguraState((s) => s.cart.lines);
  return lines.flatMap((line) => {
    const product = productById.get(line.productId);
    const variant = (variantsByProduct.get(line.productId) ?? []).find((v) => v.id === line.variantId);
    return product && variant ? [{ line, product, variant }] : [];
  });
}

export function summarise(rows: ReturnType<typeof useCartRows>) {
  const subtotal = rows.reduce((sum, r) => sum + r.variant.price * r.line.quantity, 0);
  const mrp = rows.reduce((sum, r) => sum + (r.product.compareAtPrice ?? r.variant.price) * r.line.quantity, 0);
  const shipping = subtotal === 0 || subtotal >= 2999 ? 0 : 149;
  return { subtotal, savings: Math.max(0, mrp - subtotal), shipping, total: subtotal + shipping };
}

function CartPage() {
  const rows = useCartRows();
  const totals = summarise(rows);

  if (rows.length === 0) {
    return (
      <div className="og-container py-20">
        <EmptyState
          title="Your bag is empty"
          body="Explore the selection and add pieces you want to keep."
          action={
            <>
              <OgLinkButton to="/shop">Shop all</OgLinkButton>
              <OgLinkButton to="/wishlist" variant="secondary">
                View wishlist
              </OgLinkButton>
            </>
          }
        />
      </div>
    );
  }

  return (
    <div className="og-container py-10 lg:py-16">
      <Eyebrow>Bag</Eyebrow>
      <h1 className="mt-2 font-display text-4xl">Your bag ({rows.length})</h1>

      <div className="mt-10 grid gap-10 lg:grid-cols-[minmax(0,1fr)_340px]">
        <ul className="space-y-8">
          {rows.map(({ line, product, variant }) => (
            <li key={line.id} className="grid grid-cols-[100px_minmax(0,1fr)] gap-5 border-b border-border pb-8">
              <CatalogProductThumb productId={product.id} title={product.title} />
              <div className="min-w-0">
                <p className="text-xs uppercase tracking-[0.14em] text-muted-text">{product.brandName}</p>
                <Link to="/product/$productSlug" params={{ productSlug: product.slug }} className="text-sm hover:text-rose">
                  {product.title}
                </Link>
                <p className="mt-1 text-xs text-secondary-text">
                  {variant.size} · {variant.color}
                </p>
                <div className="mt-3 flex flex-wrap items-center gap-4">
                  <div className="flex items-center border border-border">
                    <button
                      type="button"
                      aria-label="Decrease quantity"
                      onClick={() => updateCartQuantity(line.id, line.quantity - 1)}
                      className="grid size-10 place-items-center"
                    >
                      <Minus className="size-3.5" />
                    </button>
                    <span className="w-8 text-center text-sm">{line.quantity}</span>
                    <button
                      type="button"
                      aria-label="Increase quantity"
                      onClick={() => updateCartQuantity(line.id, line.quantity + 1)}
                      className="grid size-10 place-items-center"
                    >
                      <Plus className="size-3.5" />
                    </button>
                  </div>
                  <span className="text-sm">{formatINR(variant.price * line.quantity)}</span>
                  <button
                    type="button"
                    onClick={() => removeCartLine(line.id)}
                    className="text-xs text-muted-text hover:text-error"
                  >
                    Remove
                  </button>
                </div>
              </div>
            </li>
          ))}
        </ul>

        <aside className="h-fit border border-border bg-surface p-6 lg:sticky lg:top-24">
          <h2 className="text-[11px] uppercase tracking-[0.18em]">Order summary</h2>
          <dl className="mt-5 space-y-3 text-sm">
            <div className="flex justify-between">
              <dt className="text-secondary-text">Subtotal</dt>
              <dd>{formatINR(totals.subtotal)}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-secondary-text">Savings</dt>
              <dd className="text-rose">−{formatINR(totals.savings)}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-secondary-text">Shipping</dt>
              <dd>{totals.shipping === 0 ? "Free" : formatINR(totals.shipping)}</dd>
            </div>
            <div className="flex justify-between border-t border-border pt-3 text-base">
              <dt>Total</dt>
              <dd>{formatINR(totals.total)}</dd>
            </div>
          </dl>
          <OgLinkButton to="/checkout" className="mt-6 w-full">
            Checkout
          </OgLinkButton>
          <p className="mt-3 text-xs text-muted-text">
            Prototype checkout — no payment is taken and no order is really placed.
          </p>
        </aside>
      </div>
    </div>
  );
}
