import { createFileRoute } from "@tanstack/react-router";
import { productById } from "@/repositories/mock/catalog";
import { useOguraState } from "@/state/store";
import { ProductCard } from "@/components/commerce/ProductCard";
import { EmptyState, Eyebrow, OgLinkButton } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/wishlist")({
  head: () => ({
    meta: [
      { title: "Wishlist — OGURA" },
      { name: "description", content: "Pieces you have saved on OGURA." },
      { property: "og:title", content: "Wishlist — OGURA" },
      { property: "og:description", content: "Your saved OGURA pieces." },
    ],
  }),
  component: WishlistPage,
});

function WishlistPage() {
  const ids = useOguraState((s) => s.wishlist);
  const products = ids.map((id) => productById.get(id)).filter((p): p is NonNullable<typeof p> => Boolean(p));

  return (
    <div className="og-container py-10 lg:py-16">
      <Eyebrow>Saved</Eyebrow>
      <h1 className="mt-2 font-display text-4xl">Wishlist</h1>
      <p className="mt-2 text-sm text-secondary-text">{products.length} saved styles</p>

      {products.length === 0 ? (
        <div className="mt-10">
          <EmptyState
            title="Nothing saved yet"
            body="Tap the heart on any piece to keep it here."
            action={<OgLinkButton to="/shop">Shop all</OgLinkButton>}
          />
        </div>
      ) : (
        <div className="mt-10 grid grid-cols-2 gap-x-4 gap-y-10 md:grid-cols-3 xl:grid-cols-4">
          {products.map((p) => (
            <ProductCard key={p.id} product={p} />
          ))}
        </div>
      )}
    </div>
  );
}
