import { createFileRoute, notFound } from "@tanstack/react-router";
import { CATEGORY_BY_SLUG } from "@/data/taxonomy";
import { PlpEngine } from "@/components/plp/PlpEngine";
import { EmptyState, OgLinkButton } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/women/$categorySlug/$subcategorySlug")({
  loader: ({ params }) => {
    const category = CATEGORY_BY_SLUG.get(params.categorySlug);
    const sub = category?.children.find((c) => c.slug === params.subcategorySlug);
    if (!category || !sub) throw notFound();
    return { category: category.name, categorySlug: category.slug, sub: sub.name, subSlug: sub.slug };
  },
  head: ({ loaderData }) => {
    if (!loaderData) {
      return { meta: [{ title: "Not found — OGURA" }, { name: "robots", content: "noindex" }] };
    }
    const title = `${loaderData.sub} — ${loaderData.category} — OGURA`;
    const description = `Shop ${loaderData.sub.toLowerCase()} from independent designers on OGURA.`;
    return {
      meta: [
        { title },
        { name: "description", content: description },
        { property: "og:title", content: title },
        { property: "og:description", content: description },
      ],
    };
  },
  component: SubcategoryPage,
  notFoundComponent: () => (
    <div className="og-container py-24">
      <EmptyState
        title="Not found"
        body="That subcategory doesn't exist in the prototype catalogue."
        action={<OgLinkButton to="/shop">Shop all</OgLinkButton>}
      />
    </div>
  ),
});

function SubcategoryPage() {
  const { category, categorySlug, sub, subSlug } = Route.useLoaderData();
  return (
    <PlpEngine
      title={sub}
      crumbs={[
        { label: "Home", to: "/" },
        { label: category, to: `/women/${categorySlug}` },
        { label: sub },
      ]}
      baseQuery={{ category: categorySlug, subcategory: subSlug }}
      templateKey={subSlug}
      showSubcategoryFilter={false}
    />
  );
}
