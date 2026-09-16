import { useState } from "react";
import { Link, useNavigate } from "@tanstack/react-router";
import { Heart } from "lucide-react";
import { toast } from "sonner";
import type { Product } from "@/domain/catalog";
import { colorsFor, isLowStock, isSoldOut, variantsFor } from "@/repositories/mock/catalog";
import { addToCart, setBuyNow, toggleWishlist, useOguraState } from "@/state/store";
import { useUi } from "@/state/ui";
import { ProductImagePlaceholder } from "@/components/media/slots";
// TEMPORARY_DRIVE_MEDIA — migrate approved originals to owned storage before production.
import { CatalogProductImage } from "@/components/media/CatalogProductImage";
import { getPrimaryImage, getSecondaryImage, markImageFailed, renderableUrl } from "@/repositories/mock/productMediaRepository";
import { Skeleton } from "@/components/ui-og/primitives";
import { TrustLine } from "@/components/commerce/TrustBadges";
import { discountPct, formatINR } from "@/lib/format";
import { cn } from "@/lib/utils";


function badgeFor(product: Product, soldOut: boolean): string | null {
  if (soldOut) return "Sold Out";
  if (product.limited) return "Limited";
  if (product.newArrival) return "New";
  if (product.madeToOrder) return "Made to Order";
  if (product.launchpad) return "Launchpad";
  const d = discountPct(product.price, product.compareAtPrice);
  return d ? `${d}% off` : null;
}

export function ProductCardSkeleton() {
  return (
    <div className="space-y-3">
      <Skeleton className="aspect-[3/4] w-full" />
      <Skeleton className="h-3 w-20" />
      <Skeleton className="h-3 w-full" />
      <Skeleton className="h-3 w-16" />
    </div>
  );
}

export function ProductCard({ product }: { product: Product }) {
  const [pending, setPending] = useState<"cart" | "buy" | null>(null);
  const [added, setAdded] = useState(false);
  const [hover, setHover] = useState(false);
  const wishlisted = useOguraState((s) => s.wishlist.includes(product.id));
  const { openCart } = useUi();
  const navigate = useNavigate();

  const variants = variantsFor(product.id);
  const soldOut = isSoldOut(product.id);
  const lowStock = isLowStock(product.id);
  const colors = colorsFor(product.id);
  const badge = badgeFor(product, soldOut);
  const discount = discountPct(product.price, product.compareAtPrice);
  // TEMPORARY_DRIVE_MEDIA — migrate approved originals to owned storage before production.
  const primaryImage = getPrimaryImage(product.id);
  const secondaryImage = getSecondaryImage(product.id);
  const shown = hover && secondaryImage ? secondaryImage : primaryImage;

  const commitCart = (variantId: string) => {
    addToCart(product.id, variantId, 1);
    setAdded(true);
    setPending(null);
    openCart();
    toast.success("Added to bag", { description: product.title });
    window.setTimeout(() => setAdded(false), 2000);
  };

  const commitBuy = (variantId: string) => {
    setBuyNow({
      id: `buy-now-${variantId}`,
      productId: product.id,
      variantId,
      quantity: 1,
      addedAt: Date.now(),
    });
    setPending(null);
    void navigate({ to: "/checkout" });
  };

  const start = (action: "cart" | "buy") => {
    if (soldOut) return;
    const sellable = variants.filter((v) => v.availability !== "sold_out");
    const only = sellable[0];
    if (!product.requiresSize && sellable.length === 1 && only) {
      if (action === "cart") commitCart(only.id);
      else commitBuy(only.id);
      return;
    }
    setPending((p) => (p === action ? null : action));
  };

  const commit = (variantId: string) => {
    if (pending === "buy") commitBuy(variantId);
    else commitCart(variantId);
  };


  return (
    <article
      className="group relative flex flex-col"
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => {
        setHover(false);
        setPending(null);
      }}
    >
      <div className="relative">
        <Link
          to="/product/$productSlug"
          params={{ productSlug: product.slug }}
          className="block"
          aria-label={product.title}
        >
          {shown ? (
            <CatalogProductImage
              src={renderableUrl(shown)}
              alt={`${product.title} by ${product.brandName} — ${shown.imageRole.toLowerCase()} image`}
              imageRole={shown.imageRole}
              fallbackSlotId={`product.${product.id}.front`}
              fallbackLabel={`FRONT · ${product.id}`}
              onError={() => markImageFailed(shown)}
              className={cn(soldOut && "opacity-60")}
            />
          ) : (
            <ProductImagePlaceholder
              slotId={`product.${product.id}.${hover ? "alternate" : "front"}`}
              alt={`${product.title} by ${product.brandName}`}
              label={`${hover ? "ALT" : "FRONT"} · ${product.id}`}
              showMeta={false}
              className={cn(soldOut && "opacity-60")}
            />
          )}
        </Link>

        {badge ? (
          <span className="absolute left-0 top-0 bg-deep/85 px-2 py-1 text-[10px] uppercase tracking-[0.16em] text-foreground">
            {badge}
          </span>
        ) : null}

        <button
          type="button"
          onClick={() => toggleWishlist(product.id)}
          aria-pressed={wishlisted}
          aria-label={wishlisted ? `Remove ${product.title} from wishlist` : `Save ${product.title} to wishlist`}
          className="absolute right-1 top-1 grid size-11 place-items-center text-foreground/80 transition-colors hover:text-rose"
        >
          <Heart className={cn("size-4", wishlisted && "fill-rose text-rose")} />
        </button>

        {pending ? (
          <div className="absolute inset-x-0 bottom-0 border-t border-border bg-background/95 p-3 backdrop-blur">
            <p className="eyebrow mb-2">
              {pending === "buy" ? "Select a size to buy" : "Select a size"}
            </p>
            <div className="flex flex-wrap gap-1.5">
              {variants.map((v) => (
                <button
                  key={v.id}
                  type="button"
                  disabled={v.availability === "sold_out"}
                  onClick={() => commit(v.id)}
                  className="min-h-9 min-w-11 border border-border px-2 text-xs hover:border-rose disabled:line-through disabled:opacity-40"
                >
                  {v.size === "One Size" ? "One Size" : v.size}
                </button>
              ))}
            </div>
          </div>
        ) : null}

      </div>

      <div className="mt-3 space-y-1.5">
        <Link
          to="/brand/$brandSlug"
          params={{ brandSlug: product.brandSlug }}
          className="block text-[11px] uppercase tracking-[0.14em] text-muted-text hover:text-foreground"
        >
          {product.brandName}
        </Link>
        <Link
          to="/product/$productSlug"
          params={{ productSlug: product.slug }}
          className="line-clamp-2 text-[14px] leading-snug text-foreground hover:text-rose lg:text-[15px]"
        >
          {product.title}
        </Link>
        <div className="flex flex-wrap items-baseline gap-2">
          <span className="text-sm text-foreground">{formatINR(product.price)}</span>
          {discount ? (
            <>
              <span className="text-xs text-muted-text line-through">{formatINR(product.compareAtPrice!)}</span>
              <span className="text-xs text-rose">{discount}% off</span>
            </>
          ) : null}
        </div>
        {product.reviewCount >= 5 ? (
          <p className="text-xs text-secondary-text">
            {product.rating.toFixed(1)} ★ · {product.reviewCount} mock reviews
          </p>
        ) : null}
        {colors.length ? (
          <div className="flex items-center gap-1.5 pt-0.5">
            {colors.slice(0, 4).map((c) => (
              <span
                key={c.name}
                title={c.name}
                className="size-3 rounded-full border border-border-strong"
                style={{ backgroundColor: c.hex }}
              />
            ))}
            {colors.length > 4 ? <span className="text-xs text-muted-text">+{colors.length - 4} colours</span> : null}
          </div>
        ) : null}
        {lowStock && !soldOut ? <p className="text-xs text-warning">Low stock</p> : null}
        <TrustLine className="pt-1" />

        <div className="grid grid-cols-2 gap-2 pt-2">
          <button
            type="button"
            onClick={() => start("cart")}
            disabled={soldOut}
            className="min-h-11 border border-rose px-2 text-[10px] uppercase tracking-[0.08em] whitespace-nowrap text-rose transition-colors hover:bg-rose/10 disabled:cursor-not-allowed disabled:opacity-40"
          >
            {soldOut ? "Sold out" : added ? "Added ✓" : "Add to cart"}
          </button>
          <button
            type="button"
            onClick={() => start("buy")}
            disabled={soldOut}
            className="min-h-11 bg-rose px-2 text-[10px] uppercase tracking-[0.08em] whitespace-nowrap text-background transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
          >
            Buy now
          </button>
        </div>
      </div>

    </article>
  );
}
