import { createFileRoute, Link } from "@tanstack/react-router";
import { OCCASIONS } from "@/data/taxonomy";
import { filterProducts } from "@/repositories/mock/catalog";
import { CategoryTilePlaceholder } from "@/components/media/slots";
import { SectionHeading } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/occasions")({
  head: () => ({
    meta: [
      { title: "Shop by occasion — OGURA" },
      { name: "description", content: "Wedding guest, festive, party, brunch, date night, vacation, work and casual edits." },
      { property: "og:title", content: "Shop by occasion — OGURA" },
      { property: "og:description", content: "Find pieces for the evening you actually have." },
    ],
  }),
  component: OccasionsPage,
});

function OccasionsPage() {
  return (
    <div className="og-container py-12 lg:py-20">
      <SectionHeading as="h1" eyebrow="Edits" title="Shop by occasion" description="Eight edits across the catalogue." />
      <div className="mt-10 grid grid-cols-2 gap-4 lg:grid-cols-4">
        {OCCASIONS.map((o) => {
          const count = filterProducts({ occasions: [o.slug] }).length;
          return (
            <Link
              key={o.slug}
              to="/occasion/$occasionSlug"
              params={{ occasionSlug: o.slug }}
              className="group block"
            >
              <CategoryTilePlaceholder slotId={`occasion.${o.slug}`} alt={o.name} label={o.name} />
              <p className="mt-3 text-sm uppercase tracking-[0.14em] group-hover:text-rose">{o.name}</p>
              <p className="text-xs text-muted-text">{count} styles</p>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
