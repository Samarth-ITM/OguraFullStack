import { Link } from "@tanstack/react-router";
import { X } from "lucide-react";
import { useFocusTrap, useUi } from "@/state/ui";
import { removeCartLine, useOguraState } from "@/state/store";
import { productById, variantsByProduct } from "@/repositories/mock/catalog";
import { CatalogProductThumb } from "@/components/media/CatalogProductImage";
import { OgLinkButton } from "@/components/ui-og/primitives";
import { formatINR } from "@/lib/format";

export function CartDrawer() {
  const { cartOpen, closeCart } = useUi();
  const lines = useOguraState((s) => s.cart.lines);
  const trapRef = useFocusTrap(cartOpen, closeCart);
  if (!cartOpen) return null;

  const rows = lines.flatMap((line) => {
    const product = productById.get(line.productId);
    const variant = (variantsByProduct.get(line.productId) ?? []).find((v) => v.id === line.variantId);
    return product && variant ? [{ line, product, variant }] : [];
  });
  const subtotal = rows.reduce((sum, r) => sum + r.variant.price * r.line.quantity, 0);

  return (
    <div className="fixed inset-0 z-[75]" role="dialog" aria-modal="true" aria-label="Shopping bag">
      <button type="button" aria-label="Close bag" className="absolute inset-0 bg-black/60" onClick={closeCart} />
      <div ref={trapRef} className="absolute inset-y-0 right-0 flex w-full max-w-md flex-col border-l border-border bg-background">
        <div className="flex items-center justify-between border-b border-border px-5 py-4">
          <h2 className="text-[11px] uppercase tracking-[0.18em]">Your bag ({rows.length})</h2>
          <button type="button" onClick={closeCart} aria-label="Close bag" className="grid size-11 place-items-center">
            <X className="size-5" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-4">
          {rows.length === 0 ? (
            <p className="py-16 text-center text-sm text-secondary-text">Your bag is empty.</p>
          ) : (
            <ul className="space-y-5">
              {rows.map(({ line, product, variant }) => (
                <li key={line.id} className="grid grid-cols-[72px_minmax(0,1fr)] gap-4">
                  <CatalogProductThumb productId={product.id} title={product.title} />
                  <div className="min-w-0">
                    <p className="text-xs text-muted-text">{product.brandName}</p>
                    <Link
                      to="/product/$productSlug"
                      params={{ productSlug: product.slug }}
                      onClick={closeCart}
                      className="line-clamp-2 text-sm hover:text-rose"
                    >
                      {product.title}
                    </Link>
                    <p className="mt-1 text-xs text-secondary-text">
                      {variant.size} · {variant.color} · Qty {line.quantity}
                    </p>
                    <div className="mt-2 flex items-center justify-between">
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
          )}
        </div>

        <div className="border-t border-border px-5 py-5">
          <div className="mb-4 flex items-center justify-between text-sm">
            <span className="text-secondary-text">Subtotal</span>
            <span>{formatINR(subtotal)}</span>
          </div>
          <div className="flex flex-col gap-2">
            <OgLinkButton to="/cart" variant="secondary">
              Go to bag
            </OgLinkButton>
            <OgLinkButton to="/checkout">Checkout</OgLinkButton>
          </div>
        </div>
      </div>
    </div>
  );
}
