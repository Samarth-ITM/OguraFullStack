import { useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { mockDesigners } from "@/data/mockDesigners";
import { DesignerPortraitPlaceholder } from "@/components/media/slots";
import { SectionHeading } from "@/components/ui-og/primitives";
import { cn } from "@/lib/utils";

const FILTERS = [
  { key: "all", label: "All" },
  { key: "new", label: "New on OGURA" },
  { key: "launchpad", label: "Launchpad" },
  { key: "trending", label: "Trending" },
] as const;

export const Route = createFileRoute("/designers")({
  head: () => ({
    meta: [
      { title: "Designers — OGURA" },
      { name: "description", content: "Meet the independent designers and studios behind the OGURA selection." },
      { property: "og:title", content: "Designers — OGURA" },
      { property: "og:description", content: "Independent labels, their locations and their point of view." },
    ],
  }),
  component: DesignersPage,
});

function DesignersPage() {
  const [filter, setFilter] = useState<(typeof FILTERS)[number]["key"]>("all");
  const list = mockDesigners.filter((d) =>
    filter === "all" ? true : filter === "new" ? d.isNew : filter === "launchpad" ? d.launchpad : d.trending,
  );

  return (
    <div className="og-container py-12 lg:py-20">
      <SectionHeading as="h1"
        eyebrow="The people behind the pieces"
        title="Designers"
        description={`${mockDesigners.length} independent studios in the prototype.`}
      />
      <div className="mt-8 flex flex-wrap gap-2">
        {FILTERS.map((f) => (
          <button
            key={f.key}
            type="button"
            onClick={() => setFilter(f.key)}
            aria-pressed={filter === f.key}
            className={cn(
              "min-h-11 border px-4 text-xs uppercase tracking-[0.14em]",
              filter === f.key ? "border-rose text-foreground" : "border-border text-secondary-text",
            )}
          >
            {f.label}
          </button>
        ))}
      </div>

      <div className="mt-10 grid grid-cols-2 gap-6 md:grid-cols-3 lg:grid-cols-4">
        {list.map((d) => (
          <Link key={d.slug} to="/designer/$designerSlug" params={{ designerSlug: d.slug }} className="group block">
            <DesignerPortraitPlaceholder slotId={`designer.${d.slug}`} alt={d.name} label={d.name} showMeta={false} />
            <p className="mt-3 text-sm uppercase tracking-[0.14em] group-hover:text-rose">{d.name}</p>
            <p className="text-xs text-muted-text">{d.location}</p>
            <p className="mt-2 line-clamp-2 text-xs text-secondary-text">{d.statement}</p>
          </Link>
        ))}
      </div>
      {list.length === 0 ? <p className="mt-12 text-sm text-secondary-text">No designers in this filter.</p> : null}
    </div>
  );
}
