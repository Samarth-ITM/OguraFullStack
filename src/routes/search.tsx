import { createFileRoute, useLocation } from "@tanstack/react-router";
import { PlpEngine } from "@/components/plp/PlpEngine";

export const Route = createFileRoute("/search")({
  head: () => ({
    meta: [
      { title: "Search — OGURA" },
      { name: "description", content: "Search 311 design-led styles across the OGURA catalogue." },
      { property: "og:title", content: "Search — OGURA" },
      { property: "og:description", content: "Find pieces by title, designer, colour or category." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SearchPage,
});

function SearchPage() {
  const location = useLocation();
  const q = (location.search as { q?: string }).q ?? "";

  return (
    <PlpEngine
      title={q ? `Results for "${q}"` : "Search"}
      crumbs={[{ label: "Home", to: "/" }, { label: "Search" }]}
      baseQuery={{ q }}
      templateKey="shop"
    />
  );
}
