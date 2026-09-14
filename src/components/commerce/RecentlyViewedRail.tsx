import { useOguraState } from "@/state/store";
import { productById } from "@/repositories/mock/catalog";
import { SectionHeading } from "@/components/ui-og/primitives";
import { ProductRail } from "./ProductRail";

export function RecentlyViewedRail({ excludeId }: { excludeId?: string }) {
  const ids = useOguraState((s) => s.recentlyViewed);
  const products = ids
    .filter((id) => id !== excludeId)
    .map((id) => productById.get(id))
    .filter((p): p is NonNullable<typeof p> => Boolean(p))
    .slice(0, 10);

  if (products.length < 2) return null;

  return (
    <section className="mt-20 border-t border-border pt-12">
      <SectionHeading eyebrow="Continue" title="Recently viewed" />
      <ProductRail products={products} perView={5} ariaLabel="Recently viewed" />
    </section>
  );
}
