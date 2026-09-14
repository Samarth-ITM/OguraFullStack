import { createFileRoute } from "@tanstack/react-router";
import { ALL_COLLECTIONS } from "@/data/taxonomy";
import { collectionCount } from "@/repositories/mock/catalog";

export const Route = createFileRoute("/admin/merchandising")({
  head: () => ({
    meta: [
      { title: "Admin merchandising — OGURA" },
      { name: "description", content: "Mock merchandising overview of OGURA collections." },
      { property: "og:title", content: "Admin merchandising — OGURA" },
      { property: "og:description", content: "Mock merchandising overview." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AdminMerch,
});

function AdminMerch() {
  return (
    <ul className="grid gap-4 sm:grid-cols-2">
      {ALL_COLLECTIONS.map((collection) => (
        <li key={collection.slug} className="border border-border p-5">
          <p className="text-sm">{collection.title}</p>
          <p className="mt-1 text-xs text-secondary-text">{collection.description}</p>
          <p className="mt-3 text-[11px] uppercase tracking-[0.18em] text-muted-text">
            {collectionCount(collection)} styles
          </p>
        </li>
      ))}
    </ul>
  );
}
