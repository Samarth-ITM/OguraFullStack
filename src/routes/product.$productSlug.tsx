import { useEffect, useMemo, useState } from "react";
import { createFileRoute, Link, notFound, useNavigate } from "@tanstack/react-router";
import { Heart, Minus, Plus, Truck } from "lucide-react";
import { toast } from "sonner";
import {
  colorsFor,
  isLowStock,
  isSoldOut,
  listProductsSync,
  productBySlug,
  variantsFor,
} from "@/repositories/mock/catalog";
import { galleryAngles } from "@/data/mediaSlots";
import { SLUG_BY_CATEGORY_NAME, SLUG_BY_SUBCATEGORY_NAME } from "@/data/taxonomy";
import { reviewsForProduct } from "@/data/mockReviews";
import { addToCart, pushRecentlyViewed, setBuyNow, toggleWishlist, useOguraState } from "@/state/store";
import { useUi } from "@/state/ui";
import { discountPct, formatINR } from "@/lib/format";
import { ProductImagePlaceholder, ReviewMediaPlaceholder } from "@/components/media/slots";
import { CatalogProductImage } from "@/components/media/CatalogProductImage";
import { getProductGallery, markImageFailed, renderableUrl } from "@/repositories/mock/productMediaRepository";
import { EmptyState, Eyebrow, OgButton, OgInput, OgLinkButton, SectionHeading } from "@/components/ui-og/primitives";
import { TrustPanel } from "@/components/commerce/TrustBadges";
import { ProductRail } from "@/components/commerce/ProductRail";
import { RecentlyViewedRail } from "@/components/commerce/RecentlyViewedRail";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/product/$productSlug")({
  loader: ({ params }) => {
    const product = productBySlug.get(params.productSlug);
    if (!product) throw notFound();
    return product;
  },
  head: ({ loaderData }) => {
    if (!loaderData) {
      return { meta: [{ title: "Product unavailable — OGURA" }, { name: "robots", content: "noindex" }] };
    }
    const title = `${loaderData.title} by ${loaderData.brandName} — OGURA`;
    const description = loaderData.shortDescription;
    return {
      meta: [
        { title: title.slice(0, 70) },
        { name: "description", content: description },
        { property: "og:title", content: title },
        { property: "og:description", content: description },
        { property: "og:type", content: "product" },
      ],
    };
  },
  component: ProductPage,
  notFoundComponent: () => (
    <div className="og-container py-24">
      <EmptyState
        title="Product not found"
        body="This piece isn't in the prototype catalogue."
        action={<OgLinkButton to="/shop">Shop all</OgLinkButton>}
      />
    </div>
  ),
});

function ProductPage() {
  const product = Route.useLoaderData();
  const navigate = useNavigate();
  const { openCart } = useUi();

  const variants = useMemo(() => variantsFor(product.id), [product.id]);
  const colors = useMemo(() => colorsFor(product.id), [product.id]);
  const sizes = useMemo(() => Array.from(new Set(variants.map((v) => v.size))), [variants]);

  const [color, setColor] = useState(colors[0]?.name ?? "");
  const [size, setSize] = useState<string | null>(sizes.length === 1 ? sizes[0] ?? null : null);
  const [qty, setQty] = useState(1);
  const [sizeError, setSizeError] = useState(false);
  const [pincode, setPincode] = useState("");
  const [eta, setEta] = useState<string | null>(null);
  const [activeImage, setActiveImage] = useState(0);
  const [tab, setTab] = useState<"details" | "size" | "shipping" | "designer">("details");

  const wishlisted = useOguraState((s) => s.wishlist.includes(product.id));

  useEffect(() => {
    pushRecentlyViewed(product.id);
    setSize(sizes.length === 1 ? sizes[0] ?? null : null);
    setColor(colors[0]?.name ?? "");
    setQty(1);
    setActiveImage(0);
  }, [product.id, sizes, colors]);

  const selected = variants.find((v) => v.size === (size ?? "") && (!color || v.color === color)) ??
    variants.find((v) => v.size === (size ?? ""));
  const soldOut = isSoldOut(product.id);
  const lowStock = isLowStock(product.id);
  const discount = discountPct(product.price, product.compareAtPrice);
  const angles = galleryAngles(product.category, product.subcategory);
  // TEMPORARY_DRIVE_MEDIA — migrate approved originals to owned storage before production.
  const gallery = getProductGallery(product.id);
  const categorySlug = SLUG_BY_CATEGORY_NAME.get(product.category) ?? "clothing";
  const subcategorySlug = SLUG_BY_SUBCATEGORY_NAME.get(product.subcategory) ?? "";
  const reviews = useMemo(() => reviewsForProduct(product.id, product.reviewCount), [product.id, product.reviewCount]);

  const similar = useMemo(
    () =>
      listProductsSync({ subcategory: SLUG_BY_SUBCATEGORY_NAME.get(product.subcategory) ?? "", limit: 999 }).items.filter((p) => p.id !== product.id).slice(0, 10),
    [product],
  );
  const fromBrand = useMemo(
    () => listProductsSync({ brandSlugs: [product.brandSlug], limit: 999 }).items.filter((p) => p.id !== product.id).slice(0, 10),
    [product],
  );

  const requireSize = () => {
    if (!size) {
      setSizeError(true);
      toast.error("Select a size to continue");
      return false;
    }
    return true;
  };

  const onAdd = () => {
    if (soldOut || !requireSize() || !selected) return;
    addToCart(product.id, selected.id, qty);
    openCart();
    toast.success("Added to bag", { description: product.title });
  };

  const onBuyNow = () => {
    if (soldOut || !requireSize() || !selected) return;
    setBuyNow({
      id: `buy-now-${selected.id}`,
      productId: product.id,
      variantId: selected.id,
      quantity: qty,
      addedAt: Date.now(),
    });
    navigate({ to: "/checkout" });
  };

  const checkPincode = () => {
    if (!/^\d{6}$/.test(pincode)) {
      setEta("Enter a valid 6-digit pincode (prototype check).");
      return;
    }
    const days = product.madeToOrder ? 14 : 4 + (Number(pincode[5]) % 4);
    setEta(`Mock estimate: delivery in ${days}–${days + 2} days. No live courier data in this prototype.`);
  };

  return (
    <div className="og-container py-6 lg:py-10">
      <nav aria-label="Breadcrumb" className="mb-6 text-xs text-muted-text">
        <ol className="flex flex-wrap items-center gap-2">
          <li>
            <Link to="/" className="hover:text-foreground">
              Home
            </Link>
          </li>
          <li aria-hidden>/</li>
          <li>
            <Link to="/women/$categorySlug" params={{ categorySlug }} className="hover:text-foreground">
              {product.category}
            </Link>
          </li>
          <li aria-hidden>/</li>
          <li>
            <Link
              to="/women/$categorySlug/$subcategorySlug"
              params={{ categorySlug, subcategorySlug }}
              className="hover:text-foreground"
            >
              {product.subcategory}
            </Link>
          </li>
          <li aria-hidden>/</li>
          <li className="text-secondary-text" aria-current="page">
            {product.title}
          </li>
        </ol>
      </nav>

      <div className="grid gap-10 lg:grid-cols-[minmax(0,1.15fr)_minmax(0,1fr)] lg:gap-16">
        {/* Gallery */}
        <div>
          <div className="hidden gap-3 lg:grid lg:grid-cols-2">
            {angles.map((angle, i) => {
              const img = gallery[i];
              return img ? (
                <CatalogProductImage
                  key={angle}
                  src={renderableUrl(img)}
                  alt={`${product.title} — ${img.imageRole.toLowerCase()} image`}
                  imageRole={img.imageRole}
                  priority={i === 0}
                  fallbackSlotId={`product.${product.id}.${angle}`}
                  fallbackLabel={`${angle.toUpperCase()} · ${product.id}`}
                  onError={() => markImageFailed(img)}
                />
              ) : (
                <ProductImagePlaceholder
                  key={angle}
                  slotId={`product.${product.id}.${angle}`}
                  alt={`${product.title} — ${angle} view`}
                  label={`${angle.toUpperCase()} · ${product.id}`}
                />
              );
            })}
          </div>
          <div className="lg:hidden">
            {gallery[activeImage] ? (
              <CatalogProductImage
                src={renderableUrl(gallery[activeImage]!)}
                alt={`${product.title} — ${gallery[activeImage]!.imageRole.toLowerCase()} image`}
                imageRole={gallery[activeImage]!.imageRole}
                priority={activeImage === 0}
                fallbackSlotId={`product.${product.id}.${angles[activeImage] ?? "front"}`}
                fallbackLabel={`${(angles[activeImage] ?? "front").toUpperCase()} · ${product.id}`}
                onError={() => markImageFailed(gallery[activeImage]!)}
              />
            ) : (
              <ProductImagePlaceholder
                slotId={`product.${product.id}.${angles[activeImage] ?? "front"}`}
                alt={`${product.title} — ${angles[activeImage]} view`}
                label={`${(angles[activeImage] ?? "front").toUpperCase()} · ${product.id}`}
              />
            )}
            <div className="mt-3 flex justify-center gap-2" role="tablist" aria-label="Product images">
              {angles.map((angle, i) => (
                <button
                  key={angle}
                  type="button"
                  role="tab"
                  aria-selected={i === activeImage}
                  aria-label={`View ${angle}`}
                  onClick={() => setActiveImage(i)}
                  className={cn("size-2 rounded-full", i === activeImage ? "bg-rose" : "bg-border-strong")}
                />
              ))}
            </div>
          </div>
        </div>

        {/* Buy box */}
        <div className="lg:sticky lg:top-24 lg:self-start">
          <Link
            to="/brand/$brandSlug"
            params={{ brandSlug: product.brandSlug }}
            className="text-xs uppercase tracking-[0.18em] text-muted-text hover:text-rose"
          >
            {product.brandName}
          </Link>
          <h1 className="mt-3 font-display text-3xl leading-tight lg:text-4xl">{product.title}</h1>

          {product.reviewCount >= 5 ? (
            <p className="mt-3 text-sm text-secondary-text">
              {product.rating.toFixed(1)} ★ · {product.reviewCount} mock reviews
            </p>
          ) : (
            <p className="mt-3 text-sm text-muted-text">No reviews yet in this prototype.</p>
          )}

          <div className="mt-5 flex flex-wrap items-baseline gap-3">
            <span className="text-2xl">{formatINR(product.price)}</span>
            {discount ? (
              <>
                <span className="text-sm text-muted-text line-through">{formatINR(product.compareAtPrice!)}</span>
                <span className="text-sm text-rose">{discount}% off</span>
              </>
            ) : null}
          </div>
          <p className="mt-1 text-xs text-muted-text">Inclusive of all taxes (prototype pricing)</p>

          {colors.length > 1 ? (
            <div className="mt-8">
              <p className="text-[11px] uppercase tracking-[0.18em]">
                Colour: <span className="text-secondary-text">{color}</span>
              </p>
              <div className="mt-3 flex flex-wrap gap-2">
                {colors.map((c) => (
                  <button
                    key={c.name}
                    type="button"
                    onClick={() => setColor(c.name)}
                    aria-pressed={color === c.name}
                    aria-label={c.name}
                    className={cn(
                      "size-9 rounded-full border-2",
                      color === c.name ? "border-rose" : "border-border",
                    )}
                    style={{ backgroundColor: c.hex }}
                  />
                ))}
              </div>
            </div>
          ) : null}

          <div className="mt-8">
            <div className="flex items-center justify-between">
              <p className="text-[11px] uppercase tracking-[0.18em]">Size</p>
              <button type="button" onClick={() => setTab("size")} className="text-xs text-rose hover:text-rose-hover">
                Size guide
              </button>
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              {sizes.map((s) => {
                const variant = variants.find((v) => v.size === s && (!color || v.color === color)) ?? variants.find((v) => v.size === s);
                const unavailable = !variant || variant.availability === "sold_out";
                return (
                  <button
                    key={s}
                    type="button"
                    disabled={unavailable}
                    aria-pressed={size === s}
                    onClick={() => {
                      setSize(s);
                      setSizeError(false);
                    }}
                    className={cn(
                      "min-h-11 min-w-14 border px-3 text-sm",
                      size === s ? "border-rose text-foreground" : "border-border text-secondary-text",
                      unavailable && "cursor-not-allowed line-through opacity-40",
                    )}
                  >
                    {s}
                  </button>
                );
              })}
            </div>
            {sizeError ? (
              <p role="alert" className="mt-2 text-xs text-error">
                Please select a size.
              </p>
            ) : null}
            {lowStock && !soldOut ? <p className="mt-2 text-xs text-warning">Low stock in this size range.</p> : null}
          </div>

          <div className="mt-8 flex items-center gap-4">
            <p className="text-[11px] uppercase tracking-[0.18em]">Quantity</p>
            <div className="flex items-center border border-border">
              <button
                type="button"
                onClick={() => setQty((q) => Math.max(1, q - 1))}
                aria-label="Decrease quantity"
                className="grid size-11 place-items-center"
              >
                <Minus className="size-4" />
              </button>
              <span className="w-10 text-center text-sm" aria-live="polite">
                {qty}
              </span>
              <button
                type="button"
                onClick={() => setQty((q) => Math.min(5, q + 1))}
                aria-label="Increase quantity"
                className="grid size-11 place-items-center"
              >
                <Plus className="size-4" />
              </button>
            </div>
          </div>

          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <OgButton onClick={onAdd} disabled={soldOut} className="flex-1">
              {soldOut ? "Sold out" : "Add to bag"}
            </OgButton>
            <OgButton onClick={onBuyNow} disabled={soldOut} variant="secondary" className="flex-1">
              Buy now
            </OgButton>
            <button
              type="button"
              onClick={() => toggleWishlist(product.id)}
              aria-pressed={wishlisted}
              aria-label={wishlisted ? "Remove from wishlist" : "Save to wishlist"}
              className="grid size-11 shrink-0 place-items-center border border-border hover:border-rose"
            >
              <Heart className={cn("size-4", wishlisted && "fill-rose text-rose")} />
            </button>
          </div>

          <TrustPanel className="mt-6" />



          {product.madeToOrder || product.customizable ? (
            <div className="mt-6 border border-border bg-surface p-4">
              <Eyebrow>Made to Order</Eyebrow>
              <p className="mt-2 text-sm text-secondary-text">
                This piece can be adapted with the studio — size, colour or detail.
              </p>
              <OgLinkButton to="/made-to-order/request" variant="quiet" className="mt-4">
                Start a request
              </OgLinkButton>
            </div>
          ) : null}

          <div className="mt-6 border border-border p-4">
            <label htmlFor="pincode" className="flex items-center gap-2 text-[11px] uppercase tracking-[0.18em]">
              <Truck className="size-4" /> Delivery estimate
            </label>
            <div className="mt-3 flex gap-2">
              <OgInput
                id="pincode"
                inputMode="numeric"
                value={pincode}
                onChange={(e) => setPincode(e.target.value.replace(/\D/g, "").slice(0, 6))}
                placeholder="6-digit pincode"
              />
              <OgButton variant="secondary" onClick={checkPincode}>
                Check
              </OgButton>
            </div>
            {eta ? (
              <p className="mt-3 text-xs text-secondary-text" aria-live="polite">
                {eta}
              </p>
            ) : null}
          </div>

          {/* Accordions / tabs */}
          <div className="mt-10 border-t border-border">
            {(
              [
                { key: "details", label: "Details & fabric" },
                { key: "size", label: "Size & fit" },
                { key: "shipping", label: "Shipping & returns" },
                { key: "designer", label: "About the designer" },
              ] as const
            ).map((section) => (
              <div key={section.key} className="border-b border-border">
                <button
                  type="button"
                  onClick={() => setTab(section.key)}
                  aria-expanded={tab === section.key}
                  className="flex min-h-14 w-full items-center justify-between text-left text-[11px] uppercase tracking-[0.18em]"
                >
                  {section.label}
                  <span aria-hidden>{tab === section.key ? "–" : "+"}</span>
                </button>
                {tab === section.key ? (
                  <div className="pb-5 text-sm text-secondary-text">
                    {section.key === "details" ? (
                      <div className="space-y-3">
                        <p>{product.longDescription}</p>
                        <dl className="grid grid-cols-2 gap-3 text-xs">
                          <div>
                            <dt className="text-muted-text">Material</dt>
                            <dd>{product.material}</dd>
                          </div>
                          <div>
                            <dt className="text-muted-text">Fit</dt>
                            <dd>{product.fit}</dd>
                          </div>
                          <div>
                            <dt className="text-muted-text">Aesthetic</dt>
                            <dd>{product.aesthetic}</dd>
                          </div>
                          <div>
                            <dt className="text-muted-text">Occasion</dt>
                            <dd className="capitalize">{product.occasion.replace(/-/g, " ")}</dd>
                          </div>
                        </dl>
                      </div>
                    ) : null}
                    {section.key === "size" ? (
                      <div className="space-y-3">
                        <p>Sizes available: {sizes.join(", ")}.</p>
                        <p>
                          Measurements in this prototype are indicative. Made-to-order pieces can be adjusted with the
                          studio.
                        </p>
                      </div>
                    ) : null}
                    {section.key === "shipping" ? (
                      <div className="space-y-3">
                        <p>Prototype shipping: dispatch in 2–4 days, no live courier integration.</p>
                        <p>Returns accepted within 7 days for ready-to-ship pieces. Made-to-order is final sale.</p>
                      </div>
                    ) : null}
                    {section.key === "designer" ? (
                      <div className="space-y-3">
                        <p>{product.brandName} — see the full label page for their point of view.</p>
                        <Link
                          to="/brand/$brandSlug"
                          params={{ brandSlug: product.brandSlug }}
                          className="text-rose hover:text-rose-hover"
                        >
                          Visit {product.brandName} →
                        </Link>
                      </div>
                    ) : null}
                  </div>
                ) : null}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Reviews */}
      <section className="mt-20 border-t border-border pt-12">
        <SectionHeading eyebrow="Feedback" title="Reviews" description="All reviews in this prototype are mock content." />
        {reviews.length === 0 ? (
          <p className="mt-6 text-sm text-secondary-text">No reviews yet for this piece.</p>
        ) : (
          <ul className="mt-8 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {reviews.slice(0, 6).map((r) => (
              <li key={r.id} className="border border-border p-5">
                <p className="text-sm">{r.rating.toFixed(1)} ★</p>
                <p className="mt-2 text-sm text-secondary-text">{r.body}</p>
                <p className="mt-3 text-xs text-muted-text">
                  {r.author} · {r.fitFeedback}
                </p>
                {r.hasMedia ? (
                  <div className="mt-3">
                    <ReviewMediaPlaceholder slotId={`review.${r.id}`} alt="Mock customer photo" label="MOCK" showMeta={false} />
                  </div>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </section>

      {similar.length ? (
        <section className="mt-20">
          <SectionHeading eyebrow="You may also like" title="Similar pieces" />
          <div className="mt-8">
            <ProductRail products={similar} perView={5} ariaLabel="Similar pieces" />
          </div>
        </section>
      ) : null}

      {fromBrand.length ? (
        <section className="mt-20">
          <SectionHeading eyebrow="Same studio" title={`More from ${product.brandName}`} />
          <div className="mt-8">
            <ProductRail products={fromBrand} perView={5} ariaLabel={`More from ${product.brandName}`} />
          </div>
        </section>
      ) : null}

      <RecentlyViewedRail excludeId={product.id} />

      {/* Mobile sticky bar */}
      <div className="fixed inset-x-0 bottom-14 z-40 flex gap-2 border-t border-border bg-background/95 p-3 backdrop-blur lg:hidden">
        <OgButton onClick={onAdd} disabled={soldOut} className="flex-1">
          {soldOut ? "Sold out" : "Add to bag"}
        </OgButton>
        <OgButton onClick={onBuyNow} disabled={soldOut} variant="secondary" className="flex-1">
          Buy now
        </OgButton>
      </div>
    </div>
  );
}
