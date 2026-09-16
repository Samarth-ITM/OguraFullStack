import { createFileRoute, notFound } from "@tanstack/react-router";
import { COLLECTION_BY_SLUG } from "@/data/taxonomy";
import { PlpEngine } from "@/components/plp/PlpEngine";
import { EmptyState, OgLinkButton } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/collections/$collectionSlug")({
  loader: ({ params }) => {
    const collection = COLLECTION_BY_SLUG.get(params.collectionSlug);
    if (!collection) throw notFound();
    return collection;
  },
  head: ({ loaderData }) => {
    if (!loaderData) {
      return { meta: [{ title: "Collection not found — OGURA" }, { name: "robots", content: "noindex" }] };
    }
    const title = `${loaderData.title} — OGURA`;
    return {
      meta: [
        { title },
        { name: "description", content: loaderData.description },
        { property: "og:title", content: title },
        { property: "og:description", content: loaderData.description },
      ],
    };
  },
  component: CollectionPage,
  notFoundComponent: () => (
    <div className="og-container py-24">
      <EmptyState
        title="Collection not found"
        body="That collection isn't part of the prototype."
        action={<OgLinkButton to="/collections">All collections</OgLinkButton>}
      />
    </div>
  ),
});

function CollectionPage() {
  const collection = Route.useLoaderData();
  return (
    <PlpEngine
      title={collection.title}
      description={collection.description}
      crumbs={[{ label: "Home", to: "/" }, { label: "Collections", to: "/collections" }, { label: collection.title }]}
      baseQuery={{ collection: collection.slug }}
      templateKey="shop"
    />
  );
}
