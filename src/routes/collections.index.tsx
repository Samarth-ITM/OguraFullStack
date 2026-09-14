import { createFileRoute, Link } from "@tanstack/react-router";
import { PRICE_COLLECTIONS, STYLE_COLLECTIONS } from "@/data/taxonomy";
import { collectionCount } from "@/repositories/mock/catalog";
import { CategoryTilePlaceholder } from "@/components/media/slots";
import { SectionHeading } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/collections/")({
  head: () => ({
    meta: [
      { title: "Collections — OGURA" },
      { name: "description", content: "Price-led and style-led collections across the OGURA catalogue." },
      { property: "og:title", content: "Collections — OGURA" },
      { property: "og:description", content: "Curated groupings by price band and by style." },
    ],
  }),
  component: CollectionsIndex,
});

function CollectionsIndex() {
  return (
    <div className="og-container py-12 lg:py-20">
      <SectionHeading as="h1" eyebrow="Browse" title="Collections" description="Grouped by price and by style." />

      {[
        { title: "By price", items: PRICE_COLLECTIONS },
        { title: "By style", items: STYLE_COLLECTIONS },
      ].map((group) => (
        <section key={group.title} className="mt-14">
          <h2 className="mb-6 text-[11px] uppercase tracking-[0.18em] text-secondary-text">{group.title}</h2>
          <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
            {group.items.map((c) => (
              <Link key={c.slug} to="/collections/$collectionSlug" params={{ collectionSlug: c.slug }} className="group block">
                <CategoryTilePlaceholder slotId={`collection.${c.slug}`} alt={c.title} label={c.title} />
                <p className="mt-3 text-sm uppercase tracking-[0.14em] group-hover:text-rose">{c.title}</p>
                <p className="text-xs text-muted-text">{collectionCount(c)} styles</p>
              </Link>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
