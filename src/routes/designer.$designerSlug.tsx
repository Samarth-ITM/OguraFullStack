import { createFileRoute, Link, notFound } from "@tanstack/react-router";
import { mockDesignerBySlug } from "@/data/mockDesigners";
import { listProductsSync } from "@/repositories/mock/catalog";
import { DesignerPortraitPlaceholder, EditorialBannerPlaceholder } from "@/components/media/slots";
import { EmptyState, Eyebrow, OgLinkButton, SectionHeading } from "@/components/ui-og/primitives";
import { ProductRail } from "@/components/commerce/ProductRail";

export const Route = createFileRoute("/designer/$designerSlug")({
  loader: ({ params }) => {
    const designer = mockDesignerBySlug.get(params.designerSlug);
    if (!designer) throw notFound();
    return designer;
  },
  head: ({ loaderData }) => {
    if (!loaderData) {
      return { meta: [{ title: "Designer not found — OGURA" }, { name: "robots", content: "noindex" }] };
    }
    const title = `${loaderData.name} — designer on OGURA`;
    return {
      meta: [
        { title },
        { name: "description", content: loaderData.statement },
        { property: "og:title", content: title },
        { property: "og:description", content: loaderData.statement },
      ],
    };
  },
  component: DesignerPage,
  notFoundComponent: () => (
    <div className="og-container py-24">
      <EmptyState
        title="Designer not found"
        body="That studio isn't in the prototype directory."
        action={<OgLinkButton to="/designers">All designers</OgLinkButton>}
      />
    </div>
  ),
});

function DesignerPage() {
  const designer = Route.useLoaderData();
  const products = listProductsSync({ brandSlugs: [designer.slug], limit: 999 }).items;

  return (
    <div className="og-container py-10 lg:py-16">
      <EditorialBannerPlaceholder
        slotId={`designer.${designer.slug}.hero`}
        alt={designer.name}
        label={`DESIGNER · ${designer.name}`}
      />
      <div className="mt-8 grid gap-10 lg:grid-cols-[280px_minmax(0,1fr)]">
        <div>
          <DesignerPortraitPlaceholder slotId={`designer.${designer.slug}`} alt={designer.name} label="PORTRAIT" />
        </div>
        <div>
          <Eyebrow>{designer.location}</Eyebrow>
          <h1 className="mt-2 font-display text-4xl lg:text-5xl">{designer.name}</h1>
          <p className="mt-4 max-w-2xl text-sm text-secondary-text">{designer.statement}</p>
          <h2 className="mt-8 text-[11px] uppercase tracking-[0.18em]">Point of view</h2>
          <p className="mt-2 max-w-2xl text-sm text-secondary-text">{designer.pointOfView}</p>
          <dl className="mt-8 grid grid-cols-2 gap-4 text-sm sm:grid-cols-4">
            <div>
              <dt className="text-xs text-muted-text">Established</dt>
              <dd>{designer.establishedYear}</dd>
            </div>
            <div>
              <dt className="text-xs text-muted-text">Styles</dt>
              <dd>{products.length}</dd>
            </div>
            <div>
              <dt className="text-xs text-muted-text">Type</dt>
              <dd className="capitalize">{designer.entityType}</dd>
            </div>
            <div>
              <dt className="text-xs text-muted-text">Launchpad</dt>
              <dd>{designer.launchpad ? "Yes" : "No"}</dd>
            </div>
          </dl>
          <div className="mt-8">
            <Link
              to="/brand/$brandSlug"
              params={{ brandSlug: designer.slug }}
              className="inline-flex min-h-11 items-center border border-border-strong px-5 text-[11px] uppercase tracking-[0.18em] hover:bg-hover"
            >
              Shop all {designer.name}
            </Link>
          </div>
        </div>
      </div>

      <section className="mt-16">
        <SectionHeading eyebrow="The work" title={`${designer.name} styles`} />
        <div className="mt-8">
          <ProductRail products={products.slice(0, 12)} perView={4} ariaLabel={`${designer.name} styles`} />
        </div>
      </section>
    </div>
  );
}
