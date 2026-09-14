import { createFileRoute, notFound } from "@tanstack/react-router";
import { mockDesignerBySlug } from "@/data/mockDesigners";
import { PlpEngine } from "@/components/plp/PlpEngine";
import { EmptyState, OgLinkButton } from "@/components/ui-og/primitives";
import { EditorialBannerPlaceholder } from "@/components/media/slots";

export const Route = createFileRoute("/brand/$brandSlug")({
  loader: ({ params }) => {
    const brand = mockDesignerBySlug.get(params.brandSlug);
    if (!brand) throw notFound();
    return brand;
  },
  head: ({ loaderData }) => {
    if (!loaderData) {
      return { meta: [{ title: "Brand not found — OGURA" }, { name: "robots", content: "noindex" }] };
    }
    const title = `${loaderData.name} — OGURA`;
    return {
      meta: [
        { title },
        { name: "description", content: loaderData.statement },
        { property: "og:title", content: title },
        { property: "og:description", content: loaderData.statement },
      ],
    };
  },
  component: BrandPage,
  notFoundComponent: () => (
    <div className="og-container py-24">
      <EmptyState
        title="Brand not found"
        body="That label isn't in the prototype directory."
        action={<OgLinkButton to="/brands">All brands</OgLinkButton>}
      />
    </div>
  ),
});

function BrandPage() {
  const brand = Route.useLoaderData();
  return (
    <div>
      <div className="og-container pt-8">
        <EditorialBannerPlaceholder slotId={`brand.${brand.slug}.hero`} alt={brand.name} label={`BRAND · ${brand.name}`} />
        <div className="mt-6 max-w-2xl">
          <p className="eyebrow">{brand.location}</p>
          <h1 className="mt-2 font-display text-4xl lg:text-5xl">{brand.name}</h1>
          <p className="mt-4 text-sm text-secondary-text">{brand.statement}</p>
          <p className="mt-2 text-sm text-muted-text">{brand.pointOfView}</p>
          <p className="mt-3 text-xs text-muted-text">
            Established {brand.establishedYear} · {brand.productCount} styles
            {brand.launchpad ? " · Launchpad label" : ""}
          </p>
        </div>
      </div>
      <PlpEngine
        title={`${brand.name} styles`}
        crumbs={[{ label: "Home", to: "/" }, { label: "Brands", to: "/brands" }, { label: brand.name }]}
        baseQuery={{ brandSlugs: [brand.slug] }}
        templateKey="shop"
      />
    </div>
  );
}
