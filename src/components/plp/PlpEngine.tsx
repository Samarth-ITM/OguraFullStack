import { Fragment, useEffect, useMemo, useState } from "react";
import { Link } from "@tanstack/react-router";
import { SlidersHorizontal, X } from "lucide-react";
import type { ProductQuery, SortKey } from "@/domain/catalog";
import { listProductsSync } from "@/repositories/mock/catalog";
import { DEFAULT_TEMPLATE, PLP_TEMPLATES, type PlpTemplate } from "@/data/mockMerchandising";
import { SUBCATEGORY_NAME_BY_SLUG } from "@/data/taxonomy";
import { EditorialBannerPlaceholder } from "@/components/media/slots";
import { ProductCard, ProductCardSkeleton } from "@/components/commerce/ProductCard";
import { EmptyState, Eyebrow, OgButton } from "@/components/ui-og/primitives";
import { RecentlyViewedRail } from "@/components/commerce/RecentlyViewedRail";
import { useFocusTrap } from "@/state/ui";
import { toProductQuery, usePlpSearch } from "./usePlpQuery";
import { FilterPanel } from "./FilterPanel";
import { EditorialInsert } from "./EditorialInsert";

const BATCH = 24;

const SORTS: { value: SortKey; label: string }[] = [
  { value: "recommended", label: "Recommended" },
  { value: "newest", label: "New arrivals" },
  { value: "price-asc", label: "Price: low to high" },
  { value: "price-desc", label: "Price: high to low" },
  { value: "discount", label: "Discount" },
  { value: "rating", label: "Customer rating" },
  { value: "loved", label: "Most loved" },
];

export interface Crumb {
  label: string;
  to?: string;
}

export function PlpEngine({
  title,
  description,
  crumbs,
  baseQuery,
  templateKey,
  chipBasePath,
  showSubcategoryFilter = true,
}: {
  title: string;
  description?: string;
  crumbs: Crumb[];
  baseQuery: Partial<ProductQuery>;
  templateKey?: string;
  chipBasePath?: string;
  showSubcategoryFilter?: boolean;
}) {
  const { search, write, toggleFilter, clearAll, activeCount } = usePlpSearch();
  const [sheetOpen, setSheetOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const sheetRef = useFocusTrap(sheetOpen, () => setSheetOpen(false));

  const template: PlpTemplate = (templateKey && PLP_TEMPLATES[templateKey]) || DEFAULT_TEMPLATE;
  const query = useMemo(() => ({ ...toProductQuery(search, baseQuery), limit: 999 }), [search, baseQuery]);
  const result = useMemo(() => listProductsSync(query), [query]);

  const visible = result.items.slice(0, search.batches * BATCH);
  const hasMore = visible.length < result.items.length;

  useEffect(() => {
    setPending(true);
    const t = window.setTimeout(() => setPending(false), 180);
    return () => window.clearTimeout(t);
  }, [query]);

  const chips = template.chips;

  return (
    <div className="og-container py-6 lg:py-10">
      <nav aria-label="Breadcrumb" className="mb-5 text-xs text-muted-text">
        <ol className="flex flex-wrap items-center gap-2">
          {crumbs.map((c, i) => (
            <li key={`${c.label}-${i}`} className="flex items-center gap-2">
              {c.to ? (
                <Link to={c.to} className="hover:text-foreground">
                  {c.label}
                </Link>
              ) : (
                <span aria-current="page" className="text-secondary-text">
                  {c.label}
                </span>
              )}
              {i < crumbs.length - 1 ? <span aria-hidden>/</span> : null}
            </li>
          ))}
        </ol>
      </nav>

      <EditorialBannerPlaceholder
        slotId={template.bannerLabel}
        alt={template.banner}
        label={`${template.banner} · ${template.bannerLabel}`}
        className="mb-8"
      />

      <header className="mb-6">
        <Eyebrow>Shop</Eyebrow>
        <h1 className="mt-2 font-display text-4xl leading-tight lg:text-5xl">{title}</h1>
        <p className="mt-2 text-sm text-secondary-text">
          {result.total} {result.total === 1 ? "style" : "styles"}
          {description ? ` · ${description}` : ""}
        </p>
      </header>

      {chips.length && chipBasePath ? (
        <div className="og-rail mb-8 gap-2" style={{ gridAutoColumns: "max-content" }}>
          {chips.map((slug) => (
            <Link
              key={slug}
              to="/women/$categorySlug/$subcategorySlug"
              params={{ categorySlug: chipBasePath.split("/").filter(Boolean)[1] ?? "clothing", subcategorySlug: slug }}
              className="whitespace-nowrap border border-border px-4 py-2 text-xs uppercase tracking-[0.14em] text-secondary-text hover:border-rose hover:text-foreground"
            >
              {SUBCATEGORY_NAME_BY_SLUG.get(slug) ?? slug}
            </Link>
          ))}
        </div>
      ) : null}

      <div className="sticky top-16 z-30 -mx-4 mb-6 flex items-center justify-between gap-3 border-y border-border bg-background/95 px-4 py-3 backdrop-blur lg:top-20">
        <button
          type="button"
          onClick={() => setSheetOpen(true)}
          className="flex min-h-11 items-center gap-2 text-xs uppercase tracking-[0.16em] lg:hidden"
          aria-haspopup="dialog"
        >
          <SlidersHorizontal className="size-4" /> Filters{activeCount ? ` (${activeCount})` : ""}
        </button>
        <span className="hidden text-xs text-muted-text lg:block">
          Showing {visible.length} of {result.total}
        </span>
        <label className="flex items-center gap-2 text-xs text-secondary-text">
          <span className="sr-only lg:not-sr-only">Sort by</span>
          <select
            value={search.sort}
            onChange={(e) => write({ sort: e.target.value as SortKey })}
            className="min-h-11 border border-border bg-transparent px-3 text-xs text-foreground"
          >
            {SORTS.map((s) => (
              <option key={s.value} value={s.value} className="bg-deep">
                {s.label}
              </option>
            ))}
          </select>
        </label>
      </div>

      {activeCount ? (
        <div className="mb-6 flex flex-wrap items-center gap-2">
          {(Object.keys(search.filters) as (keyof typeof search.filters)[]).flatMap((key) =>
            search.filters[key].map((value) => (
              <button
                key={`${key}-${value}`}
                type="button"
                onClick={() => toggleFilter(key, value)}
                className="flex min-h-9 items-center gap-2 border border-border-strong px-3 text-xs text-secondary-text hover:text-foreground"
              >
                {SUBCATEGORY_NAME_BY_SLUG.get(value) ?? value}
                <X className="size-3" />
              </button>
            )),
          )}
          <button type="button" onClick={clearAll} className="text-xs text-rose hover:text-rose-hover">
            Clear all
          </button>
        </div>
      ) : null}

      <div className="grid gap-8 lg:grid-cols-[260px_minmax(0,1fr)]">
        <aside className="hidden lg:block">
          <div className="sticky top-40 max-h-[calc(100vh-12rem)] overflow-y-auto pr-2">
            <FilterPanel
              facets={result.facets}
              search={search}
              showSubcategory={showSubcategoryFilter}
              onToggle={toggleFilter}
              onPriceRange={(min, max) => write({ minPrice: min, maxPrice: max })}
              onClear={clearAll}
            />
          </div>
        </aside>

        <div>
          {pending ? (
            <div className="grid grid-cols-2 gap-x-4 gap-y-10 md:grid-cols-3 xl:grid-cols-4">
              {Array.from({ length: 8 }).map((_, i) => (
                <ProductCardSkeleton key={i} />
              ))}
            </div>
          ) : visible.length === 0 ? (
            <EmptyState
              title="No pieces match these filters"
              body="Try removing a filter, or explore the wider selection."
              action={<OgButton variant="secondary" onClick={clearAll}>Clear all filters</OgButton>}
            />
          ) : (
            <div className="grid grid-cols-2 gap-x-4 gap-y-10 md:grid-cols-3 xl:grid-cols-4">
              {visible.map((product, index) => (
                <Fragment key={product.id}>
                  <ProductCard product={product} />
                  {index === 11 && template.insert12 ? (
                    <EditorialInsert slotId={`${template.bannerLabel}.insert12`} {...template.insert12} />
                  ) : null}
                  {index === 35 && template.insert36 ? (
                    <EditorialInsert slotId={`${template.bannerLabel}.insert36`} {...template.insert36} />
                  ) : null}
                </Fragment>
              ))}
            </div>
          )}

          {hasMore ? (
            <div className="mt-12 flex flex-col items-center gap-3">
              <p className="text-xs text-muted-text">
                Showing {visible.length} of {result.total}
              </p>
              <OgButton variant="secondary" onClick={() => write({ batches: search.batches + 1 }, false)}>
                Load more
              </OgButton>
            </div>
          ) : visible.length ? (
            <p className="mt-12 text-center text-xs text-muted-text">You have seen all {result.total} styles.</p>
          ) : null}
        </div>
      </div>

      <RecentlyViewedRail />

      {sheetOpen ? (
        <div className="fixed inset-0 z-[80] lg:hidden" role="dialog" aria-modal="true" aria-label="Filters">
          <button type="button" aria-label="Close filters" className="absolute inset-0 bg-black/60" onClick={() => setSheetOpen(false)} />
          <div ref={sheetRef} className="absolute inset-x-0 bottom-0 flex max-h-[85vh] flex-col border-t border-border bg-background">
            <div className="flex items-center justify-between border-b border-border px-4 py-3">
              <h2 className="text-[11px] uppercase tracking-[0.18em]">Filters</h2>
              <button type="button" onClick={() => setSheetOpen(false)} aria-label="Close filters" className="grid size-11 place-items-center">
                <X className="size-5" />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto px-4 py-5">
              <FilterPanel
                facets={result.facets}
                search={search}
                showSubcategory={showSubcategoryFilter}
                onToggle={toggleFilter}
                onPriceRange={(min, max) => write({ minPrice: min, maxPrice: max })}
                onClear={clearAll}
              />
            </div>
            <div className="border-t border-border p-4">
              <OgButton className="w-full" onClick={() => setSheetOpen(false)}>
                Show {result.total} styles
              </OgButton>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
