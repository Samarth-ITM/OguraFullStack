import { createFileRoute, notFound } from "@tanstack/react-router";
import { OCCASIONS } from "@/data/taxonomy";
import { PlpEngine } from "@/components/plp/PlpEngine";
import { EmptyState, OgLinkButton } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/occasion/$occasionSlug")({
  loader: ({ params }) => {
    const occasion = OCCASIONS.find((o) => o.slug === params.occasionSlug);
    if (!occasion) throw notFound();
    return occasion;
  },
  head: ({ loaderData }) => {
    if (!loaderData) {
      return { meta: [{ title: "Occasion not found — OGURA" }, { name: "robots", content: "noindex" }] };
    }
    const title = `${loaderData.name} edit — OGURA`;
    const description = `Styles chosen for ${loaderData.name.toLowerCase()} from independent designers on OGURA.`;
    return {
      meta: [
        { title },
        { name: "description", content: description },
        { property: "og:title", content: title },
        { property: "og:description", content: description },
      ],
    };
  },
  component: OccasionPage,
  notFoundComponent: () => (
    <div className="og-container py-24">
      <EmptyState
        title="Occasion not found"
        body="Try one of the other occasion edits."
        action={<OgLinkButton to="/occasions">All occasions</OgLinkButton>}
      />
    </div>
  ),
});

function OccasionPage() {
  const occasion = Route.useLoaderData();
  return (
    <PlpEngine
      title={`${occasion.name}`}
      description="Occasion edit"
      crumbs={[{ label: "Home", to: "/" }, { label: "Occasions", to: "/occasions" }, { label: occasion.name }]}
      baseQuery={{ occasions: [occasion.slug] }}
      templateKey="shop"
    />
  );
}
