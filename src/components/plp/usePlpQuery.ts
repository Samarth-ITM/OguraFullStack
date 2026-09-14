import { useCallback, useMemo } from "react";
import { useLocation, useNavigate } from "@tanstack/react-router";
import type { ProductQuery, SortKey } from "@/domain/catalog";

export type FilterKey =
  | "sub"
  | "size"
  | "price"
  | "brand"
  | "color"
  | "occasion"
  | "style"
  | "fit"
  | "material"
  | "discount"
  | "availability"
  | "mto";

export interface PlpSearch {
  filters: Record<FilterKey, string[]>;
  sort: SortKey;
  batches: number;
  minPrice?: number;
  maxPrice?: number;
  q?: string;
}

const KEYS: FilterKey[] = [
  "sub",
  "size",
  "price",
  "brand",
  "color",
  "occasion",
  "style",
  "fit",
  "material",
  "discount",
  "availability",
  "mto",
];

function emptyFilters(): Record<FilterKey, string[]> {
  return KEYS.reduce(
    (acc, key) => {
      acc[key] = [];
      return acc;
    },
    {} as Record<FilterKey, string[]>,
  );
}

export function usePlpSearch() {
  const location = useLocation();
  const navigate = useNavigate();
  const raw = location.search as Record<string, unknown>;

  const parsed = useMemo<PlpSearch>(() => {
    const filters = emptyFilters();
    for (const key of KEYS) {
      const value = raw[key];
      if (typeof value === "string" && value) filters[key] = value.split(",");
    }
    const next: PlpSearch = {
      filters,
      sort: (typeof raw["sort"] === "string" ? raw["sort"] : "recommended") as SortKey,
      batches: Math.max(1, Number(raw["batches"] ?? 1) || 1),
    };
    if (raw["min"]) next.minPrice = Number(raw["min"]);
    if (raw["max"]) next.maxPrice = Number(raw["max"]);
    if (typeof raw["q"] === "string" && raw["q"]) next.q = raw["q"];
    return next;
  }, [raw]);

  const write = useCallback(
    (next: Partial<PlpSearch>, resetBatches = true) => {
      const merged = { ...parsed, ...next };
      const search: Record<string, string | number> = {};
      if (merged.q) search["q"] = merged.q;
      for (const key of KEYS) {
        const list = merged.filters[key];
        if (list?.length) search[key] = list.join(",");
      }
      if (merged.sort && merged.sort !== "recommended") search["sort"] = merged.sort;
      if (merged.minPrice) search["min"] = merged.minPrice;
      if (merged.maxPrice) search["max"] = merged.maxPrice;
      const batches = resetBatches ? 1 : merged.batches;
      if (batches > 1) search["batches"] = batches;
      navigate({ to: location.pathname as never, search: search as never, replace: resetBatches });
    },
    [navigate, parsed, location.pathname],
  );

  const toggleFilter = useCallback(
    (key: FilterKey, value: string) => {
      const current = parsed.filters[key];
      const next = current.includes(value) ? current.filter((v) => v !== value) : [...current, value];
      write({ filters: { ...parsed.filters, [key]: next } });
    },
    [parsed, write],
  );

  const clearAll = useCallback(() => {
    navigate({
      to: location.pathname as never,
      search: (parsed.q ? { q: parsed.q } : {}) as never,
      replace: true,
    });
  }, [navigate, location.pathname, parsed.q]);

  const activeCount = KEYS.reduce((n, key) => n + parsed.filters[key].length, 0) +
    (parsed.minPrice || parsed.maxPrice ? 1 : 0);

  return { search: parsed, write, toggleFilter, clearAll, activeCount };
}

export function toProductQuery(search: PlpSearch, base: Partial<ProductQuery>): ProductQuery {
  const f = search.filters;
  const q: ProductQuery = {
    ...base,
    sizes: f.size,
    priceBands: f.price,
    brandSlugs: base.brandSlugs?.length ? base.brandSlugs : f.brand,
    colors: f.color,
    occasions: base.occasions?.length ? base.occasions : f.occasion,
    aesthetics: f.style,
    fits: f.fit,
    materials: f.material,
    availability: f.availability,
    madeToOrder: f.mto.length > 0 || base.madeToOrder === true,
    sort: search.sort,
  };
  const sub = base.subcategory ?? (f.sub.length === 1 ? f.sub[0] : undefined);
  if (sub) q.subcategory = sub;
  if (f.discount.length) q.minDiscount = Math.min(...f.discount.map(Number));
  if (search.minPrice !== undefined) q.minPrice = search.minPrice;
  if (search.maxPrice !== undefined) q.maxPrice = search.maxPrice;
  const term = search.q ?? base.q;
  if (term) q.q = term;
  return q;
}
