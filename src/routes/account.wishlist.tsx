import { createFileRoute } from "@tanstack/react-router";
import { productById } from "@/repositories/mock/catalog";
import { useOguraState } from "@/state/store";
import { ProductCard } from "@/components/commerce/ProductCard";
import { EmptyState, OgLinkButton } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/account/wishlist")({
  head: () => ({
    meta: [
      { title: "Account wishlist — OGURA" },
      { name: "description", content: "Pieces saved to your OGURA account." },
      { property: "og:title", content: "Account wishlist — OGURA" },
      { property: "og:description", content: "Pieces saved to your OGURA account." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AccountWishlist,
});

function AccountWishlist() {
  const ids = useOguraState((s) => s.wishlist);
  const products = ids.map((id) => productById.get(id)).filter((p): p is NonNullable<typeof p> => Boolean(p));

  if (products.length === 0) {
    return (
      <EmptyState
        title="Nothing saved yet"
        body="Tap the heart on any piece to keep it here."
        action={<OgLinkButton to="/shop">Shop all</OgLinkButton>}
      />
    );
  }

  return (
    <div className="grid grid-cols-2 gap-x-4 gap-y-10 xl:grid-cols-3">
      {products.map((p) => (
        <ProductCard key={p.id} product={p} />
      ))}
    </div>
  );
}
