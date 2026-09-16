import { createFileRoute, notFound } from "@tanstack/react-router";
import { CATEGORY_BY_SLUG } from "@/data/taxonomy";
import { PlpEngine } from "@/components/plp/PlpEngine";
import { EmptyState, OgLinkButton } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/women/$categorySlug")({
  loader: ({ params }) => {
    const category = CATEGORY_BY_SLUG.get(params.categorySlug);
    if (!category) throw notFound();
    return { name: category.name, slug: category.slug };
  },
  head: ({ loaderData }) => {
    if (!loaderData) {
      return { meta: [{ title: "Category unavailable — OGURA" }, { name: "robots", content: "noindex" }] };
    }
    const title = `${loaderData.name} — OGURA`;
    const description = `Shop ${loaderData.name.toLowerCase()} from independent designers on OGURA.`;
    return {
      meta: [
        { title },
        { name: "description", content: description },
        { property: "og:title", content: title },
        { property: "og:description", content: description },
      ],
    };
  },
  component: CategoryPage,
  notFoundComponent: () => (
    <div className="og-container py-24">
      <EmptyState
        title="Category not found"
        body="That category doesn't exist in the prototype catalogue."
        action={<OgLinkButton to="/shop">Shop all</OgLinkButton>}
      />
    </div>
  ),
});

function CategoryPage() {
  const { name, slug } = Route.useLoaderData();
  return (
    <PlpEngine
      title={name}
      crumbs={[{ label: "Home", to: "/" }, { label: "Shop", to: "/shop" }, { label: name }]}
      baseQuery={{ category: slug }}
      templateKey={slug}
      chipBasePath={`/women/${slug}`}
    />
  );
}
