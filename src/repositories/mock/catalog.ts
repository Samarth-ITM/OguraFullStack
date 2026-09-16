import { generatedProducts } from "@/data/generated/products";
import { generatedVariants } from "@/data/generated/variants";
import { generatedBrands } from "@/data/generated/brands";
import {
  ALL_COLLECTIONS,
  CATEGORY_NAME_BY_SLUG,
  COLLECTION_BY_SLUG,
  PRICE_BANDS,
  SLUG_BY_SUBCATEGORY_NAME,
  SUBCATEGORY_NAME_BY_SLUG,
} from "@/data/taxonomy";
import type {
  Brand,
  Collection,
  Facets,
  Product,
  ProductListResult,
  ProductQuery,
  Variant,
} from "@/domain/catalog";
import { discountPct } from "@/lib/format";
import type { CatalogRepository } from "../contracts";
import { simulate } from "./latency";

export const allProducts: Product[] = generatedProducts;
export const allVariants: Variant[] = generatedVariants;

export const variantsByProduct = new Map<string, Variant[]>();
for (const v of allVariants) {
  const list = variantsByProduct.get(v.productId);
  if (list) list.push(v);
  else variantsByProduct.set(v.productId, [v]);
}

export const productById = new Map(allProducts.map((p) => [p.id, p]));
export const productBySlug = new Map(allProducts.map((p) => [p.slug, p]));
export const brandBySlug = new Map(generatedBrands.map((b) => [b.slug, b]));

export function variantsFor(productId: string): Variant[] {
  return variantsByProduct.get(productId) ?? [];
}

export function sizesFor(productId: string): string[] {
  return Array.from(new Set(variantsFor(productId).map((v) => v.size)));
}

export function colorsFor(productId: string): { name: string; hex: string }[] {
  const map = new Map<string, string>();
  for (const v of variantsFor(productId)) map.set(v.color, v.colorHex);
  return Array.from(map, ([name, hex]) => ({ name, hex }));
}

export function isSoldOut(productId: string): boolean {
  const list = variantsFor(productId);
  return list.length > 0 && list.every((v) => v.availability === "sold_out");
}

export function isLowStock(productId: string): boolean {
  const list = variantsFor(productId).filter((v) => v.availability !== "sold_out");
  return list.length > 0 && list.every((v) => v.availability === "low_stock");
}

function bandOf(price: number): string {
  return PRICE_BANDS.find((b) => price >= b.min && price <= b.max)?.value ?? "";
}

function matchesCollection(product: Product, collection: Collection): boolean {
  if (collection.kind === "price") {
    return product.price >= (collection.minPrice ?? 0) && product.price <= (collection.maxPrice ?? Infinity);
  }
  if (collection.subcategories?.includes(product.subcategory)) return true;
  if (collection.productTypes?.some((t) => product.productType?.toLowerCase() === t.toLowerCase())) return true;
  if (
    collection.productTypes?.some((t) =>
      `${product.title} ${product.productType}`.toLowerCase().includes(t.toLowerCase().replace(/s$/, "")),
    )
  )
    return true;
  return false;
}

export function collectionCount(collection: Collection): number {
  return allProducts.filter((p) => matchesCollection(p, collection)).length;
}

function textMatch(product: Product, q: string): boolean {
  const hay = [
    product.title,
    product.brandName,
    product.category,
    product.subcategory,
    product.productType,
    product.occasion,
    product.aesthetic,
    product.colorFamily,
    product.material,
  ]
    .join(" ")
    .toLowerCase();
  return q
    .toLowerCase()
    .split(/\s+/)
    .filter(Boolean)
    .every((token) => hay.includes(token));
}

export function filterProducts(query: ProductQuery): Product[] {
  let items = allProducts.slice();
  if (query.category) {
    const name = CATEGORY_NAME_BY_SLUG.get(query.category);
    if (name) items = items.filter((p) => p.category === name);
  }
  if (query.subcategory) {
    const name = SUBCATEGORY_NAME_BY_SLUG.get(query.subcategory);
    if (name) items = items.filter((p) => p.subcategory === name);
  }
  if (query.collection) {
    const collection = COLLECTION_BY_SLUG.get(query.collection);
    if (collection) items = items.filter((p) => matchesCollection(p, collection));
    else items = [];
  }
  if (query.q) items = items.filter((p) => textMatch(p, query.q as string));
  if (query.brandSlugs?.length) items = items.filter((p) => query.brandSlugs!.includes(p.brandSlug));
  if (query.occasions?.length) items = items.filter((p) => query.occasions!.includes(p.occasion));
  if (query.aesthetics?.length) items = items.filter((p) => query.aesthetics!.includes(p.aesthetic));
  if (query.fits?.length) items = items.filter((p) => query.fits!.includes(p.fit));
  if (query.materials?.length) items = items.filter((p) => query.materials!.includes(p.material));
  if (query.priceBands?.length) items = items.filter((p) => query.priceBands!.includes(bandOf(p.price)));
  if (query.minPrice != null) items = items.filter((p) => p.price >= query.minPrice!);
  if (query.maxPrice != null) items = items.filter((p) => p.price <= query.maxPrice!);
  if (query.minDiscount != null)
    items = items.filter((p) => (discountPct(p.price, p.compareAtPrice) ?? 0) >= query.minDiscount!);
  if (query.madeToOrder) items = items.filter((p) => p.madeToOrder || p.customizable);
  if (query.launchpad) items = items.filter((p) => p.launchpad);
  if (query.newArrival) items = items.filter((p) => p.newArrival);
  if (query.sizes?.length)
    items = items.filter((p) => variantsFor(p.id).some((v) => query.sizes!.includes(v.size)));
  if (query.colors?.length)
    items = items.filter((p) => variantsFor(p.id).some((v) => query.colors!.includes(v.color)));
  if (query.availability?.length) {
    items = items.filter((p) => {
      const sold = isSoldOut(p.id);
      if (query.availability!.includes("in_stock") && !sold) return true;
      if (query.availability!.includes("sold_out") && sold) return true;
      return false;
    });
  }
  return items;
}

function sortProducts(items: Product[], sort: ProductQuery["sort"], brandRoute: boolean): Product[] {
  const list = items.slice();
  switch (sort) {
    case "newest":
      list.sort((a, b) => b.createdAt - a.createdAt);
      return list;
    case "price-asc":
      list.sort((a, b) => a.price - b.price || a.id.localeCompare(b.id));
      return list;
    case "price-desc":
      list.sort((a, b) => b.price - a.price || a.id.localeCompare(b.id));
      return list;
    case "discount": {
      const pct = (p: Product) =>
        p.compareAtPrice && p.compareAtPrice > p.price
          ? Math.round(((p.compareAtPrice - p.price) / p.compareAtPrice) * 100)
          : 0;
      list.sort((a, b) => pct(b) - pct(a) || a.id.localeCompare(b.id));
      return list;
    }
    case "rating":
      list.sort((a, b) => b.rating - a.rating || b.reviewCount - a.reviewCount);
      return list;
    case "loved":
      list.sort((a, b) => b.popularity - a.popularity || a.id.localeCompare(b.id));
      return list;
    default: {
      list.sort((a, b) => {
        const score = (p: Product) =>
          p.popularity + (p.newArrival ? 30 : 0) + (p.reviewCount > 5 ? 12 : 0) + (p.limited ? 8 : 0);
        return score(b) - score(a) || a.id.localeCompare(b.id);
      });
      return brandRoute ? list : diversifyByBrand(list);
    }
  }
}

/** Keeps no more than two consecutive products from the same brand. */
function diversifyByBrand(items: Product[]): Product[] {
  const out: Product[] = [];
  const pool = items.slice();
  while (pool.length) {
    let picked = -1;
    for (let i = 0; i < pool.length; i += 1) {
      const brand = pool[i]?.brandSlug;
      const n = out.length;
      const streak = n >= 2 && out[n - 1]?.brandSlug === brand && out[n - 2]?.brandSlug === brand;
      if (!streak) {
        picked = i;
        break;
      }
    }
    if (picked === -1) picked = 0;
    const taken = pool.splice(picked, 1)[0];
    if (taken) out.push(taken);
  }
  return out;
}

function buildFacets(items: Product[]): Facets {
  const count = <T extends string>(values: T[]) => {
    const map = new Map<string, number>();
    for (const v of values) map.set(v, (map.get(v) ?? 0) + 1);
    return Array.from(map, ([value, c]) => ({ value, count: c })).sort((a, b) => b.count - a.count);
  };

  const sizeMap = new Map<string, number>();
  const colorMap = new Map<string, { hex: string; count: number }>();
  for (const p of items) {
    for (const size of new Set(variantsFor(p.id).map((v) => v.size))) {
      sizeMap.set(size, (sizeMap.get(size) ?? 0) + 1);
    }
    for (const v of variantsFor(p.id)) {
      const existing = colorMap.get(v.color);
      if (existing) existing.count += 0;
      else colorMap.set(v.color, { hex: v.colorHex, count: 0 });
    }
    for (const color of new Set(variantsFor(p.id).map((v) => v.color))) {
      const entry = colorMap.get(color)!;
      entry.count += 1;
    }
  }

  const brandCounts = new Map<string, { label: string; count: number }>();
  for (const p of items) {
    const entry = brandCounts.get(p.brandSlug);
    if (entry) entry.count += 1;
    else brandCounts.set(p.brandSlug, { label: p.brandName, count: 1 });
  }

  return {
    subcategories: count(items.map((p) => SLUG_BY_SUBCATEGORY_NAME.get(p.subcategory) ?? p.subcategory)),
    brands: Array.from(brandCounts, ([value, v]) => ({ value, label: v.label, count: v.count })).sort((a, b) =>
      a.label.localeCompare(b.label),
    ),
    sizes: Array.from(sizeMap, ([value, c]) => ({ value, count: c })).sort((a, b) => b.count - a.count),
    colors: Array.from(colorMap, ([value, v]) => ({ value, hex: v.hex, count: v.count })).sort(
      (a, b) => b.count - a.count,
    ),
    occasions: count(items.map((p) => p.occasion)),
    aesthetics: count(items.map((p) => p.aesthetic)),
    fits: count(items.map((p) => p.fit)),
    materials: count(items.map((p) => p.material)),
    priceBands: PRICE_BANDS.map((b) => ({
      value: b.value,
      count: items.filter((p) => p.price >= b.min && p.price <= b.max).length,
    })).filter((b) => b.count > 0),
  };
}

export function listProductsSync(query: ProductQuery): ProductListResult {
  const filtered = filterProducts(query);
  const sorted = sortProducts(filtered, query.sort, Boolean(query.brandSlugs?.length));
  const offset = query.offset ?? 0;
  const limit = query.limit ?? 24;
  return {
    items: sorted.slice(offset, offset + limit),
    total: sorted.length,
    facets: buildFacets(filtered),
  };
}

export const mockCatalogRepository: CatalogRepository = {
  listProducts(query) {
    return simulate(`list:${JSON.stringify(query)}`, () => listProductsSync(query));
  },
  getProduct(slug) {
    return simulate(`product:${slug}`, () => {
      const product = productBySlug.get(slug);
      if (!product) return null;
      return { product, variants: variantsFor(product.id) };
    });
  },
  searchProducts(q, limit = 8) {
    return simulate(`search:${q}`, () =>
      q.trim() ? allProducts.filter((p) => textMatch(p, q)).slice(0, limit) : [],
    );
  },
  listBrands() {
    return simulate("brands", () => generatedBrands as Brand[]);
  },
  getBrand(slug) {
    return simulate(`brand:${slug}`, () => brandBySlug.get(slug) ?? null);
  },
  listCollections() {
    return simulate("collections", () => ALL_COLLECTIONS);
  },
  getCollection(slug) {
    return simulate(`collection:${slug}`, () => COLLECTION_BY_SLUG.get(slug) ?? null);
  },
};
