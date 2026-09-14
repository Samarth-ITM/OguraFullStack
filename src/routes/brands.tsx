import { useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { mockDesigners } from "@/data/mockDesigners";
import { BrandLogoPlaceholder } from "@/components/media/slots";
import { OgInput, SectionHeading } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/brands")({
  head: () => ({
    meta: [
      { title: "Brands — OGURA" },
      { name: "description", content: "Every independent label stocked on OGURA, with their point of view." },
      { property: "og:title", content: "Brands — OGURA" },
      { property: "og:description", content: "Browse the labels behind the OGURA selection." },
    ],
  }),
  component: BrandsPage,
});

function BrandsPage() {
  const [q, setQ] = useState("");
  const list = mockDesigners.filter((b) => b.name.toLowerCase().includes(q.toLowerCase()));
  const grouped = list.reduce<Record<string, typeof list>>((acc, b) => {
    const key = (b.name[0] ?? "#").toUpperCase();
    (acc[key] ??= []).push(b);
    return acc;
  }, {});

  return (
    <div className="og-container py-12 lg:py-20">
      <SectionHeading as="h1" eyebrow="Directory" title="Brands" description={`${mockDesigners.length} labels on OGURA.`} />
      <div className="mt-8 max-w-sm">
        <label htmlFor="brand-search" className="sr-only">
          Search brands
        </label>
        <OgInput id="brand-search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search brands" />
      </div>

      {Object.keys(grouped)
        .sort()
        .map((letter) => (
          <section key={letter} className="mt-12">
            <h2 className="mb-5 font-display text-2xl text-rose">{letter}</h2>
            <div className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
              {(grouped[letter] ?? []).map((b) => (
                <Link key={b.slug} to="/brand/$brandSlug" params={{ brandSlug: b.slug }} className="group border border-border p-4">
                  <BrandLogoPlaceholder slotId={`brand.${b.slug}`} alt={b.name} label={b.name} showMeta={false} />
                  <p className="mt-3 text-sm uppercase tracking-[0.14em] group-hover:text-rose">{b.name}</p>
                  <p className="text-xs text-muted-text">
                    {b.location} · {b.productCount} styles
                  </p>
                </Link>
              ))}
            </div>
          </section>
        ))}

      {list.length === 0 ? <p className="mt-12 text-sm text-secondary-text">No brands match "{q}".</p> : null}
    </div>
  );
}
