import type { Facets } from "@/domain/catalog";
import { PRICE_BANDS, SUBCATEGORY_NAME_BY_SLUG } from "@/data/taxonomy";
import { Eyebrow } from "@/components/ui-og/primitives";
import type { FilterKey, PlpSearch } from "./usePlpQuery";

interface Group {
  key: FilterKey;
  title: string;
  options: { value: string; label: string; count?: number; hex?: string }[];
}

export function buildGroups(facets: Facets, showSubcategory: boolean): Group[] {
  const groups: Group[] = [];
  if (showSubcategory && facets.subcategories.length > 1) {
    groups.push({
      key: "sub",
      title: "Category",
      options: facets.subcategories.map((s) => ({
        value: s.value,
        label: SUBCATEGORY_NAME_BY_SLUG.get(s.value) ?? s.value,
        count: s.count,
      })),
    });
  }
  groups.push({
    key: "size",
    title: "Size",
    options: facets.sizes.map((s) => ({ value: s.value, label: s.value, count: s.count })),
  });
  groups.push({
    key: "price",
    title: "Price",
    options: PRICE_BANDS.map((b) => ({
      value: b.value,
      label: b.label,
      count: facets.priceBands.find((f) => f.value === b.value)?.count ?? 0,
    })).filter((o) => o.count > 0),
  });
  groups.push({
    key: "brand",
    title: "Brand & designer",
    options: facets.brands.map((b) => ({ value: b.value, label: b.label, count: b.count })),
  });
  groups.push({
    key: "color",
    title: "Colour",
    options: facets.colors.map((c) => ({ value: c.value, label: c.value, count: c.count, hex: c.hex })),
  });
  groups.push({
    key: "occasion",
    title: "Occasion",
    options: facets.occasions.map((o) => ({
      value: o.value,
      label: o.value.replace(/-/g, " ").replace(/\b\w/g, (m) => m.toUpperCase()),
      count: o.count,
    })),
  });
  groups.push({
    key: "style",
    title: "Style & aesthetic",
    options: facets.aesthetics.map((a) => ({ value: a.value, label: a.value, count: a.count })),
  });
  groups.push({
    key: "fit",
    title: "Fit & silhouette",
    options: facets.fits.map((f) => ({ value: f.value, label: f.value, count: f.count })),
  });
  groups.push({
    key: "material",
    title: "Material & fabric",
    options: facets.materials.map((m) => ({ value: m.value, label: m.value, count: m.count })),
  });
  groups.push({
    key: "discount",
    title: "Discount",
    options: [
      { value: "10", label: "10% and above" },
      { value: "20", label: "20% and above" },
      { value: "30", label: "30% and above" },
    ],
  });
  groups.push({
    key: "availability",
    title: "Availability",
    options: [
      { value: "in_stock", label: "In stock" },
      { value: "sold_out", label: "Sold out" },
    ],
  });
  groups.push({
    key: "mto",
    title: "Made to Order",
    options: [{ value: "yes", label: "Made to order / customisable" }],
  });
  return groups.filter((g) => g.options.length > 0);
}

export function FilterPanel({
  facets,
  search,
  showSubcategory,
  onToggle,
  onPriceRange,
  onClear,
}: {
  facets: Facets;
  search: PlpSearch;
  showSubcategory: boolean;
  onToggle: (key: FilterKey, value: string) => void;
  onPriceRange: (min: number, max: number) => void;
  onClear: () => void;
}) {
  const groups = buildGroups(facets, showSubcategory);

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <Eyebrow>Filters</Eyebrow>
        <button type="button" onClick={onClear} className="text-xs text-muted-text hover:text-foreground">
          Clear all
        </button>
      </div>

      {groups.map((group) => (
        <fieldset key={group.key} className="border-t border-border pt-5">
          <legend className="sr-only">{group.title}</legend>
          <p className="mb-3 text-[11px] uppercase tracking-[0.18em] text-foreground">{group.title}</p>
          <div className="max-h-56 space-y-2 overflow-y-auto pr-1">
            {group.options.map((opt) => {
              const checked = search.filters[group.key].includes(opt.value);
              return (
                <label key={opt.value} className="flex min-h-9 cursor-pointer items-center gap-2.5 text-sm">
                  <input
                    type="checkbox"
                    checked={checked}
                    onChange={() => onToggle(group.key, opt.value)}
                    className="size-4 accent-[#E72D63]"
                  />
                  {opt.hex ? (
                    <span className="size-3 rounded-full border border-border-strong" style={{ backgroundColor: opt.hex }} />
                  ) : null}
                  <span className={checked ? "text-foreground" : "text-secondary-text"}>{opt.label}</span>
                  {opt.count != null ? <span className="ml-auto text-xs text-muted-text">{opt.count}</span> : null}
                </label>
              );
            })}
          </div>
          {group.key === "price" ? (
            <div className="mt-4">
              <label htmlFor="price-slider" className="text-xs text-muted-text">
                Max price: ₹{(search.maxPrice ?? 15000).toLocaleString("en-IN")}
              </label>
              <input
                id="price-slider"
                type="range"
                min={1111}
                max={15000}
                step={100}
                value={search.maxPrice ?? 15000}
                onChange={(e) => onPriceRange(1111, Number(e.target.value))}
                className="mt-2 w-full accent-[#E72D63]"
              />
            </div>
          ) : null}
        </fieldset>
      ))}
    </div>
  );
}
