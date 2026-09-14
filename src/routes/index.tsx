import { createFileRoute, Link } from "@tanstack/react-router";
import { useMemo } from "react";
import { listProductsSync } from "@/repositories/mock/catalog";
import { mockDesigners } from "@/data/mockDesigners";
import { EXPLORE_TILES, FOOTWEAR_SERVICES, PROMISE_ITEMS } from "@/data/mockHomepage";
import { PRICE_COLLECTIONS, STYLE_COLLECTIONS } from "@/data/taxonomy";
import {
  CampaignMediaPlaceholder,
  CategoryTilePlaceholder,
  DesignerPortraitPlaceholder,
  EditorialBannerPlaceholder,
  HeroMediaPlaceholder,
  HeroMobileMediaPlaceholder,
} from "@/components/media/slots";
import { Eyebrow, OgLinkButton, SectionHeading } from "@/components/ui-og/primitives";
import { ProductRail } from "@/components/commerce/ProductRail";
import { RecentlyViewedRail } from "@/components/commerce/RecentlyViewedRail";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "OGURA — Fashion that defines you" },
      {
        name: "description",
        content:
          "Discover 311 design-led styles from independent designers: clothing, ethnicwear, footwear and accessories, with made-to-order options.",
      },
      { property: "og:title", content: "OGURA — Fashion that defines you" },
      {
        property: "og:description",
        content: "A design-led fashion marketplace prototype featuring independent Indian designers.",
      },
    ],
  }),
  component: Home,
});

function Home() {
  const rails = useMemo(() => {
    const newIn = listProductsSync({ sort: "newest", limit: 12 }).items.slice(0, 12);
    const under3k = listProductsSync({ priceBands: ["1111-2999"], sort: "recommended" }).items.slice(0, 12);
    const ethnic = listProductsSync({ category: "ethnicwear", sort: "recommended" }).items.slice(0, 12);
    const accessories = listProductsSync({ category: "accessories", sort: "recommended" }).items.slice(0, 10);
    const footwear = listProductsSync({ category: "footwear", sort: "recommended" }).items.slice(0, 10);
    const mto = listProductsSync({ madeToOrder: true, sort: "recommended" }).items.slice(0, 10);
    return { newIn, under3k, ethnic, accessories, footwear, mto };
  }, []);

  const designers = mockDesigners.slice(0, 8);

  return (
    <div>
      {/* Hero */}
      <section className="relative">
        <HeroMediaPlaceholder
          slotId="home.hero"
          alt="OGURA campaign imagery"
          label="HOME HERO · 2400×1200"
          className="hidden lg:block"
        />
        <HeroMobileMediaPlaceholder
          slotId="home.hero.mobile"
          alt="OGURA campaign imagery"
          label="HOME HERO · 1080×1440"
          className="lg:hidden"
        />
        <div className="pointer-events-none absolute inset-0 flex items-end bg-gradient-to-t from-deep via-deep/40 to-transparent">
          <div className="og-container pointer-events-auto pb-10 lg:pb-16">
            <Eyebrow>Autumn / Winter Prototype</Eyebrow>
            <h1 className="mt-4 max-w-3xl font-display text-[clamp(2.5rem,7vw,5.5rem)] leading-[0.95]">
              Fashion that defines you.
            </h1>
            <p className="mt-4 max-w-xl text-sm text-secondary-text lg:text-base">
              311 styles from independent designers — clothing, ethnicwear, footwear and accessories,
              with made-to-order pieces shaped around you.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <OgLinkButton to="/shop">Shop the selection</OgLinkButton>
              <OgLinkButton to="/designers" variant="secondary">
                Meet the designers
              </OgLinkButton>
            </div>
          </div>
        </div>
      </section>

      {/* Promise strip */}
      <section className="border-y border-border bg-surface">
        <div className="og-container grid grid-cols-2 gap-6 py-8 lg:grid-cols-4">
          {PROMISE_ITEMS.map((item) => (
            <div key={item.title}>
              <p className="text-[11px] uppercase tracking-[0.18em] text-foreground">{item.title}</p>
              <p className="mt-2 text-xs text-secondary-text">{item.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Explore OGURA */}
      <section className="og-container py-16 lg:py-24">
        <SectionHeading
          eyebrow="Explore OGURA"
          title="Six ways into the wardrobe"
          description="Start from a category, a price, or a mood."
        />
        <div className="mt-10 grid grid-cols-2 gap-4 lg:grid-cols-3">
          {EXPLORE_TILES.map((tile) => (
            <Link key={tile.to} to={tile.to} className="group block">
              <CategoryTilePlaceholder slotId={tile.slotId} alt={tile.title} label={tile.title} />
              <div className="mt-3">
                <p className="text-sm uppercase tracking-[0.16em] text-foreground group-hover:text-rose">{tile.title}</p>
                <p className="mt-1 text-xs text-secondary-text">{tile.line}</p>
              </div>
            </Link>
          ))}
        </div>
      </section>

      {/* New In */}
      <section className="og-container pb-16 lg:pb-24">
        <SectionHeading
          eyebrow="Just arrived"
          title="New In"
          action={
            <OgLinkButton to="/new-in" variant="quiet">
              View all
            </OgLinkButton>
          }
        />
        <div className="mt-8">
          <ProductRail products={rails.newIn} perView={4} ariaLabel="New In" />
        </div>
      </section>

      {/* Designers */}
      <section className="border-y border-border bg-surface py-16 lg:py-24">
        <div className="og-container">
          <SectionHeading
            eyebrow="The people behind the pieces"
            title="Designers on OGURA"
            action={
              <OgLinkButton to="/designers" variant="quiet">
                All designers
              </OgLinkButton>
            }
          />
          <div className="og-rail mt-8 gap-4" style={{ gridAutoColumns: "minmax(220px, 1fr)" }}>
            {designers.map((d) => (
              <Link key={d.slug} to="/designer/$designerSlug" params={{ designerSlug: d.slug }} className="group block">
                <DesignerPortraitPlaceholder slotId={`designer.${d.slug}`} alt={d.name} label={d.name} />
                <p className="mt-3 text-sm uppercase tracking-[0.14em] group-hover:text-rose">{d.name}</p>
                <p className="mt-1 line-clamp-2 text-xs text-secondary-text">{d.statement}</p>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* Under 2999 */}
      <section className="og-container py-16 lg:py-24">
        <SectionHeading
          eyebrow="Shop by price"
          title="Design under ₹2,999"
          description="202 of our 311 styles sit in this band."
          action={
            <OgLinkButton to="/collections/under-3000" variant="quiet">
              View all
            </OgLinkButton>
          }
        />
        <div className="mt-8">
          <ProductRail products={rails.under3k} perView={5} ariaLabel="Design under 2999" />
        </div>
        <div className="mt-8 flex flex-wrap gap-2">
          {PRICE_COLLECTIONS.map((c) => (
            <Link
              key={c.slug}
              to="/collections/$collectionSlug"
              params={{ collectionSlug: c.slug }}
              className="border border-border px-4 py-2 text-xs uppercase tracking-[0.14em] text-secondary-text hover:border-rose hover:text-foreground"
            >
              {c.title}
            </Link>
          ))}
        </div>
      </section>

      {/* Festive campaign */}
      <section className="og-container pb-16 lg:pb-24">
        <div className="grid items-center gap-8 border border-border bg-surface p-6 lg:grid-cols-2 lg:p-10">
          <CampaignMediaPlaceholder slotId="home.campaign.festive" alt="Festive campaign" label="CAMPAIGN · FESTIVE" />
          <div>
            <Eyebrow>Campaign</Eyebrow>
            <h2 className="mt-3 font-display text-4xl leading-tight lg:text-5xl">A new language of festive</h2>
            <p className="mt-4 text-sm text-secondary-text">
              53 ethnicwear styles — sarees, lehengas, sets and gowns — from ateliers working in small runs.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <OgLinkButton to="/occasion/festive">Shop festive</OgLinkButton>
              <OgLinkButton to="/women/ethnicwear" variant="secondary">
                All ethnicwear
              </OgLinkButton>
            </div>
          </div>
        </div>
        <div className="mt-8">
          <ProductRail products={rails.ethnic} perView={4} ariaLabel="Festive ethnicwear" />
        </div>
      </section>

      {/* Footwear services */}
      <section className="border-y border-border bg-surface py-16 lg:py-24">
        <div className="og-container">
          <SectionHeading eyebrow="Footwear" title="The finishing step" />
          <div className="mt-8 grid gap-4 md:grid-cols-3">
            {FOOTWEAR_SERVICES.map((s) => (
              <div key={s.title} className="border border-border bg-background p-6">
                <p className="text-[11px] uppercase tracking-[0.18em] text-foreground">{s.title}</p>
                <p className="mt-3 text-sm text-secondary-text">{s.line}</p>
              </div>
            ))}
          </div>
          <div className="mt-10">
            <ProductRail products={rails.footwear} perView={5} ariaLabel="Footwear" />
          </div>
        </div>
      </section>

      {/* Accessories / finishing touch */}
      <section className="og-container py-16 lg:py-24">
        <SectionHeading
          eyebrow="Accessories"
          title="The finishing touch"
          action={
            <OgLinkButton to="/women/accessories" variant="quiet">
              View all
            </OgLinkButton>
          }
        />
        <div className="mt-8">
          <ProductRail products={rails.accessories} perView={5} ariaLabel="Accessories" />
        </div>
      </section>

      {/* Complete the look editorial */}
      <section className="og-container pb-16 lg:pb-24">
        <div className="grid gap-8 lg:grid-cols-[1fr_1fr]">
          <EditorialBannerPlaceholder slotId="home.editorial.look" alt="Complete the look" label="EDITORIAL · LOOK" />
          <div className="flex flex-col justify-center">
            <Eyebrow>Styling</Eyebrow>
            <h2 className="mt-3 font-display text-4xl leading-tight">Complete the look</h2>
            <p className="mt-4 text-sm text-secondary-text">
              Pieces designed to sit together — upperwear, bottoms and a bag from studios with a shared point of view.
            </p>
            <div className="mt-6 flex flex-wrap gap-2">
              {STYLE_COLLECTIONS.slice(0, 6).map((c) => (
                <Link
                  key={c.slug}
                  to="/collections/$collectionSlug"
                  params={{ collectionSlug: c.slug }}
                  className="border border-border px-4 py-2 text-xs uppercase tracking-[0.14em] text-secondary-text hover:border-rose hover:text-foreground"
                >
                  {c.title}
                </Link>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* Made to order */}
      <section className="border-t border-border bg-surface py-16 lg:py-24">
        <div className="og-container">
          <SectionHeading
            eyebrow="Service"
            title="Made to Order"
            description="Start from a piece you like and shape it with the studio — size, colour and detail."
            action={
              <OgLinkButton to="/made-to-order" variant="quiet">
                How it works
              </OgLinkButton>
            }
          />
          <div className="mt-8">
            <ProductRail products={rails.mto} perView={5} ariaLabel="Made to order" />
          </div>
        </div>
      </section>

      <div className="og-container">
        <RecentlyViewedRail />
      </div>
    </div>
  );
}
